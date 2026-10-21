// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'studio_state.dart';

extension StudioStatePersistence on StudioState {
  /// Replace lesson content without changing the classroom, media or audio state.
  void openLiveLesson(Map<String, dynamic> json) {
    notes = '';
    question = '';
    page = 0;
    pages = [[]];
    pageTitles = [];
    pageNotes = [];
    pageStickers.clear();
    pageChalkAnnotations.clear();
    pdfChalkAnnotations.clear();
    _redoPages = null;
    restoreFromJson(json);
    view = 'board';
    online = true;
    savedAt = '';
    notifyListeners();
  }

  Map<String, dynamic> exportLessonJson() {
    Map<String, dynamic> serializePdfAnnotations(
      Map<int, List<BoardStroke>> annotations,
    ) => annotations.map(
      (page, strokes) => MapEntry(
        page.toString(),
        strokes.map((stroke) => stroke.toJson()).toList(),
      ),
    );

    ensurePageIds();
    return {
      'boardRevision': boardRevision,
      if (hasLiveTeacherContext && preparationDocument != null)
        'teacherPreparation': preparationDocument,
      if (preparationProjection != null)
        'preparationProjection': preparationProjection,
      if (teacherCuesEdited) ...{
        'teacherCueUpdates': preparationDocument?['teacherCues'] ?? [],
        'expectedPreparationRevision': preparationDocument?['revision'] ?? 0,
      },
      'pageIds': List<String>.of(pageIds),
      'title': title,
      'subject': subject,
      'notes': notes,
      'question': question,
      'page': page,
      'pages': pages.map((p) => p.map((s) => s.toJson()).toList()).toList(),
      'pageTitles': pageTitles,
      'pageNotes': pageNotes,
      'stickers': pageStickers.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'smartChalkAnnotations': pageChalkAnnotations.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'pdfChalkAnnotations': pdfChalkAnnotations.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'pdfAnnotations': pdfAnnotations.map(
        (k, v) =>
            MapEntry(k.toString(), v.map((stroke) => stroke.toJson()).toList()),
      ),
      'importedPdfDocuments': importedDocs.map((document) {
        final annotations = document.id == activeDocId
            ? pdfAnnotations
            : document.annotations;
        return {
          'id': document.id,
          'name': document.name,
          'path': document.path,
          'contentFingerprint':
              document.contentFingerprint ??
              (document.bytes == null
                  ? null
                  : _pdfContentFingerprint(document.bytes!)),
          'totalPages': document.id == activeDocId
              ? pdfTotalPages
              : document.totalPages,
          'annotations': serializePdfAnnotations(annotations),
        };
      }).toList(),
      'pdfFilePath': pdfFilePath,
      'pdfPage': pdfPage,
      'pdfWindowMaximized': _pdfWindowMaximized,
      'hasCustomPdfWindowPos': hasCustomPdfWindowPos,
      'pdfWindowX': _pdfWindowPosition?.dx,
      'pdfWindowY': _pdfWindowPosition?.dy,
      'hasCustomPdfWindowSize': hasCustomPdfWindowSize,
      'pdfWindowW': _pdfWindowSize?.width,
      'pdfWindowH': _pdfWindowSize?.height,
    };
  }

  void restoreFromJson(Map<String, dynamic> json) {
    final teacherContext = json['preparation'] ?? json['teacherPreparation'];
    hasLiveTeacherContext = json['teacherPreparation'] is Map;
    preparationDocument = teacherContext is Map
        ? Map<String, dynamic>.from(
            jsonDecode(jsonEncode(teacherContext)) as Map,
          )
        : null;
    preparationProjection = json['preparationProjection'] is Map
        ? Map<String, dynamic>.from(json['preparationProjection'] as Map)
        : null;
    boardRevision = (json['boardRevision'] as num?)?.toInt() ?? 0;
    teacherCuesEdited = false;
    presentedActivityId = null;
    _pinnedTeacherTarget = null;
    _pinnedTeacherActivityId = null;
    // This is a session preference, not lesson data. Loading any lesson starts
    // with the safe default that new answer circles are saved.
    _saveAnswerCirclesEnabled = true;
    // Session-only answer overrides and their undo history belong to the
    // previous lesson/PDF session, even when the incoming lesson has no PDF.
    _temporarySmartPenOverrides.clear();
    _clearSmartPenHistory();
    // A restored lesson may have no active PDF even when this StudioState was
    // previously showing one. Reset the old view before restoring document
    // metadata so a closed-document lesson cannot keep displaying stale bytes.
    pdfFilePath = null;
    pdfBytes = null;
    pdfPage = 1;
    pdfTotalPages = 1;
    pdfAnnotations.clear();
    activeDocId = null;
    importedDocs.clear();
    if (json['importedPdfDocuments'] is List) {
      for (final entry in json['importedPdfDocuments'] as List) {
        if (entry is! Map) continue;
        final documentJson = Map<String, dynamic>.from(entry);
        final name = documentJson['name'] as String?;
        if (name == null || name.isEmpty) continue;
        final document = ImportedDocument(
          id:
              documentJson['id'] as String? ??
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
        importedDocs.add(document);
      }
    }
    if (json.containsKey('title')) title = json['title'] as String? ?? title;
    if (json.containsKey('subject')) {
      subject = json['subject'] as String? ?? subject;
    }
    if (json.containsKey('notes')) {
      notes = json['notes'] as String? ?? notes;
    }
    if (json.containsKey('question')) {
      question = json['question'] as String? ?? question;
    }
    if (json.containsKey('page')) page = (json['page'] as num?)?.toInt() ?? 0;
    if (json.containsKey('pdfFilePath') && json['pdfFilePath'] is String) {
      final p = json['pdfFilePath'] as String;
      if (p.isNotEmpty) {
        setPdfFile(p);
      }
    }
    if (json.containsKey('pdfPage') && json['pdfPage'] is num) {
      pdfPage = (json['pdfPage'] as num).toInt();
    }
    if (json.containsKey('pdfWindowMaximized') &&
        json['pdfWindowMaximized'] is bool) {
      _pdfWindowMaximized = json['pdfWindowMaximized'] as bool;
    }
    if (json.containsKey('hasCustomPdfWindowPos') &&
        json['hasCustomPdfWindowPos'] == true) {
      final x = (json['pdfWindowX'] as num?)?.toDouble() ?? 0.0;
      final y = (json['pdfWindowY'] as num?)?.toDouble() ?? 0.0;
      setPdfWindowPosition(Offset(x, y));
    }
    if (json.containsKey('hasCustomPdfWindowSize') &&
        json['hasCustomPdfWindowSize'] == true) {
      final w = (json['pdfWindowW'] as num?)?.toDouble() ?? 540.0;
      final h = (json['pdfWindowH'] as num?)?.toDouble() ?? 720.0;
      setPdfWindowSize(Size(w, h));
    }
    if (json.containsKey('pageTitles') && json['pageTitles'] is List) {
      pageTitles
        ..clear()
        ..addAll((json['pageTitles'] as List).map((e) => e.toString()));
    }
    if (json.containsKey('pageNotes') && json['pageNotes'] is List) {
      pageNotes
        ..clear()
        ..addAll((json['pageNotes'] as List).map((e) => e.toString()));
    }
    if (json.containsKey('pages') && json['pages'] is List) {
      pages.clear();
      for (final p in json['pages'] as List) {
        if (p is List) {
          pages.add(
            p
                .map((s) => BoardStroke.fromJson(s as Map<String, dynamic>))
                .toList(),
          );
        }
      }
    }
    while (pageNotes.length < pages.length) {
      pageNotes.add('');
    }
    pageIds = (json['pageIds'] is List)
        ? (json['pageIds'] as List).map((v) => v.toString()).toList()
        : [];
    ensurePageIds();
    if (json.containsKey('stickers') && json['stickers'] is Map) {
      pageStickers.clear();
      final map = json['stickers'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 0;
        if (v is List) {
          pageStickers[pageIdx] = v
              .map(
                (s) =>
                    BoardSticker.fromJson(Map<String, dynamic>.from(s as Map)),
              )
              .toList();
        }
      });
    }
    if (json.containsKey('smartChalkAnnotations') &&
        json['smartChalkAnnotations'] is Map) {
      pageChalkAnnotations.clear();
      final map = json['smartChalkAnnotations'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 0;
        if (v is List) {
          pageChalkAnnotations[pageIdx] = v
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
      pdfChalkAnnotations.clear();
      final map = json['pdfChalkAnnotations'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 1;
        if (v is List) {
          pdfChalkAnnotations[pageIdx] = v
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
      pdfAnnotations.clear();
      final map = json['pdfAnnotations'] as Map;
      map.forEach((key, value) {
        final pageNumber = int.tryParse(key.toString()) ?? 1;
        if (value is List) {
          pdfAnnotations[pageNumber] = value
              .map(
                (stroke) => BoardStroke.fromJson(
                  Map<String, dynamic>.from(stroke as Map),
                ),
              )
              .toList();
        }
      });
    }
    final restoredActiveDocument = activeDoc;
    if (restoredActiveDocument != null) {
      restoredActiveDocument.annotations
        ..clear()
        ..addAll(
          pdfAnnotations.map(
            (page, strokes) => MapEntry(page, List.of(strokes)),
          ),
        );
      restoredActiveDocument.totalPages = pdfTotalPages;
    }
    dirty = false;
    _revision++;
    notifyListeners();
  }
}
