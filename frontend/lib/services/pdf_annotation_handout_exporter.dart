part of 'pdf_annotation_exporter.dart';

Future<sf.PdfFont> _loadHandoutFontImpl(
  double size, {
  bool bold = false,
}) async {
  try {
    final byteData = await rootBundle.load('assets/fonts/Manrope.ttf');
    final bytes = byteData.buffer.asUint8List();
    return sf.PdfTrueTypeFont(bytes, size);
  } catch (_) {
    try {
      final file = File('assets/fonts/Manrope.ttf');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return sf.PdfTrueTypeFont(bytes, size);
      }
    } catch (_) {}
  }
  return sf.PdfStandardFont(
    sf.PdfFontFamily.helvetica,
    size,
    style: bold ? sf.PdfFontStyle.bold : sf.PdfFontStyle.regular,
  );
}

Future<Uint8List> _generateHandoutPdfBytesImpl(StudioState studio) async {
  final doc = sf.PdfDocument();
  doc.pageSettings.orientation = sf.PdfPageOrientation.portrait;
  doc.pageSettings.size = const Size(595, 842); // Khổ A4 đứng

  final fontTitle = await _loadHandoutFontImpl(13, bold: true);
  final fontSub = await _loadHandoutFontImpl(9.5);
  final fontSlideTitle = await _loadHandoutFontImpl(10.5, bold: true);
  final fontBadge = await _loadHandoutFontImpl(9, bold: true);
  final fontNotes = await _loadHandoutFontImpl(10);
  final fontFooter = await _loadHandoutFontImpl(8.5);

  final totalPages = studio.pages.isEmpty ? 1 : studio.pages.length;

  for (int i = 0; i < totalPages; i++) {
    final page = doc.pages.add();
    final g = page.graphics;

    // 1. Header văn bản
    final lessonTitle = studio.title.trim().isEmpty
        ? 'Bài giảng Studio'
        : studio.title.trim();
    g.drawString(
      lessonTitle,
      fontTitle,
      brush: sf.PdfSolidBrush(sf.PdfColor(15, 23, 42)),
      bounds: const Rect.fromLTWH(36, 32, 380, 20),
    );

    final subjectText =
        'Môn: ${studio.subject.trim().isEmpty ? 'Chung' : studio.subject.trim()} · Tài liệu học tập';
    g.drawString(
      subjectText,
      fontSub,
      brush: sf.PdfSolidBrush(sf.PdfColor(100, 116, 139)),
      bounds: const Rect.fromLTWH(36, 48, 380, 16),
    );

    g.drawString(
      'Học Lực - Teacher Station',
      fontSub,
      brush: sf.PdfSolidBrush(sf.PdfColor(14, 165, 233)),
      bounds: const Rect.fromLTWH(420, 36, 139, 16),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
    );

    // Đường kẻ phân cách Header
    g.drawLine(
      sf.PdfPen(sf.PdfColor(226, 232, 240), width: 1),
      const Offset(36, 68),
      const Offset(559, 68),
    );

    // 2. Tiêu đề slide
    final pageTitle = i < studio.pageTitles.length
        ? studio.pageTitles[i]
        : 'Trang ${i + 1}';
    g.drawString(
      'SLIDE ${i + 1}/$totalPages: $pageTitle',
      fontSlideTitle,
      brush: sf.PdfSolidBrush(sf.PdfColor(30, 41, 59)),
      bounds: const Rect.fromLTWH(36, 78, 523, 18),
    );

    // 3. Khung Slide (16:9 ratio, chalkboard style)
    const slideBox = Rect.fromLTWH(36, 98, 523, 294.2);
    g.drawRectangle(
      brush: sf.PdfSolidBrush(sf.PdfColor(27, 43, 37)),
      pen: sf.PdfPen(sf.PdfColor(45, 74, 62), width: 1.2),
      bounds: slideBox,
    );

    // Vẽ các nét vẽ trên slide
    if (i < studio.pages.length) {
      final strokes = studio.pages[i];
      for (final s in strokes) {
        if (s.points.isEmpty && s.rect == null) continue;
        final rVal = (s.color.r * 255.0).round().clamp(0, 255);
        final gVal = (s.color.g * 255.0).round().clamp(0, 255);
        final bVal = (s.color.b * 255.0).round().clamp(0, 255);
        final pen = sf.PdfPen(
          sf.PdfColor(rVal, gVal, bVal),
          width: (s.width * (slideBox.width / 960.0)).clamp(1.0, 8.0),
        );

        if (s.rect != null) {
          final r = Rect.fromLTWH(
            slideBox.left + s.rect!.left * slideBox.width,
            slideBox.top + s.rect!.top * slideBox.height,
            s.rect!.width * slideBox.width,
            s.rect!.height * slideBox.height,
          );
          if (s.isHollow) {
            g.drawRectangle(pen: pen, bounds: r);
          } else {
            g.drawRectangle(
              brush: sf.PdfSolidBrush(sf.PdfColor(rVal, gVal, bVal)),
              bounds: r,
            );
          }
        } else if (s.points.length == 1) {
          final pt = Offset(
            slideBox.left + s.points[0].dx * slideBox.width,
            slideBox.top + s.points[0].dy * slideBox.height,
          );
          g.drawRectangle(
            brush: sf.PdfSolidBrush(sf.PdfColor(rVal, gVal, bVal)),
            bounds: Rect.fromLTWH(pt.dx - 2, pt.dy - 2, 4, 4),
          );
        } else {
          for (int j = 0; j < s.points.length - 1; j++) {
            final p1 = Offset(
              slideBox.left + s.points[j].dx * slideBox.width,
              slideBox.top + s.points[j].dy * slideBox.height,
            );
            final p2 = Offset(
              slideBox.left + s.points[j + 1].dx * slideBox.width,
              slideBox.top + s.points[j + 1].dy * slideBox.height,
            );
            g.drawLine(pen, p1, p2);
          }
        }
      }
    }

    // 4. Khung Ghi chú bài giảng (Lecture Notes)
    const noteBadgeRect = Rect.fromLTWH(36, 406, 210, 20);
    g.drawRectangle(
      brush: sf.PdfSolidBrush(sf.PdfColor(239, 246, 255)),
      pen: sf.PdfPen(sf.PdfColor(191, 219, 254), width: 1),
      bounds: noteBadgeRect,
    );
    g.drawString(
      'GHI CHÚ & HƯỚNG DẪN BÀI HỌC',
      fontBadge,
      brush: sf.PdfSolidBrush(sf.PdfColor(29, 78, 216)),
      bounds: const Rect.fromLTWH(44, 410, 195, 14),
    );

    const notesBox = Rect.fromLTWH(36, 432, 523, 360);
    g.drawRectangle(
      brush: sf.PdfSolidBrush(sf.PdfColor(248, 250, 252)),
      pen: sf.PdfPen(sf.PdfColor(226, 232, 240), width: 1),
      bounds: notesBox,
    );

    final note = (i < studio.pageNotes.length)
        ? studio.pageNotes[i].trim()
        : '';
    if (note.isNotEmpty) {
      g.drawString(
        note,
        fontNotes,
        brush: sf.PdfSolidBrush(sf.PdfColor(30, 41, 59)),
        bounds: Rect.fromLTWH(
          notesBox.left + 14,
          notesBox.top + 12,
          notesBox.width - 28,
          notesBox.height - 24,
        ),
        format: sf.PdfStringFormat(
          alignment: sf.PdfTextAlignment.left,
          lineAlignment: sf.PdfVerticalAlignment.top,
          wordWrap: sf.PdfWordWrapType.word,
        ),
      );
    } else {
      g.drawString(
        '(Không có ghi chú riêng của giáo viên · Dành cho học sinh ghi chú khi học)',
        fontSub,
        brush: sf.PdfSolidBrush(sf.PdfColor(148, 163, 184)),
        bounds: Rect.fromLTWH(
          notesBox.left + 14,
          notesBox.top + 12,
          notesBox.width - 28,
          18,
        ),
      );
      for (
        double lineY = notesBox.top + 50;
        lineY < notesBox.bottom - 20;
        lineY += 32
      ) {
        g.drawLine(
          sf.PdfPen(sf.PdfColor(226, 232, 240), width: 0.8),
          Offset(notesBox.left + 14, lineY),
          Offset(notesBox.right - 14, lineY),
        );
      }
    }

    // 5. Footer trang
    g.drawLine(
      sf.PdfPen(sf.PdfColor(226, 232, 240), width: 1),
      const Offset(36, 804),
      const Offset(559, 804),
    );
    g.drawString(
      'Tài liệu học tập Học Lực · Lưu hành nội bộ lớp học',
      fontFooter,
      brush: sf.PdfSolidBrush(sf.PdfColor(148, 163, 184)),
      bounds: const Rect.fromLTWH(36, 810, 300, 14),
    );
    g.drawString(
      'Trang ${i + 1} / $totalPages',
      fontFooter,
      brush: sf.PdfSolidBrush(sf.PdfColor(148, 163, 184)),
      bounds: const Rect.fromLTWH(420, 810, 139, 14),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.right),
    );
  }

  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

Future<String?> _exportHandoutWithNotesToPdfImpl(
  BuildContext context,
  StudioState studio,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final bytes = await _generateHandoutPdfBytesImpl(studio);

    final cleanTitle = studio.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final suggestedName = '${cleanTitle}_Handout_GhiChu.pdf';

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Lưu tài liệu bài học (Slide kèm Ghi chú)',
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
                'Đã xuất tài liệu Handout (${studio.pages.length} trang) kèm ghi chú: $displayFile',
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
      '[PdfAnnotationExporter] exportHandoutWithNotesToPdf error: $e',
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Lỗi khi xuất tài liệu Handout: $e'),
        backgroundColor: const Color(0xf03b1111),
      ),
    );
    return null;
  }
}

Future<String?> _saveLecturePdfImpl(
  BuildContext context,
  StudioState studio,
) async {
  // 1. Nếu có tài liệu PDF đang mở trong phòng học
  if (studio.pdfBytes != null || studio.pdfFilePath != null) {
    if (studio.pdfDgnlPassages.isNotEmpty) {
      return PdfAnnotationExporter.saveHighlightedPdf(context, studio);
    }

    Uint8List? sourceBytes = studio.pdfBytes;
    if (sourceBytes == null && studio.pdfFilePath != null) {
      final file = File(studio.pdfFilePath!);
      if (await file.exists()) {
        sourceBytes = await file.readAsBytes();
      }
    }

    if (sourceBytes != null && sourceBytes.isNotEmpty) {
      String suggestedName = 'tai_lieu_bai_giang.pdf';
      if (studio.pdfFilePath != null && studio.pdfFilePath!.isNotEmpty) {
        final raw = studio.pdfFilePath!.replaceAll(r'\', '/').split('/').last;
        suggestedName = raw;
      }

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Lưu tệp tài liệu PDF bài học',
        fileName: suggestedName,
        bytes: sourceBytes,
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
        await outFile.writeAsBytes(sourceBytes);
      }

      final displayFile = finalPath.replaceAll(r'\', '/').split('/').last;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu tệp PDF: $displayFile'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
      return finalPath;
    }
  }

  // 2. Nếu không có file PDF tài liệu nào mở, xuất các slide bảng viết ra tệp PDF
  if (!context.mounted) return null;
  return PdfAnnotationExporter.exportChalkboardSlidesToPdf(context, studio);
}

