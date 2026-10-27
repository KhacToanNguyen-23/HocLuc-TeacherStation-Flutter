import 'package:teaching_companion/core/utils/frontend_logger.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import '../services/dgnl_service.dart';

part 'region_snipping_painter.dart';

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
            if (_isProcessing || _startPoint == null || _currentPoint == null) {
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
                          blurRadius: 8,
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
    _PdfSnippetResult? pdfResult = await _extractFromActivePdfViewer(
      context,
      studio,
      screenRect,
    );

    // 2. Fallback to direct page extraction from PDF bytes/file if controller was not ready
    if (pdfResult == null &&
        (studio.pdfBytes != null || studio.pdfFilePath != null)) {
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

      void addSpanSafely(PdfDgnlHighlightSpan candidate) {
        // 1. Kiểm tra trùng lặp trong cùng phân loại (cùng category)
        for (int i = 0; i < spans.length; i++) {
          final s = spans[i];
          if (s.category == candidate.category) {
            for (final ra in s.normalizedRects) {
              for (final rb in candidate.normalizedRects) {
                final inter = ra.intersect(rb);
                if (inter.width > 0 && inter.height > 0) {
                  final interArea = inter.width * inter.height;
                  final minArea = math.min(ra.width * ra.height, rb.width * rb.height);
                  if (minArea > 0 && (interArea / minArea) >= 0.75) {
                    if (candidate.text.length > s.text.length) {
                      spans[i] = candidate;
                    }
                    return;
                  }
                }
              }
            }
          }
        }

        // 2. Nếu hai từ vựng (vocabulary) chồng lấn nhau trên cùng một vùng chữ:
        // Giữ lại từ cụ thể hơn / dài hơn (ví dụ 'bitterness' thay vì 'bitter')
        if (candidate.category == 'vocabulary') {
          for (int i = 0; i < spans.length; i++) {
            final s = spans[i];
            if (s.category == 'vocabulary') {
              for (final ra in s.normalizedRects) {
                for (final rb in candidate.normalizedRects) {
                  final inter = ra.intersect(rb);
                  if (inter.width > 0 && inter.height > 0) {
                    final interArea = inter.width * inter.height;
                    final minArea = math.min(ra.width * ra.height, rb.width * rb.height);
                    if (minArea > 0 && (interArea / minArea) >= 0.75) {
                      if (candidate.text.length > s.text.length) {
                        spans[i] = candidate;
                      }
                      return;
                    }
                  }
                }
              }
            }
          }
        }

        spans.add(candidate);
      }

      for (final hl in analysis.highlights) {
        final hlText = hl['text']?.toString().trim() ?? '';
        final category = hl['category']?.toString() ?? 'grammar';
        final level = hl['level']?.toString() ?? 'B2';
        final type = hl['type']?.toString() ?? category.toUpperCase();
        final note = hl['note']?.toString() ?? '';
        final isPedagogical = hl['isPedagogical'] as bool? ?? false;
        final isAcademic = hl['isAcademic'] as bool? ?? false;
        final isPreTeach = hl['isPreTeach'] as bool? ?? false;
        final isFunctionWord = hl['isFunctionWord'] as bool? ?? false;
        final isProperNoun = hl['isProperNoun'] as bool? ?? false;
        final isNumber = hl['isNumber'] as bool? ?? false;
        final lemma = hl['lemma'] as String?;

        if (hlText.isEmpty) continue;

        // 1. Try flexible regex matching across rawCharsText
        final escaped = RegExp.escape(hlText)
            .replaceAll(RegExp(r'\\\s+'), r'\s+')
            .replaceAll(RegExp(r'[-–—]'), r'[-–—\s\u25A1]?');
        final pattern = category == 'vocabulary'
            ? r'\b' + escaped + r'\b'
            : escaped;
        final matchReg = RegExp(pattern, caseSensitive: false);
        final matches = matchReg.allMatches(rawCharsText).toList();

        if (matches.isNotEmpty) {
          for (final m in matches) {
            final matchedBoxes = <Rect>[];
            for (
              int ci = m.start;
              ci < m.end && ci < snippetChars.length;
              ci++
            ) {
              matchedBoxes.add(snippetChars[ci].normalizedRect);
            }
            if (matchedBoxes.isNotEmpty) {
              final lineRects = _groupCharBoxesIntoLines(matchedBoxes);
              addSpanSafely(
                PdfDgnlHighlightSpan(
                  text: hlText,
                  category: category,
                  level: level,
                  type: type,
                  note: note,
                  normalizedRects: lineRects,
                  isPedagogical: isPedagogical,
                  isAcademic: isAcademic,
                  isPreTeach: isPreTeach,
                  isFunctionWord: isFunctionWord,
                  isProperNoun: isProperNoun,
                  isNumber: isNumber,
                  lemma: lemma,
                ),
              );
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
              addSpanSafely(
                PdfDgnlHighlightSpan(
                  text: hlText,
                  category: category,
                  level: level,
                  type: type,
                  note: note,
                  normalizedRects: lineRects,
                  isPedagogical: isPedagogical,
                  isAcademic: isAcademic,
                  isPreTeach: isPreTeach,
                  isFunctionWord: isFunctionWord,
                  isProperNoun: isProperNoun,
                  isNumber: isNumber,
                  lemma: lemma,
                ),
              );
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
                final isPedagogical = hl['isPedagogical'] as bool? ?? false;
                final isAcademic = hl['isAcademic'] as bool? ?? false;
                final isPreTeach = hl['isPreTeach'] as bool? ?? false;
                final isFunctionWord = hl['isFunctionWord'] as bool? ?? false;
                final isProperNoun = hl['isProperNoun'] as bool? ?? false;
                final isNumber = hl['isNumber'] as bool? ?? false;
                final lemma = hl['lemma'] as String?;

                int findIdx = 0;
                final hlLower = hlText.toLowerCase();
                while ((findIdx = pageFullLower.indexOf(hlLower, findIdx)) !=
                    -1) {
                  final endIdx = findIdx + hlLower.length;
                  final matchedBoxes = <Rect>[];
                  for (
                    int ci = findIdx;
                    ci < endIdx && ci < rawPageText.charRects.length;
                    ci++
                  ) {
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
                    spans.add(
                      PdfDgnlHighlightSpan(
                        text: hlText,
                        category: category,
                        level: level,
                        type: type,
                        note: note,
                        normalizedRects: lineRects,
                        isPedagogical: isPedagogical,
                        isAcademic: isAcademic,
                        isPreTeach: isPreTeach,
                        isFunctionWord: isFunctionWord,
                        isProperNoun: isProperNoun,
                        isNumber: isNumber,
                        lemma: lemma,
                      ),
                    );
                  }
                  findIdx = endIdx;
                }
              }
            }
          }
        } catch (e) {
          FrontendLogger.write(
            '[RegionSnippingOverlay] Page fallback span search error: $e',
          );
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
        textProfile: analysis.textProfile,
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
                const Icon(
                  Icons.check_circle,
                  color: Color(0xff86efac),
                  size: 18,
                ),
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
              const Icon(
                Icons.check_circle,
                color: Color(0xff86efac),
                size: 18,
              ),
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
          content: Text(
            'Không tìm thấy văn bản trong vùng khoanh. Vui lòng kéo chọn lại!',
          ),
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
        final globalBottomRight = overlayBox.localToGlobal(
          screenRect.bottomRight,
        );

        // Convert global screen coordinate to PDF document layout space
        Offset? docTopLeft = controller.globalToDocument(globalTopLeft);
        Offset? docBottomRight = controller.globalToDocument(globalBottomRight);

        if (docTopLeft == null || docBottomRight == null) {
          final viewerBox =
              viewerKey?.currentContext?.findRenderObject() as RenderBox?;
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
        for (
          int i = 0;
          i < pageLayouts.length && i < controller.pages.length;
          i++
        ) {
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
          for (
            int i = 0;
            i < pageLayouts.length && i < controller.pages.length;
            i++
          ) {
            final pLayout = pageLayouts[i];
            final dist = (docRect.center.dy - pLayout.center.dy).abs();
            if (dist < minDist) {
              minDist = dist;
              bestPageIdx = i;
            }
          }
        }

        bestPageIdx ??= (studio.pdfPage - 1).clamp(
          0,
          controller.pages.length - 1,
        );

        final pLayout = pageLayouts[bestPageIdx];
        final page = controller.pages[bestPageIdx];

        // Normalized rectangular boundary relative to this specific page
        final clampLeft = math.max(docRect.left, pLayout.left);
        final clampRight = math.min(docRect.right, pLayout.right);
        final clampTop = math.max(docRect.top, pLayout.top);
        final clampBottom = math.min(docRect.bottom, pLayout.bottom);

        final normLeft = ((clampLeft - pLayout.left) / pLayout.width).clamp(
          0.0,
          1.0,
        );
        final normTop = ((clampTop - pLayout.top) / pLayout.height).clamp(
          0.0,
          1.0,
        );
        final normRight = ((clampRight - pLayout.left) / pLayout.width).clamp(
          0.0,
          1.0,
        );
        final normBottom = ((clampBottom - pLayout.top) / pLayout.height).clamp(
          0.0,
          1.0,
        );
        final normRect = Rect.fromLTRB(
          normLeft,
          normTop,
          normRight,
          normBottom,
        );

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

            // Expand thin/zero-width space rects slightly for reliable hit-testing
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

          // Fallback if character boxes missed lines
          if (snippetText.trim().length < 5) {
            final lines = rawText.fullText
                .split('\n')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList();
            if (lines.isNotEmpty) {
              final startLine = (normTop * lines.length)
                  .clamp(0, lines.length - 1)
                  .toInt();
              final endLine = (normBottom * lines.length)
                  .clamp(startLine, lines.length - 1)
                  .toInt();
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
      FrontendLogger.write(
        '[RegionSnippingOverlay] Accurate PDF extraction error: $e',
      );
    }
    return null;
  }
}

