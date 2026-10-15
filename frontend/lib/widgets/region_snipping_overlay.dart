import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/studio_state.dart';
import '../services/dgnl_service.dart';

class _PdfCharBox {
  final String char;
  final int index;
  final Rect normalizedRect;

  _PdfCharBox({
    required this.char,
    required this.index,
    required this.normalizedRect,
  });
}

class _PdfSnippetResult {
  final int pageNumber;
  final String text;
  final Rect normalizedBounds;
  final List<_PdfCharBox> charBoxes;

  _PdfSnippetResult({
    required this.pageNumber,
    required this.text,
    required this.normalizedBounds,
    required this.charBoxes,
  });
}

class RegionSnippingOverlay extends StatefulWidget {
  const RegionSnippingOverlay({super.key, required this.studio});

  final StudioState studio;

  @override
  State<RegionSnippingOverlay> createState() => _RegionSnippingOverlayState();
}

class _RegionSnippingOverlayState extends State<RegionSnippingOverlay> {
  Offset? _startPoint;
  Offset? _currentPoint;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final studio = widget.studio;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          studio.stopSnipping();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            if (_isProcessing) return;
            setState(() {
              _startPoint = details.localPosition;
              _currentPoint = details.localPosition;
            });
          },
          onPanUpdate: (details) {
            if (_isProcessing || _startPoint == null) return;
            setState(() {
              _currentPoint = details.localPosition;
            });
          },
          onPanEnd: (details) async {
            if (_isProcessing ||
                _startPoint == null ||
                _currentPoint == null) {
              return;
            }

            final selRect = Rect.fromPoints(_startPoint!, _currentPoint!);
            if (selRect.width < 10 || selRect.height < 10) {
              setState(() {
                _startPoint = null;
                _currentPoint = null;
              });
              return;
            }

            setState(() => _isProcessing = true);
            await _processSelection(context, selRect);
          },
          child: Stack(
            children: [
              // Shaded screen with cutout & glowing selection box
              Positioned.fill(
                child: CustomPaint(
                  painter: _SnippingPainter(
                    start: _startPoint,
                    current: _currentPoint,
                  ),
                ),
              ),

              // Top Instruction Banner
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xf0111a15),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xff89b4fa),
                        width: 1.4,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x88000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.crop_free,
                          size: 16,
                          color: Color(0xff89b4fa),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isProcessing
                              ? 'Đang trích xuất & bóc tách highlight trực tiếp trên đề...'
                              : 'Kéo chuột để khoanh vùng đoạn văn bản trên đề • Nhấn ESC hoặc nút Đóng để hủy',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () => studio.stopSnipping(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0x28ffffff),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 13,
                              color: Color(0xffa5b5a8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processSelection(BuildContext context, Rect screenRect) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final studio = widget.studio;
    final size = MediaQuery.of(context).size;

    // 1. Try accurate extraction using active PdfViewerController
    _PdfSnippetResult? pdfResult = await _extractFromActivePdfViewer(context, studio, screenRect);

    // 2. Fallback to direct page extraction from PDF bytes/file if controller was not ready
    if (pdfResult == null && (studio.pdfBytes != null || studio.pdfFilePath != null)) {
      pdfResult = await _extractFromPdfFallback(studio, screenRect, size);
    }

    if (pdfResult != null && pdfResult.text.trim().isNotEmpty) {
      final cleanText = pdfResult.text.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Perform DGNL analysis and Cloze generation first while overlay is active
      final analysis = await DgnlService.analyze(cleanText);
      final clozeQuestions = await DgnlService.generateCloze(cleanText);

      // Map highlight spans to line-level bounding boxes on the PDF page
      final spans = <PdfDgnlHighlightSpan>[];
      final snippetChars = pdfResult.charBoxes;
      final rawCharsText = snippetChars.map((b) => b.char).join('');
      final rawCharsLower = rawCharsText.toLowerCase();

      for (final hl in analysis.highlights) {
        final hlText = hl['text']?.toString().trim() ?? '';
        final category = hl['category']?.toString() ?? 'grammar';
        final level = hl['level']?.toString() ?? 'B2';
        final type = hl['type']?.toString() ?? category.toUpperCase();
        final note = hl['note']?.toString() ?? '';

        if (hlText.isEmpty) continue;

        // 1. Try flexible regex matching across rawCharsText
        final escaped = RegExp.escape(hlText)
            .replaceAll(RegExp(r'\\\s+'), r'\s+')
            .replaceAll(RegExp(r'[-–—]'), r'[-–—\s\u25A1]?');
        final matchReg = RegExp(escaped, caseSensitive: false);
        final matches = matchReg.allMatches(rawCharsText).toList();

        if (matches.isNotEmpty) {
          for (final m in matches) {
            final matchedBoxes = <Rect>[];
            for (int ci = m.start; ci < m.end && ci < snippetChars.length; ci++) {
              matchedBoxes.add(snippetChars[ci].normalizedRect);
            }
            if (matchedBoxes.isNotEmpty) {
              final lineRects = _groupCharBoxesIntoLines(matchedBoxes);
              spans.add(PdfDgnlHighlightSpan(
                text: hlText,
                category: category,
                level: level,
                type: type,
                note: note,
                normalizedRects: lineRects,
              ));
            }
          }
        } else {
          // 2. Substring fallback matching
          final hlLower = hlText.toLowerCase();
          int sIdx = 0;
          while ((sIdx = rawCharsLower.indexOf(hlLower, sIdx)) != -1) {
            final eIdx = sIdx + hlLower.length;
            final matchedBoxes = <Rect>[];
            for (int ci = sIdx; ci < eIdx && ci < snippetChars.length; ci++) {
              matchedBoxes.add(snippetChars[ci].normalizedRect);
            }
            if (matchedBoxes.isNotEmpty) {
              final lineRects = _groupCharBoxesIntoLines(matchedBoxes);
              spans.add(PdfDgnlHighlightSpan(
                text: hlText,
                category: category,
                level: level,
                type: type,
                note: note,
                normalizedRects: lineRects,
              ));
            }
            sIdx = eIdx;
          }
        }
      }

      // 3. Fallback: If snippet character matching had gaps or missed spans, search page fullText
      if (spans.isEmpty && studio.pdfViewerController != null) {
        try {
          final ctrl = studio.pdfViewerController;
          if (ctrl.isReady && pdfResult.pageNumber <= ctrl.pages.length) {
            final page = ctrl.pages[pdfResult.pageNumber - 1];
            final rawPageText = await page.loadText();
            if (rawPageText != null && rawPageText.fullText.isNotEmpty) {
              final pageFull = rawPageText.fullText;
              final pageFullLower = pageFull.toLowerCase();
              for (final hl in analysis.highlights) {
                final hlText = hl['text']?.toString().trim() ?? '';
                if (hlText.isEmpty) continue;
                final category = hl['category']?.toString() ?? 'grammar';
                final level = hl['level']?.toString() ?? 'B2';
                final type = hl['type']?.toString() ?? category.toUpperCase();
                final note = hl['note']?.toString() ?? '';

                int findIdx = 0;
                final hlLower = hlText.toLowerCase();
                while ((findIdx = pageFullLower.indexOf(hlLower, findIdx)) != -1) {
                  final endIdx = findIdx + hlLower.length;
                  final matchedBoxes = <Rect>[];
                  for (int ci = findIdx; ci < endIdx && ci < rawPageText.charRects.length; ci++) {
                    final r = rawPageText.charRects[ci];
                    final rFlutter = r.toRect(page: page);
                    final cRect = Rect.fromLTRB(
                      (rFlutter.left / page.width).clamp(0.0, 1.0),
                      (rFlutter.top / page.height).clamp(0.0, 1.0),
                      (rFlutter.right / page.width).clamp(0.0, 1.0),
                      (rFlutter.bottom / page.height).clamp(0.0, 1.0),
                    );
                    matchedBoxes.add(cRect);
                  }
                  if (matchedBoxes.isNotEmpty) {
                    final lineRects = _groupCharBoxesIntoLines(matchedBoxes);
                    spans.add(PdfDgnlHighlightSpan(
                      text: hlText,
                      category: category,
                      level: level,
                      type: type,
                      note: note,
                      normalizedRects: lineRects,
                    ));
                  }
                  findIdx = endIdx;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[RegionSnippingOverlay] Page fallback span search error: $e');
        }
      }

      // Add direct in-document passage highlight to the PDF page
      final passage = PdfDgnlPassage(
        id: 'dgnl-${DateTime.now().millisecondsSinceEpoch}',
        pageNumber: pdfResult.pageNumber,
        rawText: cleanText,
        normalizedBounds: pdfResult.normalizedBounds,
        spans: spans,
        metrics: {
          'total_words': analysis.totalWords,
          'content_words': analysis.contentWords,
          'lexical_density': analysis.lexicalDensity,
          'cefr_profile': analysis.cefrProfile,
          'evaluation': analysis.evaluation,
          'status': analysis.status,
        },
        clozeQuestions: clozeQuestions,
      );

      // 1. First add passage to PDF stage so in-document highlight appears immediately
      studio.addPdfDgnlPassage(passage);

      // 2. Synchronize to English assistant plugin and cleanly close snipping
      studio.sendSnippetToPlugin(cleanText);
      studio.stopSnipping();

      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xff86efac), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã highlight trực tiếp trên đề (Trang ${pdfResult.pageNumber}): ${spans.length} điểm Ngữ pháp, Collocations & CEFR B2/C1!',
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
      return;
    }


    // 3. Fallback to Chalkboard handwriting annotations if applicable
    String extracted = '';
    final annotations = studio.currentChalkAnnotations;
    final matchedTexts = <String>[];
    for (final a in annotations) {
      final aScreenRect = Rect.fromLTWH(
        a.normalizedBounds.left * size.width,
        a.normalizedBounds.top * size.height,
        a.normalizedBounds.width * size.width,
        a.normalizedBounds.height * size.height,
      );
      if (screenRect.overlaps(aScreenRect)) {
        matchedTexts.add(a.rawText);
      }
    }
    if (matchedTexts.isNotEmpty) {
      extracted = matchedTexts.join(' ');
    }

    if (!mounted) return;

    if (extracted.trim().isNotEmpty) {
      final cleanText = extracted.trim();
      studio.sendSnippetToPlugin(cleanText);
      studio.stopSnipping();

      messenger?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xff86efac), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã quét thành công ${cleanText.split(RegExp(r'\s+')).length} từ!',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xf0111a15),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      studio.stopSnipping();
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy văn bản trong vùng khoanh. Vui lòng kéo chọn lại!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Trích xuất chính xác theo ma trận tọa độ hiển thị thực tế của PdfViewer
  Future<_PdfSnippetResult?> _extractFromActivePdfViewer(
    BuildContext context,
    StudioState studio,
    Rect screenRect,
  ) async {
    try {
      final controller = studio.pdfViewerController as PdfViewerController?;
      final viewerKey = studio.pdfViewerKey;

      if (controller != null && controller.isReady) {
        final overlayBox = context.findRenderObject() as RenderBox?;
        if (overlayBox == null) return null;

        final globalTopLeft = overlayBox.localToGlobal(screenRect.topLeft);
        final globalBottomRight = overlayBox.localToGlobal(screenRect.bottomRight);

        // Convert global screen coordinate to PDF document layout space
        Offset? docTopLeft = controller.globalToDocument(globalTopLeft);
        Offset? docBottomRight = controller.globalToDocument(globalBottomRight);

        if (docTopLeft == null || docBottomRight == null) {
          final viewerBox = viewerKey?.currentContext?.findRenderObject() as RenderBox?;
          if (viewerBox != null) {
            final vLocalTL = viewerBox.globalToLocal(globalTopLeft);
            final vLocalBR = viewerBox.globalToLocal(globalBottomRight);
            docTopLeft ??= controller.localToDocument(vLocalTL);
            docBottomRight ??= controller.localToDocument(vLocalBR);
          }
        }

        if (docTopLeft == null || docBottomRight == null) return null;

        final minX = math.min(docTopLeft.dx, docBottomRight.dx);
        final maxX = math.max(docTopLeft.dx, docBottomRight.dx);
        final minY = math.min(docTopLeft.dy, docBottomRight.dy);
        final maxY = math.max(docTopLeft.dy, docBottomRight.dy);
        final docRect = Rect.fromLTRB(minX, minY, maxX, maxY);

        final pageLayouts = controller.layout.pageLayouts;
        if (pageLayouts.isEmpty || controller.pages.isEmpty) return null;

        // Find the page with the highest overlap area with docRect
        int? bestPageIdx;
        double maxOverlapArea = 0.0;
        for (int i = 0; i < pageLayouts.length && i < controller.pages.length; i++) {
          final pLayout = pageLayouts[i];
          if (docRect.overlaps(pLayout)) {
            final interL = math.max(docRect.left, pLayout.left);
            final interR = math.min(docRect.right, pLayout.right);
            final interT = math.max(docRect.top, pLayout.top);
            final interB = math.min(docRect.bottom, pLayout.bottom);
            final area = (interR - interL) * (interB - interT);
            if (area > maxOverlapArea) {
              maxOverlapArea = area;
              bestPageIdx = i;
            }
          }
        }

        // If selection is slightly outside/on border, pick page closest vertically
        if (bestPageIdx == null) {
          double minDist = double.infinity;
          for (int i = 0; i < pageLayouts.length && i < controller.pages.length; i++) {
            final pLayout = pageLayouts[i];
            final dist = (docRect.center.dy - pLayout.center.dy).abs();
            if (dist < minDist) {
              minDist = dist;
              bestPageIdx = i;
            }
          }
        }

        bestPageIdx ??= (studio.pdfPage - 1).clamp(0, controller.pages.length - 1);

        final pLayout = pageLayouts[bestPageIdx];
        final page = controller.pages[bestPageIdx];

        // Normalized rectangular boundary relative to this specific page
        final clampLeft = math.max(docRect.left, pLayout.left);
        final clampRight = math.min(docRect.right, pLayout.right);
        final clampTop = math.max(docRect.top, pLayout.top);
        final clampBottom = math.min(docRect.bottom, pLayout.bottom);

        final normLeft = ((clampLeft - pLayout.left) / pLayout.width).clamp(0.0, 1.0);
        final normTop = ((clampTop - pLayout.top) / pLayout.height).clamp(0.0, 1.0);
        final normRight = ((clampRight - pLayout.left) / pLayout.width).clamp(0.0, 1.0);
        final normBottom = ((clampBottom - pLayout.top) / pLayout.height).clamp(0.0, 1.0);
        final normRect = Rect.fromLTRB(normLeft, normTop, normRight, normBottom);

        final rawText = await page.loadText();
        if (rawText != null && rawText.fullText.isNotEmpty) {
          final boxes = <_PdfCharBox>[];
          final charIndices = <int>{};

          for (int c = 0; c < rawText.charRects.length && c < rawText.fullText.length; c++) {
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

            // Expand thin/zero-width space rects slightly for reliable hit-testing
            final hitRect = cRect.width < 0.002
                ? Rect.fromCenter(center: cRect.center, width: 0.006, height: math.max(0.012, cRect.height))
                : cRect;

            if (hitRect.overlaps(normRect) || normRect.contains(cRect.center)) {
              charIndices.add(c);
              boxes.add(_PdfCharBox(
                char: rawText.fullText[c],
                index: c,
                normalizedRect: cRect,
              ));
            }
          }

          // Ensure intervening whitespace characters are included so words don't conjoin
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
                  boxes.add(_PdfCharBox(char: ch, index: i, normalizedRect: cRect));
                }
              }
            }
            boxes.sort((a, b) => a.index.compareTo(b.index));
          }

          String snippetText = '';
          if (boxes.isNotEmpty) {
            snippetText = boxes.map((b) => b.char).join('');
          }

          // Fallback if character boxes missed lines
          if (snippetText.trim().length < 5) {
            final lines = rawText.fullText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
            if (lines.isNotEmpty) {
              final startLine = (normTop * lines.length).clamp(0, lines.length - 1).toInt();
              final endLine = (normBottom * lines.length).clamp(startLine, lines.length - 1).toInt();
              snippetText = lines.sublist(startLine, endLine + 1).join(' ');
            }
          }

          if (snippetText.trim().isNotEmpty) {
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
      debugPrint('[RegionSnippingOverlay] Accurate PDF extraction error: $e');
    }
    return null;
  }

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

          for (int c = 0; c < rawText.charRects.length && c < rawText.fullText.length; c++) {
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
                ? Rect.fromCenter(center: cRect.center, width: 0.006, height: math.max(0.012, cRect.height))
                : cRect;

            if (hitRect.overlaps(normRect) || normRect.contains(cRect.center)) {
              charIndices.add(c);
              boxes.add(_PdfCharBox(
                char: rawText.fullText[c],
                index: c,
                normalizedRect: cRect,
              ));
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
                  boxes.add(_PdfCharBox(char: ch, index: i, normalizedRect: cRect));
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
      debugPrint('[RegionSnippingOverlay] Fallback extraction error: $e');
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
        if ((ref.top - b.top).abs() < 0.015 || (b.top <= ref.bottom && b.bottom >= ref.top)) {
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

      merged.add(Rect.fromLTRB(
        minX,
        (minY - 0.001).clamp(0.0, 1.0),
        maxX,
        (maxY + 0.001).clamp(0.0, 1.0),
      ));
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
      ..addRRect(
        RRect.fromRectAndRadius(selRect, const Radius.circular(4)),
      );
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
    canvas.drawLine(selRect.topLeft, selRect.topLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(selRect.topLeft, selRect.topLeft + const Offset(0, cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(selRect.topRight, selRect.topRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(selRect.topRight, selRect.topRight + const Offset(0, cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(selRect.bottomLeft, selRect.bottomLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(selRect.bottomLeft, selRect.bottomLeft + const Offset(0, -cornerLen), cornerPaint);
    // Bottom-right
    canvas.drawLine(selRect.bottomRight, selRect.bottomRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(selRect.bottomRight, selRect.bottomRight + const Offset(0, -cornerLen), cornerPaint);

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
