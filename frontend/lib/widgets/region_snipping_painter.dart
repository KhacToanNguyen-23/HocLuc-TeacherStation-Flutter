part of 'region_snipping_overlay.dart';

extension _RegionSnippingFallbackExt on _RegionSnippingOverlayState {
  /// Trích xuất dự phòng trực tiếp từ tài liệu PDF (khi chưa khởi tạo controller hoặc sau Hot Reload)
  Future<_PdfSnippetResult?> _extractFromPdfFallback(
    StudioState studio,
    Rect screenRect,
    Size stageSize,
  ) async {
    try {
      PdfDocument? doc;
      if (studio.pdfBytes != null) {
        doc = await PdfDocument.openData(studio.pdfBytes!);
      } else if (studio.pdfFilePath != null) {
        doc = await PdfDocument.openFile(studio.pdfFilePath!);
      }
      if (doc == null || doc.pages.isEmpty) return null;

      final normLeft = (screenRect.left / stageSize.width).clamp(0.0, 1.0);
      final normRight = (screenRect.right / stageSize.width).clamp(0.0, 1.0);
      final normTop = (screenRect.top / stageSize.height).clamp(0.0, 1.0);
      final normBottom = (screenRect.bottom / stageSize.height).clamp(0.0, 1.0);
      final normRect = Rect.fromLTRB(normLeft, normTop, normRight, normBottom);

      // Check pages around current page, then other pages
      final targetIdx = (studio.pdfPage - 1).clamp(0, doc.pages.length - 1);
      final pagesToCheck = <int>[
        targetIdx,
        for (int i = 0; i < doc.pages.length; i++)
          if (i != targetIdx) i,
      ];

      for (final pIdx in pagesToCheck) {
        final page = doc.pages[pIdx];
        final rawText = await page.loadText();
        if (rawText != null && rawText.fullText.isNotEmpty) {
          final boxes = <_PdfCharBox>[];
          final charIndices = <int>{};

          for (
            int c = 0;
            c < rawText.charRects.length && c < rawText.fullText.length;
            c++
          ) {
            final r = rawText.charRects[c];
            final rFlutter = r.toRect(page: page);
            final cNormLeft = (rFlutter.left / page.width).clamp(0.0, 1.0);
            final cNormRight = (rFlutter.right / page.width).clamp(0.0, 1.0);
            final cNormTop = (rFlutter.top / page.height).clamp(0.0, 1.0);
            final cNormBottom = (rFlutter.bottom / page.height).clamp(0.0, 1.0);

            final cRect = Rect.fromLTRB(
              cNormLeft,
              math.min(cNormTop, cNormBottom),
              cNormRight,
              math.max(cNormTop, cNormBottom),
            );

            final hitRect = cRect.width < 0.002
                ? Rect.fromCenter(
                    center: cRect.center,
                    width: 0.006,
                    height: math.max(0.012, cRect.height),
                  )
                : cRect;

            if (hitRect.overlaps(normRect) || normRect.contains(cRect.center)) {
              charIndices.add(c);
              boxes.add(
                _PdfCharBox(
                  char: rawText.fullText[c],
                  index: c,
                  normalizedRect: cRect,
                ),
              );
            }
          }

          if (boxes.isNotEmpty) {
            final minIdx = boxes.first.index;
            final maxIdx = boxes.last.index;
            for (int i = minIdx; i <= maxIdx; i++) {
              if (!charIndices.contains(i)) {
                final ch = rawText.fullText[i];
                if (ch == ' ' || ch == '\t' || ch == '\n') {
                  final r = rawText.charRects[i];
                  final rFlutter = r.toRect(page: page);
                  final cRect = Rect.fromLTRB(
                    (rFlutter.left / page.width).clamp(0.0, 1.0),
                    (rFlutter.top / page.height).clamp(0.0, 1.0),
                    (rFlutter.right / page.width).clamp(0.0, 1.0),
                    (rFlutter.bottom / page.height).clamp(0.0, 1.0),
                  );
                  boxes.add(
                    _PdfCharBox(char: ch, index: i, normalizedRect: cRect),
                  );
                }
              }
            }
            boxes.sort((a, b) => a.index.compareTo(b.index));
          }

          String snippetText = '';
          if (boxes.isNotEmpty) {
            snippetText = boxes.map((b) => b.char).join('');
          }

          if (snippetText.trim().length >= 10) {
            return _PdfSnippetResult(
              pageNumber: page.pageNumber,
              text: snippetText,
              normalizedBounds: normRect,
              charBoxes: boxes,
            );
          }
        }
      }
    } catch (e) {
      FrontendLogger.write(
        '[RegionSnippingOverlay] Fallback extraction error: $e',
      );
    }
    return null;
  }

  /// Gom các box ký tự trên cùng dòng thành một hình chữ nhật highlight duy nhất
  List<Rect> _groupCharBoxesIntoLines(List<Rect> boxes) {
    if (boxes.isEmpty) return const [];
    final lines = <List<Rect>>[];

    for (final b in boxes) {
      bool added = false;
      for (final line in lines) {
        final ref = line.first;
        // Group if vertical overlap exists or top distance is within tolerance
        if ((ref.top - b.top).abs() < 0.015 ||
            (b.top <= ref.bottom && b.bottom >= ref.top)) {
          line.add(b);
          added = true;
          break;
        }
      }
      if (!added) {
        lines.add([b]);
      }
    }

    final merged = <Rect>[];
    for (final line in lines) {
      double minX = line.first.left;
      double maxX = line.first.right;
      double minY = line.first.top;
      double maxY = line.first.bottom;

      for (final r in line) {
        minX = math.min(minX, r.left);
        maxX = math.max(maxX, r.right);
        minY = math.min(minY, r.top);
        maxY = math.max(maxY, r.bottom);
      }

      merged.add(
        Rect.fromLTRB(
          minX,
          (minY - 0.001).clamp(0.0, 1.0),
          maxX,
          (maxY + 0.001).clamp(0.0, 1.0),
        ),
      );
    }
    return merged;
  }
}

class _SnippingPainter extends CustomPainter {
  const _SnippingPainter({this.start, this.current});

  final Offset? start;
  final Offset? current;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0x66000000);

    if (start == null || current == null) {
      canvas.drawRect(Offset.zero & size, bgPaint);
      return;
    }

    final selRect = Rect.fromPoints(start!, current!);

    // Cutout hole for clear selection
    final bgPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(selRect, const Radius.circular(4)));
    final cutoutPath = Path.combine(PathOperation.difference, bgPath, holePath);
    canvas.drawPath(cutoutPath, bgPaint);

    // Glowing border for selection
    final borderPaint = Paint()
      ..color = const Color(0xff89b4fa)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(selRect, const Radius.circular(4)),
      borderPaint,
    );

    // Corner guides
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const cornerLen = 10.0;
    // Top-left
    canvas.drawLine(
      selRect.topLeft,
      selRect.topLeft + const Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      selRect.topLeft,
      selRect.topLeft + const Offset(0, cornerLen),
      cornerPaint,
    );
    // Top-right
    canvas.drawLine(
      selRect.topRight,
      selRect.topRight + const Offset(-cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      selRect.topRight,
      selRect.topRight + const Offset(0, cornerLen),
      cornerPaint,
    );
    // Bottom-left
    canvas.drawLine(
      selRect.bottomLeft,
      selRect.bottomLeft + const Offset(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      selRect.bottomLeft,
      selRect.bottomLeft + const Offset(0, -cornerLen),
      cornerPaint,
    );
    // Bottom-right
    canvas.drawLine(
      selRect.bottomRight,
      selRect.bottomRight + const Offset(-cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      selRect.bottomRight,
      selRect.bottomRight + const Offset(0, -cornerLen),
      cornerPaint,
    );

    // Dimensions badge
    final textSpan = TextSpan(
      text: '${selRect.width.round()} × ${selRect.height.round()}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    final badgeRect = Rect.fromLTWH(
      selRect.left,
      selRect.bottom + 6,
      tp.width + 12,
      tp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
      Paint()..color = const Color(0xd0111a15),
    );
    tp.paint(canvas, Offset(badgeRect.left + 6, badgeRect.top + 2));
  }

  @override
  bool shouldRepaint(covariant _SnippingPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.current != current;
  }
}

