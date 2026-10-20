import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../../../core/network/local_service.dart';
import '../../domain/models/board_sticker.dart';
import '../../domain/models/smart_chalk_annotation.dart';
import '../../domain/models/studio_board_models.dart';
import 'audio_sync_controller.dart';
import 'canvas_drawing_controller.dart';
import 'pdf_smart_pen_controller.dart';
import 'studio_plugin_bridge_controller.dart';

/// Central Mediator & Workspace Coordinator managing the classroom session,
/// metadata, dirty/save lifecycle, cross-domain events, and sub-controllers.
class StudioWorkspaceCoordinator extends ChangeNotifier {
  StudioWorkspaceCoordinator({
    LocalService? service,
    CanvasDrawingController? canvas,
    PdfSmartPenController? pdf,
    AudioSyncController? audio,
    StudioPluginBridgeController? plugins,
  })  : service = service ?? LocalService(),
        canvas = canvas ?? CanvasDrawingController(),
        pdf = pdf ?? PdfSmartPenController(),
        audio = audio ?? AudioSyncController(service: service),
        plugins = plugins ?? StudioPluginBridgeController() {
    this.canvas.addListener(_onChildChanged);
    this.pdf.addListener(_onChildChanged);
    this.plugins.addListener(_onChildChanged);
    this.audio.addListener(_onChildChanged);
    this.pdf.onMarkDirty = () {
      dirty = true;
      notifyListeners();
    };
    this.pdf.smartPenManager.onClearBoardRedo = () {
      this.canvas.clearRedo();
    };
    this.pdf.isPluginSmartSnapActive = () {
      final p = this.plugins.activePlugin;
      if (p == null || this.plugins.activeSubjectTool == null) return false;
      return p.manifest.contributesTools.any(
        (t) =>
            t.pdfTapMode && (t.target ?? t.id) == this.plugins.activeSubjectTool,
      );
    };
  }

  final Map<BoardStroke, int> _boardUndoSequence = {};
  final Map<BoardStroke, int> _boardRedoSequence = {};

  void recordBoardAction(BoardStroke stroke) {
    _boardUndoSequence[stroke] = ++pdf.smartPenManager.historySequence;
    canvas.clearRedo();
    pdf.smartPenManager.smartPenRedo[pdf.historyKey]?.clear();
  }

  void recordPdfAction(List<BoardStroke> target) {
    canvas.clearRedo();
    pdf.smartPenManager.smartPenRedo[pdf.historyKey]?.clear();
  }

  final LocalService service;
  final CanvasDrawingController canvas;
  final PdfSmartPenController pdf;
  final AudioSyncController audio;
  final StudioPluginBridgeController plugins;

  String title = 'Không gian giảng dạy';
  String subject = 'Chung';
  String notes = '';
  String question = 'Câu hỏi thảo luận cho cả lớp';
  String endpoint = '';
  String view = 'board'; // 'board' | 'pdf' | 'split'
  bool dirty = false;
  bool saving = false;
  bool online = false;
  bool loading = false;
  String? error;

  void _onChildChanged() {
    notifyListeners();
  }

  void markDirty() {
    if (!dirty) {
      dirty = true;
      notifyListeners();
    }
  }

  /// Mediator: Inserts a card or sticker coming from an external Plugin onto the canvas.
  void insertPluginCard(Map<String, dynamic> cardData) {
    final rawRect = cardData['rect'] as List? ?? [0.2, 0.25, 0.45, 0.22];
    final rect = Rect.fromLTWH(
      (rawRect[0] as num).toDouble(),
      (rawRect[1] as num).toDouble(),
      (rawRect[2] as num).toDouble(),
      (rawRect[3] as num).toDouble(),
    );

    final rawTokens = cardData['tokens'] as List? ?? [];
    final tokens = rawTokens
        .map((t) => t is Map ? Map<String, dynamic>.from(t) : {'text': t.toString()})
        .toList();

    final rawIssues = cardData['issues'] as List? ?? [];
    final issues = rawIssues.map((e) => e.toString()).toList();

    final sticker = BoardSticker(
      id: cardData['id']?.toString() ??
          'sticker-${DateTime.now().millisecondsSinceEpoch}',
      type: cardData['type']?.toString() ?? 'generic_sticker',
      normalizedRect: rect,
      rawText: cardData['rawText']?.toString() ?? '',
      tokens: tokens,
      issues: issues,
    );

    canvas.addSticker(sticker);
    markDirty();

    if (plugins.showPluginDrawer && !plugins.pluginFloating) {
      plugins.showPluginDrawer = false;
    }
  }

  bool get canUndo =>
      (pdf.smartPenManager.smartPenUndo[pdf.historyKey]?.isNotEmpty ?? false) ||
      canvas.canUndo;

  bool get canRedo =>
      (pdf.smartPenManager.smartPenRedo[pdf.historyKey]?.isNotEmpty ?? false) ||
      canvas.canRedo;

  void undo() {
    final pdfHistory = pdf.smartPenManager.smartPenUndo[pdf.historyKey];
    final currentStrokes = canvas.currentStrokes;
    final boardSequence = currentStrokes.isEmpty
        ? -1
        : (_boardUndoSequence[currentStrokes.last] ?? 0);
    final pdfSequence = pdfHistory == null || pdfHistory.isEmpty
        ? -1
        : pdfHistory.last.sequence;

    if (pdfHistory != null &&
        pdfHistory.isNotEmpty &&
        pdfSequence > boardSequence) {
      pdf.smartPenManager.undo();
      notifyListeners();
      return;
    }
    if (canvas.canUndo) {
      final stroke = currentStrokes.last;
      canvas.undo();
      _boardRedoSequence[stroke] = ++pdf.smartPenManager.historySequence;
      dirty = true;
      notifyListeners();
    }
  }

  void redo() {
    final pdfHistory = pdf.smartPenManager.smartPenRedo[pdf.historyKey];
    final currentRedo = canvas.currentRedoStack;
    final boardSequence = currentRedo.isEmpty
        ? -1
        : (_boardRedoSequence[currentRedo.last] ?? 0);
    final pdfSequence = pdfHistory == null || pdfHistory.isEmpty
        ? -1
        : pdfHistory.last.redoSequence;

    if (pdfHistory != null &&
        pdfHistory.isNotEmpty &&
        pdfSequence > boardSequence) {
      pdf.smartPenManager.redo();
      notifyListeners();
      return;
    }
    if (canvas.canRedo) {
      final stroke = currentRedo.last;
      canvas.redo();
      _boardUndoSequence[stroke] = ++pdf.smartPenManager.historySequence;
      dirty = true;
      notifyListeners();
    }
  }

  /// Exports entire lesson board, PDF annotations, and notes to a JSON payload.
  Map<String, dynamic> exportLessonJson() {
    Map<String, dynamic> serializeAnnotations(
      Map<int, List<BoardStroke>> annotations,
    ) =>
        annotations.map(
          (page, strokes) => MapEntry(
            page.toString(),
            strokes.map((stroke) => stroke.toJson()).toList(),
          ),
        );

    return {
      'title': title,
      'subject': subject,
      'notes': notes,
      'question': question,
      'page': canvas.page,
      'pages': canvas.pages.map((p) => p.map((s) => s.toJson()).toList()).toList(),
      'pageTitles': canvas.pageTitles,
      'pageNotes': canvas.pageNotes,
      'stickers': canvas.pageStickers.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'smartChalkAnnotations': canvas.pageChalkAnnotations.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'pdfChalkAnnotations': pdf.pdfChalkAnnotations.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'pdfAnnotations': serializeAnnotations(pdf.pdfAnnotations),
      'importedPdfDocuments': pdf.importedDocs.map((doc) {
        final annotations =
            doc.id == pdf.activeDocId ? pdf.pdfAnnotations : doc.annotations;
        return {
          'id': doc.id,
          'name': doc.name,
          'path': doc.path,
          'contentFingerprint': doc.contentFingerprint,
          'totalPages':
              doc.id == pdf.activeDocId ? pdf.pdfTotalPages : doc.totalPages,
          'annotations': serializeAnnotations(annotations),
        };
      }).toList(),
      'pdfFilePath': pdf.pdfFilePath,
      'pdfPage': pdf.pdfPage,
    };
  }

  /// Restores complete state from JSON representation.
  void restoreFromJson(Map<String, dynamic> json) {
    pdf.smartPenManager.resetSession(resetSavingDefault: true);
    pdf.pdfFilePath = null;
    pdf.pdfBytes = null;
    pdf.setPdfPage(1);
    pdf.setPdfTotalPages(1);
    pdf.activeDocId = null;
    pdf.importedDocs.clear();

    if (json['importedPdfDocuments'] is List) {
      for (final entry in json['importedPdfDocuments'] as List) {
        if (entry is! Map) continue;
        final documentJson = Map<String, dynamic>.from(entry);
        final name = documentJson['name'] as String?;
        if (name == null || name.isEmpty) continue;
        final document = ImportedDocument(
          id: documentJson['id'] as String? ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          path: documentJson['path'] as String?,
          contentFingerprint: documentJson['contentFingerprint'] as String?,
          totalPages: (documentJson['totalPages'] as num?)?.toInt() ?? 1,
        );
        final annotations = documentJson['annotations'];
        if (annotations is Map) {
          annotations.forEach((key, value) {
            final pageNumber = int.tryParse(key.toString());
            if (pageNumber == null || value is! List) return;
            document.annotations[pageNumber] = value
                .map(
                  (stroke) => BoardStroke.fromJson(
                    Map<String, dynamic>.from(stroke as Map),
                  ),
                )
                .toList();
          });
        }
        pdf.importedDocs.add(document);
      }
    }

    if (json.containsKey('pdfFilePath') && json['pdfFilePath'] is String) {
      final p = json['pdfFilePath'] as String;
      if (p.isNotEmpty) {
        pdf.setPdfFile(p);
      }
    }
    if (json.containsKey('pdfTotalPages')) {
      pdf.setPdfTotalPages((json['pdfTotalPages'] as num?)?.toInt() ?? 1);
    }

    if (json.containsKey('title')) title = json['title'] as String? ?? title;
    if (json.containsKey('subject')) subject = json['subject'] as String? ?? subject;
    if (json.containsKey('notes')) notes = json['notes'] as String? ?? notes;
    if (json.containsKey('question')) question = json['question'] as String? ?? question;

    if (json.containsKey('pageTitles') && json['pageTitles'] is List) {
      canvas.pageTitles
        ..clear()
        ..addAll((json['pageTitles'] as List).map((e) => e.toString()));
    }
    if (json.containsKey('pageNotes') && json['pageNotes'] is List) {
      canvas.pageNotes
        ..clear()
        ..addAll((json['pageNotes'] as List).map((e) => e.toString()));
    }
    if (json.containsKey('pages') && json['pages'] is List) {
      canvas.pages.clear();
      for (final p in json['pages'] as List) {
        if (p is List) {
          canvas.pages.add(
            p
                .map((s) => BoardStroke.fromJson(s as Map<String, dynamic>))
                .toList(),
          );
        }
      }
    }
    while (canvas.pageNotes.length < canvas.pages.length) {
      canvas.pageNotes.add('');
    }
    if (json.containsKey('stickers') && json['stickers'] is Map) {
      canvas.pageStickers.clear();
      final map = json['stickers'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 0;
        if (v is List) {
          canvas.pageStickers[pageIdx] = v
              .map(
                (s) => BoardSticker.fromJson(Map<String, dynamic>.from(s as Map)),
              )
              .toList();
        }
      });
    }
    if (json.containsKey('smartChalkAnnotations') &&
        json['smartChalkAnnotations'] is Map) {
      canvas.pageChalkAnnotations.clear();
      final map = json['smartChalkAnnotations'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 0;
        if (v is List) {
          canvas.pageChalkAnnotations[pageIdx] = v
              .map(
                (s) => SmartChalkAnnotation.fromJson(
                  Map<String, dynamic>.from(s as Map),
                ),
              )
              .toList();
        }
      });
    }

    if (json.containsKey('pdfChalkAnnotations') &&
        json['pdfChalkAnnotations'] is Map) {
      pdf.pdfChalkAnnotations.clear();
      final map = json['pdfChalkAnnotations'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 1;
        if (v is List) {
          pdf.pdfChalkAnnotations[pageIdx] = v
              .map(
                (s) => SmartChalkAnnotation.fromJson(
                  Map<String, dynamic>.from(s as Map),
                ),
              )
              .toList();
        }
      });
    }

    if (json.containsKey('pdfAnnotations') && json['pdfAnnotations'] is Map) {
      pdf.pdfAnnotations.clear();
      final map = json['pdfAnnotations'] as Map;
      map.forEach((key, value) {
        final pageNumber = int.tryParse(key.toString()) ?? 1;
        if (value is List) {
          pdf.pdfAnnotations[pageNumber] = value
              .map(
                (stroke) => BoardStroke.fromJson(
                  Map<String, dynamic>.from(stroke as Map),
                ),
              )
              .toList();
        }
      });
    }

    if (json.containsKey('page')) {
      canvas.page = (json['page'] as num?)?.toInt() ?? 0;
    }
    if (json.containsKey('pdfPage')) {
      pdf.setPdfPage((json['pdfPage'] as num?)?.toInt() ?? 1);
    }

    final restoredActiveDocument = pdf.activeDoc;
    if (restoredActiveDocument != null) {
      restoredActiveDocument.annotations
        ..clear()
        ..addAll(
          pdf.pdfAnnotations.map(
            (page, strokes) => MapEntry(page, List.of(strokes)),
          ),
        );
      restoredActiveDocument.totalPages = pdf.pdfTotalPages;
    }

    dirty = false;
    notifyListeners();
  }

  @override
  void dispose() {
    canvas.removeListener(_onChildChanged);
    pdf.removeListener(_onChildChanged);
    plugins.removeListener(_onChildChanged);
    audio.removeListener(_onChildChanged);

    canvas.dispose();
    pdf.dispose();
    audio.dispose();
    plugins.dispose();

    super.dispose();
  }
}

