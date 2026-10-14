import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/studio_state.dart';

class PdfAnnotationExporter {
  /// Xuất mảng byte PDF đã được ghi đè lớp TextMarkup Highlight Annotation chuẩn ISO-32000
  static Future<Uint8List?> exportHighlightedPdfBytes(StudioState studio) async {
    Uint8List? sourceBytes = studio.pdfBytes;
    if (sourceBytes == null && studio.pdfFilePath != null) {
      final file = File(studio.pdfFilePath!);
      if (await file.exists()) {
        sourceBytes = await file.readAsBytes();
      }
    }

    if (sourceBytes == null || sourceBytes.isEmpty) return null;

    final doc = sf.PdfDocument(inputBytes: sourceBytes);

    final passages = studio.pdfDgnlPassages;
    for (final passage in passages) {
      if (passage.pageNumber < 1 || passage.pageNumber > doc.pages.count) continue;
      final page = doc.pages[passage.pageNumber - 1];
      final pageSize = page.size;

      for (final span in passage.spans) {
        final isGrammar = span.category == 'grammar';
        final isCollocation = span.category == 'collocation';
        final isNestedVocab = span.category == 'vocabulary' &&
            passage.spans.any((other) => other.category == 'collocation' && _isSpanContained(span, other));

        sf.PdfColor highlightColor;
        if (isGrammar) {
          highlightColor = sf.PdfColor(137, 180, 250); // Cyan/blue
        } else if (isCollocation) {
          highlightColor = sf.PdfColor(134, 239, 172); // Emerald green
        } else if (span.level == 'C1' || span.level == 'C2') {
          highlightColor = sf.PdfColor(203, 166, 247); // Purple C1
        } else {
          highlightColor = sf.PdfColor(249, 226, 175); // Amber/yellow B2
        }

        for (final normR in span.normalizedRects) {
          final x = normR.left * pageSize.width;
          final y = normR.top * pageSize.height;
          final w = normR.width * pageSize.width;
          final h = normR.height * pageSize.height;

          if (w <= 0 || h <= 0) continue;

          if (isGrammar) {
            // Grammar: Outer dashed border, 0% brush fill to keep background transparent & readable
            final pen = sf.PdfPen(highlightColor, width: 1.5);
            pen.dashStyle = sf.PdfDashStyle.dash;
            page.graphics.drawRectangle(
              pen: pen,
              bounds: Rect.fromLTWH(x - 2, y - 2, w + 4, h + 4),
            );
          } else if (isNestedVocab) {
            // Nested Vocab: Clean thin outline pen, zero background fill to prevent double-brush mud
            final pen = sf.PdfPen(highlightColor, width: 1.2);
            page.graphics.drawRectangle(
              pen: pen,
              bounds: Rect.fromLTWH(x, y, w, h),
            );
          } else {
            // Collocation or Standalone Vocab: Soft pastel solid brush
            page.graphics.save();
            page.graphics.setTransparency(0.25);
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
              textMarkupAnnotationType: sf.PdfTextMarkupAnnotationType.highlight,
            );
            page.annotations.add(annotation);
          }
        }
      }
    }

    final outputBytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(outputBytes);
  }

  static bool _isSpanContained(PdfDgnlHighlightSpan inner, PdfDgnlHighlightSpan outer) {
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

  /// Áp highlight thẳng lên tài liệu PDF hiện tại mà KHÔNG bật hộp thoại lưu file (Zero-dialog in-place)
  static Future<bool> applyHighlightDirectlyToPdf(
    BuildContext context,
    StudioState studio, {
    bool showFeedback = true,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (studio.pdfDgnlPassages.isEmpty) {
      if (showFeedback) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Chưa có đoạn văn nào được quét để highlight lên file.'),
            backgroundColor: Color(0xf0201815),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    try {
      // 1. Ghi vĩnh viễn các điểm highlight vào canvas nét vẽ (BoardStroke) của PDF trong StudioState
      // Giúp highlight tồn tại vĩnh viễn trên màn hình ngay cả khi tắt extension hay đóng thẻ card
      for (final passage in studio.pdfDgnlPassages) {
        final targetList = studio.pdfAnnotations.putIfAbsent(passage.pageNumber, () => []);
        for (final span in passage.spans) {
          final isGrammar = span.category == 'grammar';
          final isNestedVocab = span.category == 'vocabulary' &&
              passage.spans.any((other) => other.category == 'collocation' && _isSpanContained(span, other));

          Color strokeColor;
          if (isGrammar) {
            strokeColor = const Color(0xff89b4fa);
          } else if (span.category == 'collocation') {
            strokeColor = const Color(0xff86efac);
          } else if (span.level == 'C1' || span.level == 'C2') {
            strokeColor = const Color(0xffcba6f7);
          } else {
            strokeColor = const Color(0xfff9e2af);
          }

          final isHollow = isGrammar || isNestedVocab;
          final strokeWidth = isGrammar ? 1.5 : (isNestedVocab ? 1.2 : 20.0);

          for (final normR in span.normalizedRects) {
            final exists = targetList.any((s) => s.rect == normR);
            if (!exists) {
              targetList.add(BoardStroke(
                strokeColor,
                strokeWidth,
                [Offset(normR.left, normR.top), Offset(normR.right, normR.bottom)],
                rect: normR,
                isHollow: isHollow,
              ));
            }
          }
        }
      }

      final bytes = await exportHighlightedPdfBytes(studio);
      if (bytes != null) {
        // 2. Nếu có tệp trên ổ đĩa, ghi đè trực tiếp (in-place) không hỏi gì cả
        if (studio.pdfFilePath != null && studio.pdfFilePath!.isNotEmpty) {
          try {
            final file = File(studio.pdfFilePath!);
            if (await file.exists()) {
              await file.writeAsBytes(bytes);
            }
          } catch (e) {
            debugPrint('[PdfAnnotationExporter] In-place write error: $e');
          }
        }

        // 3. Cập nhật thẳng vào studio.pdfBytes mà không bị reset trang 1
        studio.updatePdfBytesInPlace(bytes);
      }

      studio.dirty = true;
      studio.bumpRevision();

      final totalSpans = studio.pdfDgnlPassages.fold<int>(
        0,
        (sum, p) => sum + p.spans.length,
      );

      if (showFeedback) {
        messenger?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xff86efac), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã áp dụng vĩnh viễn $totalSpans điểm highlight lên tài liệu (vẫn giữ nguyên khi tắt extension)!',
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
      return true;
    } catch (e) {
      debugPrint('[PdfAnnotationExporter] applyHighlightDirectlyToPdf error: $e');
      if (showFeedback) {
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

    if (studio.pdfDgnlPassages.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Chưa có đoạn văn nào được highlight để lưu vào file PDF.'),
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

      final outFile = File(finalPath);
      if (!await outFile.exists() || await outFile.length() == 0) {
        await outFile.writeAsBytes(bytes);
      }

      // Cập nhật lại studio để stage tự động load tệp PDF mới đã ghi vĩnh viễn
      studio.setPdfFile(finalPath, bytes);

      final totalSpans = studio.pdfDgnlPassages.fold<int>(
        0,
        (sum, p) => sum + p.spans.length,
      );

      final displayFile = finalPath.replaceAll(r'\', '/').split('/').last;

      messenger?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xff86efac), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã ghi vĩnh viễn $totalSpans điểm Highlight chuẩn ISO vào: $displayFile (Mở được trên Adobe, Foxit, Chrome)!',
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
      debugPrint('[PdfAnnotationExporter] Error saving highlighted PDF: $e');
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu PDF: $e'),
          backgroundColor: const Color(0xf03b1111),
        ),
      );
      return null;
    }
  }
}
