import 'package:teaching_companion/core/utils/frontend_logger.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/widgets/pdf_annotation_save_indicator.dart';
import 'pdf_annotation_save_diagnostics.dart';

part 'pdf_annotation_handout_exporter.dart';

class PdfAnnotationExporter {
  /// Converts top-left normalized coordinates in the page's displayed
  /// orientation to the unrotated coordinates expected by Syncfusion's page
  /// graphics. Loaded pages keep their MediaBox dimensions in [PdfPage.size],
  /// while `page.graphics` applies the page `/Rotate` transform when saving.
  @visibleForTesting
  static Offset displayedNormalizedToPdfNormalized(
    Offset point,
    sf.PdfPageRotateAngle rotation,
  ) => switch (rotation) {
    sf.PdfPageRotateAngle.rotateAngle0 => point,
    sf.PdfPageRotateAngle.rotateAngle90 => Offset(point.dy, 1 - point.dx),
    sf.PdfPageRotateAngle.rotateAngle180 => Offset(1 - point.dx, 1 - point.dy),
    sf.PdfPageRotateAngle.rotateAngle270 => Offset(1 - point.dy, point.dx),
  };

  /// Xuất mảng byte PDF đã được ghi đè lớp TextMarkup Highlight Annotation chuẩn ISO-32000
  static Future<Uint8List?> exportHighlightedPdfBytes(
    StudioState studio, {
    PedagogicalHighlightPolicy? policy,
  }) async {
    Uint8List? sourceBytes = studio.pdfBytes;
    if (sourceBytes == null && studio.pdfFilePath != null) {
      final file = File(studio.pdfFilePath!);
      if (await file.exists()) {
        sourceBytes = await file.readAsBytes();
      }
    }

    if (sourceBytes == null || sourceBytes.isEmpty) return null;

    final doc = sf.PdfDocument(inputBytes: sourceBytes);
    final activePolicy = policy ?? studio.pedagogicalPolicy;

    final passages = studio.pdfDgnlPassages;
    for (final passage in passages) {
      if (passage.pageNumber < 1 || passage.pageNumber > doc.pages.count) {
        continue;
      }
      final page = doc.pages[passage.pageNumber - 1];
      final pageSize = page.size;

      final spansToUse =
          passage.activeFilteredSpans ??
          activePolicy.filterSpans(passage.spans);
      final dedupedSpans = deduplicateSpansForRendering(spansToUse);

      for (final span in dedupedSpans) {
        final isNestedInColloc =
            span.category == 'vocabulary' &&
            dedupedSpans.any(
              (other) =>
                  other.category == 'collocation' &&
                  _isSpanContained(span, other),
            );
        final isNestedInGrammar =
            span.category == 'vocabulary' &&
            dedupedSpans.any(
              (other) =>
                  other.category == 'grammar' && _isSpanContained(span, other),
            );

        final style = DgnlHighlightPalette.resolveRenderingStyle(
          span: span,
          isNestedInCollocation: isNestedInColloc,
          isNestedInGrammar: isNestedInGrammar,
        );

        final rgb = DgnlHighlightPalette.toRgb(style.color);
        final highlightColor = sf.PdfColor(rgb.r, rgb.g, rgb.b);

        for (final normR in span.normalizedRects) {
          final x = normR.left * pageSize.width;
          final y = normR.top * pageSize.height;
          final w = normR.width * pageSize.width;
          final h = normR.height * pageSize.height;

          if (w <= 0 || h <= 0) continue;

          if (style.isDashed) {
            // Grammar: Outer dashed border, 0% brush fill to keep background transparent & readable
            final pen = sf.PdfPen(highlightColor, width: style.borderWidth);
            pen.dashStyle = sf.PdfDashStyle.dash;
            page.graphics.save();
            page.graphics.setTransparency(style.borderOpacity);
            page.graphics.drawRectangle(
              pen: pen,
              bounds: Rect.fromLTWH(x - 2, y - 2, w + 4, h + 4),
            );
            page.graphics.restore();
          } else if (style.isHollow) {
            // Nested Vocab inside Collocation: Clean thin outline pen, zero background fill to prevent double-brush mud
            final pen = sf.PdfPen(highlightColor, width: style.borderWidth);
            page.graphics.save();
            page.graphics.setTransparency(style.borderOpacity);
            page.graphics.drawRectangle(
              pen: pen,
              bounds: Rect.fromLTWH(x, y, w, h),
            );
            page.graphics.restore();
          } else {
            // Collocation or Standalone Vocab / Vocab in Grammar:
            // Soft pastel solid brush with centralized adaptive opacity
            page.graphics.save();
            page.graphics.setTransparency(style.fillOpacity);
            page.graphics.drawRectangle(
              brush: sf.PdfSolidBrush(highlightColor),
              bounds: Rect.fromLTWH(x, y, w, h),
            );
            page.graphics.restore();

            // Text markup annotation for PDF readers (ISO-32000)
            final annotation = sf.PdfTextMarkupAnnotation(
              Rect.fromLTWH(x, y, w, h),
              span.text,
              highlightColor,
              author: 'Học Lực - Trợ giảng Tiếng Anh',
              subject: '[${span.type}] ${span.note}',
              textMarkupAnnotationType:
                  sf.PdfTextMarkupAnnotationType.highlight,
            );
            annotation.opacity = style.fillOpacity;
            page.annotations.add(annotation);
          }
        }
      }
    }

    // PDF ink, including Smart Pen answer ovals, is stored in normalized page
    // coordinates. Export it as vector lines so it remains crisp when printed.
    for (final entry in studio.pdfAnnotations.entries) {
      if (entry.key < 1 || entry.key > doc.pages.count) continue;
      final page = doc.pages[entry.key - 1];
      final pageSize = page.size;
      for (final stroke in entry.value) {
        if (stroke.rect != null || stroke.points.isEmpty) continue;
        final color = stroke.color;
        final argb = color.toARGB32();
        final pen = sf.PdfPen(
          sf.PdfColor((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff),
          width: stroke.width,
        )..lineCap = sf.PdfLineCap.round;
        final points = stroke.points.map((point) {
          final pdfNormalized = displayedNormalizedToPdfNormalized(
            point,
            page.rotation,
          );
          return Offset(
            pdfNormalized.dx * pageSize.width,
            pdfNormalized.dy * pageSize.height,
          );
        }).toList();
        if (points.length == 1) {
          final radius = stroke.width / 2;
          page.graphics.drawEllipse(
            Rect.fromCircle(center: points.single, radius: radius),
            pen: pen,
          );
          continue;
        }
        for (var i = 1; i < points.length; i++) {
          page.graphics.drawLine(pen, points[i - 1], points[i]);
        }
        if (stroke.isGroupedPdfAnnotation) {
          page.graphics.drawLine(pen, points.last, points.first);
        }
      }
    }

    final outputBytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(outputBytes);
  }

  static bool _isSpanContained(
    PdfDgnlHighlightSpan inner,
    PdfDgnlHighlightSpan outer,
  ) {
    if (identical(inner, outer)) return false;
    final innerText = inner.text.toLowerCase().trim();
    final outerText = outer.text.toLowerCase().trim();
    if (outerText.contains(innerText) && outerText != innerText) {
      return true;
    }
    for (final iRect in inner.normalizedRects) {
      for (final oRect in outer.normalizedRects) {
        final oExpanded = Rect.fromLTRB(
          oRect.left - 0.005,
          oRect.top - 0.005,
          oRect.right + 0.005,
          oRect.bottom + 0.005,
        );
        if (oExpanded.contains(iRect.center)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Kiểm tra xem hai span có tọa độ trùng lặp hoặc lồng nhau >= 75% hay không
  static bool _isExactOrNearDuplicate(
    PdfDgnlHighlightSpan a,
    PdfDgnlHighlightSpan b,
  ) {
    if (identical(a, b)) return true;
    if (a.normalizedRects.isEmpty || b.normalizedRects.isEmpty) return false;
    for (final ra in a.normalizedRects) {
      for (final rb in b.normalizedRects) {
        final intersection = ra.intersect(rb);
        if (intersection.width > 0 && intersection.height > 0) {
          final interArea = intersection.width * intersection.height;
          final minArea = math.min(ra.width * ra.height, rb.width * rb.height);
          if (minArea > 0 && (interArea / minArea) >= 0.75) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Khử trùng lặp và phân tách kênh hiển thị trước khi ghi vào PDF hoặc lưu vào StudioState.
  /// 1. Loại bỏ các span trùng lặp chính xác cùng category.
  /// 2. Nếu hai span vocabulary chồng lấn nhau trên cùng một vùng chữ (ví dụ: 'bitter' và 'bitterness'):
  ///    ưu tiên giữ span có độ dài ký tự lớn hơn / cụ thể hơn để tránh tô đè 2 màu từ vựng.
  /// 3. Bảo toàn các span khác category (Grammar + Vocab, Collocation + Vocab) để phục vụ sư phạm.
  @visibleForTesting
  static List<PdfDgnlHighlightSpan> deduplicateSpansForRendering(
    List<PdfDgnlHighlightSpan> spans,
  ) {
    final result = <PdfDgnlHighlightSpan>[];
    for (final span in spans) {
      // 1. Kiểm tra trùng lặp trong cùng phân loại
      final duplicateCategoryIdx = result.indexWhere(
        (existing) =>
            existing.category == span.category &&
            _isExactOrNearDuplicate(existing, span),
      );
      if (duplicateCategoryIdx != -1) {
        // Trong cùng category, nếu span mới có từ cụ thể hơn, thay thế span cũ
        if (span.text.length > result[duplicateCategoryIdx].text.length) {
          result[duplicateCategoryIdx] = span;
        }
        continue;
      }

      // 2. Nếu là từ vựng (vocabulary) chồng lấn với một từ vựng khác:
      if (span.category == 'vocabulary') {
        final existingVocabIdx = result.indexWhere(
          (existing) =>
              existing.category == 'vocabulary' &&
              _isExactOrNearDuplicate(existing, span),
        );
        if (existingVocabIdx != -1) {
          if (span.text.length > result[existingVocabIdx].text.length) {
            result[existingVocabIdx] = span;
          }
          continue;
        }
      }

      result.add(span);
    }
    return result;
  }

  /// Áp highlight thẳng lên tài liệu PDF hiện tại mà KHÔNG bật hộp thoại lưu file (Zero-dialog in-place)
  static Future<bool> applyHighlightDirectlyToPdf(
    BuildContext context,
    StudioState studio, {
    bool showFeedback = true,
    PedagogicalHighlightPolicy? policy,
    String? passageId,
    List<PdfDgnlHighlightSpan>? selectedSpans,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final operationId = PdfAnnotationSaveDiagnostics.newOperationId(
      'highlight',
    );
    final operationTimer = Stopwatch()..start();
    PdfAnnotationSaveIndicatorToken? savingIndicator;
    Stopwatch? savingUiTimer;
    Timer? savingIndicatorDelay;
    var persistenceCompleted = false;
    VoidCallback? documentSwitchListener;
    final originalDocumentKey = studio.pdf.historyKey;
    var indicatorHiddenForDocumentSwitch = false;

    final hasInkAnnotations = studio.pdfAnnotations.values.any(
      (annotations) => annotations.isNotEmpty,
    );
    if (studio.pdfDgnlPassages.isEmpty && !hasInkAnnotations) {
      if (showFeedback) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa có đoạn văn nào được quét để highlight lên file.',
            ),
            backgroundColor: Color(0xf0201815),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    try {
      final activePolicy = policy ?? studio.pedagogicalPolicy;
      final preparationTimer = Stopwatch()..start();
      var appliedSpanCount = 0;
      final additions = <int, List<BoardStroke>>{};
      final occupiedRects = <int, Set<Rect>>{};
      // 1. Ghi vĩnh viễn các điểm highlight vào canvas nét vẽ (BoardStroke) của PDF trong StudioState
      // Giúp highlight tồn tại vĩnh viễn trên màn hình ngay cả khi tắt extension hay đóng thẻ card
      for (final passage in studio.pdfDgnlPassages) {
        if (passageId != null && passage.id != passageId) continue;
        final page = passage.pageNumber;
        final occupied = occupiedRects.putIfAbsent(
          page,
          () => {
            for (final existing in studio.pdfAnnotations[page] ?? const [])
              if (existing.rect != null) existing.rect!,
          },
        );
        final pageAdditions = additions.putIfAbsent(page, () => []);
        final explicitSelection =
            (passageId == passage.id ? selectedSpans : null) ??
            passage.activeFilteredSpans;
        final spansToApply =
            explicitSelection ??
            deduplicateSpansForRendering(
              activePolicy.filterSpans(passage.spans),
            );
        final collocationSpans = spansToApply
            .where((span) => span.category == 'collocation')
            .toList(growable: false);
        final grammarSpans = spansToApply
            .where((span) => span.category == 'grammar')
            .toList(growable: false);
        for (final span in spansToApply) {
          final isNestedInColloc =
              span.category == 'vocabulary' &&
              collocationSpans.any((other) => _isSpanContained(span, other));
          final isNestedInGrammar =
              span.category == 'vocabulary' &&
              grammarSpans.any((other) => _isSpanContained(span, other));

          final style = DgnlHighlightPalette.resolveRenderingStyle(
            span: span,
            isNestedInCollocation: isNestedInColloc,
            isNestedInGrammar: isNestedInGrammar,
          );

          final isHollow = style.isHollow;
          final strokeWidth = isHollow ? style.borderWidth : 20.0;
          final opacity = isHollow ? style.borderOpacity : style.fillOpacity;

          var spanWasAdded = false;
          for (final normR in span.normalizedRects) {
            if (occupied.add(normR)) {
              final newStroke = BoardStroke(
                style.color,
                strokeWidth,
                [
                  Offset(normR.left, normR.top),
                  Offset(normR.right, normR.bottom),
                ],
                id: '${passage.id}_${span.category}_${span.level}_${normR.left.toStringAsFixed(3)}_${normR.top.toStringAsFixed(3)}',
                rect: normR,
                isHollow: isHollow,
                isDashed: style.isDashed,
                text: span.text,
                category: span.category,
                level: span.level,
                opacity: opacity,
              );
              pageAdditions.add(newStroke);
              spanWasAdded = true;
            }
          }
          if (spanWasAdded) appliedSpanCount++;
        }
      }

      // 2. Non-destructive persistence: Lưu lớp chú thích riêng biệt, tuyệt đối không ghi đè tệp gốc
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'batch_preparation',
        duration: preparationTimer.elapsed,
        fields: {
          'spans': appliedSpanCount,
          'annotations': additions.values.fold<int>(
            0,
            (total, strokes) => total + strokes.length,
          ),
          'pages': additions.length,
          'pdfBytes': studio.pdfBytes?.length ?? 0,
        },
      );
      studio.dirty = true;
      final persistence = appliedSpanCount == 0
          ? Future<bool>.value(true)
          : studio.pdf.recordAnnotationsAdded(
              additions,
              operationId: operationId,
            );
      if (appliedSpanCount > 0 && showFeedback) {
        savingUiTimer = Stopwatch()..start();
        final overlay = Overlay.maybeOf(context, rootOverlay: true);
        documentSwitchListener = () {
          if (studio.pdf.historyKey != originalDocumentKey &&
              !indicatorHiddenForDocumentSwitch) {
            indicatorHiddenForDocumentSwitch = true;
            savingIndicatorDelay?.cancel();
            PdfAnnotationSaveIndicator.hide(savingIndicator);
            PdfAnnotationSaveDiagnostics.log(
              operationId,
              'ui_saving_state',
              duration: savingUiTimer?.elapsed,
              fields: {'status': 'document_switched'},
            );
          }
        };
        studio.pdf.addListener(documentSwitchListener);
        savingIndicatorDelay = Timer(const Duration(milliseconds: 160), () {
          if (!persistenceCompleted &&
              !indicatorHiddenForDocumentSwitch &&
              studio.pdf.historyKey == originalDocumentKey) {
            savingIndicator = PdfAnnotationSaveIndicator.showOnOverlay(
              overlay,
              operationId,
            );
          }
        });
      }

      final saved = await persistence;
      persistenceCompleted = true;
      savingIndicatorDelay?.cancel();
      if (documentSwitchListener != null) {
        studio.pdf.removeListener(documentSwitchListener);
        documentSwitchListener = null;
      }
      final documentUnchanged = studio.pdf.historyKey == originalDocumentKey;
      if (appliedSpanCount > 0 && showFeedback) {
        if (!indicatorHiddenForDocumentSwitch) {
          PdfAnnotationSaveIndicator.hide(savingIndicator);
          PdfAnnotationSaveDiagnostics.log(
            operationId,
            'ui_saving_state',
            duration: savingUiTimer?.elapsed,
            fields: {
              'status': saved ? 'success' : 'error',
              'documentUnchanged': documentUnchanged,
            },
          );
        }
      }
      if (!saved) {
        if (showFeedback && (messenger?.mounted ?? false)) {
          messenger?.showSnackBar(
            SnackBar(
              content: Text(
                'Highlight đã áp dụng trong phiên này nhưng chưa lưu được. ${studio.pdf.annotationPersistenceError ?? ''}',
              ),
              action: SnackBarAction(
                label: 'Thử lưu lại',
                onPressed: () => studio.pdf.retryAnnotationPersistence(),
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
        PdfAnnotationSaveDiagnostics.log(
          operationId,
          'operation_total',
          duration: operationTimer.elapsed,
          fields: {
            'annotations': additions.values.fold<int>(
              0,
              (total, strokes) => total + strokes.length,
            ),
            'status': 'error',
          },
        );
        return false;
      }

      if (showFeedback && documentUnchanged && (messenger?.mounted ?? false)) {
        messenger?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xff86efac),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã lưu $appliedSpanCount điểm highlight vào lớp chú thích (tệp PDF gốc được bảo toàn)!',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xf0111a15),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'operation_total',
        duration: operationTimer.elapsed,
        fields: {
          'annotations': additions.values.fold<int>(
            0,
            (total, strokes) => total + strokes.length,
          ),
          'status': 'success',
        },
      );
      return true;
    } catch (e) {
      persistenceCompleted = true;
      savingIndicatorDelay?.cancel();
      if (documentSwitchListener != null) {
        studio.pdf.removeListener(documentSwitchListener);
      }
      PdfAnnotationSaveIndicator.hide(savingIndicator);
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'operation_total',
        duration: operationTimer.elapsed,
        fields: {'status': 'error', 'errorType': e.runtimeType},
      );
      FrontendLogger.write(
        '[PdfAnnotationExporter] applyHighlightDirectlyToPdf error: ${e.runtimeType}',
      );
      if (showFeedback && (messenger?.mounted ?? false)) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Lỗi khi áp highlight lên file: $e'),
            backgroundColor: const Color(0xf03b1111),
          ),
        );
      }
      return false;
    }
  }

  /// Hộp thoại lưu file PDF đã được highlight vĩnh viễn (Save As ra tệp mới)
  static Future<String?> saveHighlightedPdf(
    BuildContext context,
    StudioState studio,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final hasInkAnnotations = studio.pdfAnnotations.values.any(
      (annotations) => annotations.isNotEmpty,
    );
    if (studio.pdfDgnlPassages.isEmpty && !hasInkAnnotations) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa có đoạn văn nào được highlight để lưu vào file PDF.',
          ),
          backgroundColor: Color(0xf0201815),
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }

    try {
      final bytes = await exportHighlightedPdfBytes(studio);
      if (bytes == null) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Không thể đọc dữ liệu PDF hiện tại để xuất file.'),
            backgroundColor: Color(0xf03b1111),
          ),
        );
        return null;
      }

      String suggestedName = 'bai_giang_highlighted.pdf';
      if (studio.pdfFilePath != null && studio.pdfFilePath!.isNotEmpty) {
        final raw = studio.pdfFilePath!.replaceAll(r'\', '/').split('/').last;
        final dot = raw.lastIndexOf('.');
        final base = dot != -1 ? raw.substring(0, dot) : raw;
        suggestedName = '${base}_highlighted.pdf';
      }

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Lưu tệp PDF đã Highlight vĩnh viễn',
        fileName: suggestedName,
        bytes: bytes,
        mimeType: 'application/pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savedUri == null) {
        return null; // Người dùng nhấn Cancel
      }

      String finalPath;
      if (savedUri.hasScheme && savedUri.scheme == 'file') {
        finalPath = savedUri.toFilePath();
      } else {
        finalPath = savedUri.path;
      }

      if (finalPath.trim().isEmpty) {
        return null;
      }

      finalPath = finalPath.trim();
      if (!finalPath.toLowerCase().endsWith('.pdf')) {
        finalPath = '$finalPath.pdf';
      }

      if (studio.pdfFilePath != null && studio.pdfFilePath!.isNotEmpty) {
        final srcNorm = studio.pdfFilePath!.replaceAll(r'\', '/').toLowerCase();
        final outNorm = finalPath.replaceAll(r'\', '/').toLowerCase();
        if (srcNorm == outNorm) {
          messenger?.showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể xuất đè lên tệp PDF gốc để bảo toàn tài liệu. Vui lòng chọn tên tệp khác.',
              ),
              backgroundColor: Color(0xf03b1111),
              duration: Duration(seconds: 4),
            ),
          );
          return null;
        }
      }

      final outFile = File(finalPath);
      await outFile.writeAsBytes(bytes);

      final displayFile = finalPath.replaceAll(r'\', '/').split('/').last;

      messenger?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xff86efac),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã xuất bản sao PDF có highlight tại: $displayFile (tệp gốc không bị ảnh hưởng)!',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xf0111a15),
          duration: const Duration(seconds: 5),
        ),
      );

      return finalPath;
    } catch (e) {
      FrontendLogger.write(
        '[PdfAnnotationExporter] Error saving highlighted PDF: $e',
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu PDF: $e'),
          backgroundColor: const Color(0xf03b1111),
        ),
      );
      return null;
    }
  }

  /// Xuất toàn bộ các slide / trang bảng viết ra tệp PDF hoàn chỉnh
  static Future<String?> exportChalkboardSlidesToPdf(
    BuildContext context,
    StudioState studio,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final doc = sf.PdfDocument();
      doc.pageSettings.orientation = sf.PdfPageOrientation.landscape;
      doc.pageSettings.size = const Size(960, 540);

      final totalPages = studio.pages.isEmpty ? 1 : studio.pages.length;

      for (int i = 0; i < totalPages; i++) {
        final page = doc.pages.add();
        final pageSize = page.size;

        // Vẽ nền bảng viết màu xanh đậm
        page.graphics.drawRectangle(
          brush: sf.PdfSolidBrush(sf.PdfColor(27, 43, 37)),
          bounds: Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        );

        // Vẽ tiêu đề trang slide (nếu có)
        final pageTitle = i < studio.pageTitles.length
            ? studio.pageTitles[i]
            : 'Trang ${i + 1}';
        final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12);
        page.graphics.drawString(
          pageTitle,
          font,
          brush: sf.PdfSolidBrush(sf.PdfColor(200, 220, 200)),
          bounds: Rect.fromLTWH(20, 15, pageSize.width - 40, 20),
        );

        // Vẽ các nét vẽ trên trang bảng
        if (i < studio.pages.length) {
          final strokes = studio.pages[i];
          for (final s in strokes) {
            if (s.points.isEmpty && s.rect == null) continue;
            final rVal = (s.color.r * 255.0).round().clamp(0, 255);
            final gVal = (s.color.g * 255.0).round().clamp(0, 255);
            final bVal = (s.color.b * 255.0).round().clamp(0, 255);
            final pen = sf.PdfPen(
              sf.PdfColor(rVal, gVal, bVal),
              width: s.width,
            );
            if (s.rect != null) {
              final r = Rect.fromLTWH(
                s.rect!.left * pageSize.width,
                s.rect!.top * pageSize.height,
                s.rect!.width * pageSize.width,
                s.rect!.height * pageSize.height,
              );
              if (s.isHollow) {
                page.graphics.save();
                page.graphics.setTransparency(
                  s.color.a < 1.0 ? s.color.a : 0.85,
                );
                page.graphics.drawRectangle(pen: pen, bounds: r);
                page.graphics.restore();
              } else {
                page.graphics.save();
                page.graphics.setTransparency(
                  s.color.a < 1.0 ? s.color.a : 0.22,
                );
                page.graphics.drawRectangle(
                  brush: sf.PdfSolidBrush(sf.PdfColor(rVal, gVal, bVal)),
                  bounds: r,
                );
                page.graphics.restore();
              }
            } else if (s.points.length == 1) {
              final pt = Offset(
                s.points[0].dx * pageSize.width,
                s.points[0].dy * pageSize.height,
              );
              page.graphics.drawRectangle(
                brush: sf.PdfSolidBrush(sf.PdfColor(rVal, gVal, bVal)),
                bounds: Rect.fromLTWH(
                  pt.dx - s.width / 2,
                  pt.dy - s.width / 2,
                  s.width,
                  s.width,
                ),
              );
            } else {
              for (int j = 0; j < s.points.length - 1; j++) {
                final p1 = Offset(
                  s.points[j].dx * pageSize.width,
                  s.points[j].dy * pageSize.height,
                );
                final p2 = Offset(
                  s.points[j + 1].dx * pageSize.width,
                  s.points[j + 1].dy * pageSize.height,
                );
                page.graphics.drawLine(pen, p1, p2);
              }
            }
          }
        }
      }

      final bytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      final cleanTitle = studio.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final suggestedName = '${cleanTitle}_slides.pdf';

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Lưu Slide bài giảng dạng PDF',
        fileName: suggestedName,
        bytes: bytes,
        mimeType: 'application/pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savedUri == null) return null;

      String finalPath;
      if (savedUri.hasScheme && savedUri.scheme == 'file') {
        finalPath = savedUri.toFilePath();
      } else {
        finalPath = savedUri.path;
      }
      if (!finalPath.toLowerCase().endsWith('.pdf')) {
        finalPath = '$finalPath.pdf';
      }

      final outFile = File(finalPath);
      if (!await outFile.exists() || await outFile.length() == 0) {
        await outFile.writeAsBytes(bytes);
      }

      final displayFile = finalPath.replaceAll(r'\', '/').split('/').last;
      messenger?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xff86efac),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã xuất $totalPages trang slide bảng ra: $displayFile',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xf0111a15),
          duration: const Duration(seconds: 4),
        ),
      );
      return finalPath;
    } catch (e) {
      FrontendLogger.write(
        '[PdfAnnotationExporter] exportChalkboardSlidesToPdf error: $e',
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xuất slide ra PDF: $e'),
          backgroundColor: const Color(0xf03b1111),
        ),
      );
      return null;
    }
  }

  /// Tạo mảng byte PDF cho tài liệu Handout (mỗi trang gồm Slide bảng viết phía trên + Ghi chú bài giảng phía dưới)
  static Future<Uint8List> generateHandoutPdfBytes(StudioState studio) =>
      _generateHandoutPdfBytesImpl(studio);

  /// Xuất tài liệu Handout (Slide kèm Ghi chú diễn giải) ra tệp PDF và mở hộp thoại lưu tệp
  static Future<String?> exportHandoutWithNotesToPdf(
    BuildContext context,
    StudioState studio,
  ) => _exportHandoutWithNotesToPdfImpl(context, studio);

  /// Lưu file PDF của bài học (ưu tiên tệp PDF đang mở nếu có, hoặc xuất slide bảng thành PDF)
  static Future<String?> saveLecturePdf(
    BuildContext context,
    StudioState studio,
  ) => _saveLecturePdfImpl(context, studio);
}
