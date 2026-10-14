import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import '../services/pdf_annotation_exporter.dart';

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    const radius = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}

class PdfDgnlPassageOverlay extends StatefulWidget {
  const PdfDgnlPassageOverlay({
    super.key,
    required this.studio,
    required this.pageNumber,
    required this.pageRect,
  });

  final StudioState studio;
  final int pageNumber;
  final Rect pageRect;

  @override
  State<PdfDgnlPassageOverlay> createState() => _PdfDgnlPassageOverlayState();
}

class _PdfDgnlPassageOverlayState extends State<PdfDgnlPassageOverlay> {
  int _activeSpanIndex = 0;
  String? _activeCategoryFilter; // null = all, or 'grammar', 'collocation', 'vocabulary'

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.studio,
      builder: (context, _) {
        final passages = widget.studio.getPdfDgnlPassagesForPage(widget.pageNumber);
        if (passages.isEmpty) return const SizedBox.shrink();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final passage in passages) ..._buildPassageWidgets(context, passage),
          ],
        );
      },
    );
  }

  bool _isSpanContained(PdfDgnlHighlightSpan inner, PdfDgnlHighlightSpan outer) {
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

  List<Widget> _buildPassageWidgets(BuildContext context, PdfDgnlPassage passage) {
    final widgets = <Widget>[];
    final pageRect = widget.pageRect;
    final studio = widget.studio;

    final pLeft = passage.normalizedBounds.left * pageRect.width;
    final pTop = passage.normalizedBounds.top * pageRect.height;
    final pWidth = passage.normalizedBounds.width * pageRect.width;
    final pHeight = passage.normalizedBounds.height * pageRect.height;

    // Filter spans if category selected: null = Tất cả, or 'grammar', 'collocation', 'B2', 'C1'
    final visibleSpans = _activeCategoryFilter == null
        ? passage.spans
        : passage.spans.where((s) {
            if (_activeCategoryFilter == 'grammar') return s.category == 'grammar';
            if (_activeCategoryFilter == 'collocation') return s.category == 'collocation';
            if (_activeCategoryFilter == 'B2') return s.category == 'vocabulary' && s.level == 'B2';
            if (_activeCategoryFilter == 'C1') {
              return s.category == 'vocabulary' && (s.level == 'C1' || s.level == 'C2');
            }
            return true;
          }).toList();

    final grammarCount = passage.spans.where((s) => s.category == 'grammar').length;
    final collocCount = passage.spans.where((s) => s.category == 'collocation').length;
    final b2Count = passage.spans.where((s) => s.category == 'vocabulary' && s.level == 'B2').length;
    final c1Count = passage.spans.where((s) => s.category == 'vocabulary' && (s.level == 'C1' || s.level == 'C2')).length;

    // Ensure active index is within bounds
    if (_activeSpanIndex >= visibleSpans.length && visibleSpans.isNotEmpty) {
      _activeSpanIndex = 0;
    }
    final activeSpan = visibleSpans.isNotEmpty ? visibleSpans[_activeSpanIndex] : null;

    // 1. Passage boundary box (soft glowing border on the PDF page)
    widgets.add(
      Positioned(
        left: pLeft,
        top: pTop,
        width: pWidth,
        height: pHeight,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x0c89b4fa),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0x5589b4fa),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 2. Highlighting individual spans directly on the printed ink text
    for (int spanIdx = 0; spanIdx < passage.spans.length; spanIdx++) {
      final span = passage.spans[spanIdx];
      final isCurrentActive = activeSpan != null && identical(span, activeSpan);

      final matchesFilter = _activeCategoryFilter == null ||
          (_activeCategoryFilter == 'grammar' && span.category == 'grammar') ||
          (_activeCategoryFilter == 'collocation' && span.category == 'collocation') ||
          (_activeCategoryFilter == 'B2' && span.category == 'vocabulary' && span.level == 'B2') ||
          (_activeCategoryFilter == 'C1' && span.category == 'vocabulary' && (span.level == 'C1' || span.level == 'C2'));

      final spanOpacity = matchesFilter ? 1.0 : 0.14;

      // Check if vocabulary span is nested inside a collocation span
      final isNestedVocab = span.category == 'vocabulary' &&
          passage.spans.any((other) => other.category == 'collocation' && _isSpanContained(span, other));

      for (final normR in span.normalizedRects) {
        // Expand grammar dashed box slightly so it neatly wraps around inner spans
        final isGrammar = span.category == 'grammar';
        final pad = isGrammar ? 2.5 : 0.0;

        final sLeft = normR.left * pageRect.width - pad;
        final sTop = normR.top * pageRect.height - pad;
        final sWidth = normR.width * pageRect.width + (pad * 2);
        final sHeight = normR.height * pageRect.height + (pad * 2);

        Color bgColor;
        Color accentColor;

        if (isGrammar) {
          // Grammar: outer dashed border, ZERO background fill to avoid color mud
          bgColor = isCurrentActive ? const Color(0x2289b4fa) : Colors.transparent;
          accentColor = const Color(0xff89b4fa); // Neon blue
        } else if (span.category == 'collocation') {
          // Collocation: Soft green pastel fill
          bgColor = isCurrentActive ? const Color(0x4d86efac) : const Color(0x2886efac);
          accentColor = const Color(0xff86efac); // Vibrant green
        } else if (span.level == 'C1' || span.level == 'C2') {
          // C1 Vocab: If nested inside collocation, use transparent fill with crisp border
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x35cba6f7) : Colors.transparent)
              : (isCurrentActive ? const Color(0x55cba6f7) : const Color(0x28cba6f7));
          accentColor = const Color(0xffcba6f7); // Purple C1
        } else {
          // B2 Vocab: If nested inside collocation, use transparent fill with crisp border
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x35f9e2af) : Colors.transparent)
              : (isCurrentActive ? const Color(0x55f9e2af) : const Color(0x28f9e2af));
          accentColor = const Color(0xfff9e2af); // Amber/yellow B2
        }

        widgets.add(
          Positioned(
            left: sLeft,
            top: sTop,
            width: sWidth,
            height: sHeight,
            child: Opacity(
              opacity: spanOpacity,
              child: Tooltip(
                message: '[${span.type}] ${span.text}\n💡 ${span.note}',
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xf0111a15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor, width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (!matchesFilter) {
                        _activeCategoryFilter = span.category == 'grammar'
                            ? 'grammar'
                            : (span.category == 'collocation'
                                ? 'collocation'
                                : (span.level == 'C1' || span.level == 'C2' ? 'C1' : 'B2'));
                      }
                      final targetVisible = _activeCategoryFilter == null
                          ? passage.spans
                          : passage.spans.where((s) {
                              if (_activeCategoryFilter == 'grammar') return s.category == 'grammar';
                              if (_activeCategoryFilter == 'collocation') return s.category == 'collocation';
                              if (_activeCategoryFilter == 'B2') return s.category == 'vocabulary' && s.level == 'B2';
                              if (_activeCategoryFilter == 'C1') return s.category == 'vocabulary' && (s.level == 'C1' || s.level == 'C2');
                              return true;
                            }).toList();
                      final idx = targetVisible.indexOf(span);
                      _activeSpanIndex = idx != -1 ? idx : 0;
                    });
                  },
                  borderRadius: BorderRadius.circular(3),
                  child: CustomPaint(
                    painter: isGrammar
                        ? _DashedBorderPainter(
                            color: isCurrentActive ? Colors.white : accentColor,
                            strokeWidth: isCurrentActive ? 2.0 : 1.5,
                          )
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(isGrammar ? 4.5 : 3.5),
                        border: isGrammar
                            ? null
                            : Border.all(
                                color: isCurrentActive
                                    ? Colors.white
                                    : (isNestedVocab
                                        ? accentColor.withValues(alpha: 0.95)
                                        : accentColor.withValues(alpha: 0.45)),
                                width: isCurrentActive ? 1.6 : (isNestedVocab ? 1.2 : 0.8),
                              ),
                        boxShadow: isCurrentActive
                            ? [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // 3. Legend Header Bar (bounded inside PDF page dimensions, never overflowing)
    final headerTop = (pTop - 44).clamp(6.0, pageRect.height - 50).toDouble();
    const estimatedBarWidth = 620.0;
    final headerLeft = ((pLeft + estimatedBarWidth > pageRect.width - 8.0)
        ? (pageRect.width - estimatedBarWidth - 8.0).clamp(8.0, pLeft)
        : pLeft.clamp(8.0, math.max(8.0, pageRect.width - 100.0))).toDouble();
    final maxBarWidth = (pageRect.width - headerLeft - 8.0).clamp(120.0, pageRect.width).toDouble();

    widgets.add(
      Positioned(
        left: headerLeft,
        top: headerTop,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBarWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xf6111a15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xff89b4fa), width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 14, color: Color(0xff89b4fa)),
                  const SizedBox(width: 4),
                  const Text(
                    'Bóc tách Đa tầng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Chip: Tất cả các tầng
                  _buildLegendChip(
                    label: 'Tất cả',
                    count: passage.spans.length,
                    color: const Color(0xff89dceb),
                    isDashed: false,
                    isSelected: _activeCategoryFilter == null,
                    onTap: () {
                      setState(() {
                        _activeCategoryFilter = null;
                        _activeSpanIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 5),

                  // Chip: Ngữ pháp
                  _buildLegendChip(
                    label: 'Ngữ pháp',
                    count: grammarCount,
                    color: const Color(0xff89b4fa),
                    isDashed: true,
                    isSelected: _activeCategoryFilter == 'grammar',
                    onTap: () {
                      setState(() {
                        _activeCategoryFilter =
                            _activeCategoryFilter == 'grammar' ? null : 'grammar';
                        _activeSpanIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 5),

                  // Chip: Collocation
                  _buildLegendChip(
                    label: 'Collocation',
                    count: collocCount,
                    color: const Color(0xff86efac),
                    isDashed: false,
                    isSelected: _activeCategoryFilter == 'collocation',
                    onTap: () {
                      setState(() {
                        _activeCategoryFilter =
                            _activeCategoryFilter == 'collocation' ? null : 'collocation';
                        _activeSpanIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 5),

                  // Chip: CEFR B2
                  _buildLegendChip(
                    label: 'B2',
                    count: b2Count,
                    color: const Color(0xfff9e2af),
                    isDashed: false,
                    isSelected: _activeCategoryFilter == 'B2',
                    onTap: () {
                      setState(() {
                        _activeCategoryFilter =
                            _activeCategoryFilter == 'B2' ? null : 'B2';
                        _activeSpanIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 5),

                  // Chip: CEFR C1
                  if (c1Count > 0) ...[
                    _buildLegendChip(
                      label: 'C1',
                      count: c1Count,
                      color: const Color(0xffcba6f7),
                      isDashed: false,
                      isSelected: _activeCategoryFilter == 'C1',
                      onTap: () {
                        setState(() {
                          _activeCategoryFilter =
                              _activeCategoryFilter == 'C1' ? null : 'C1';
                          _activeSpanIndex = 0;
                        });
                      },
                    ),
                    const SizedBox(width: 5),
                  ],

                  const SizedBox(width: 3),

                  // Cloze Test Button
                  if (passage.clozeQuestions.isNotEmpty) ...[
                    InkWell(
                      onTap: () => _showClozeModal(context, passage),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x3386efac),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x8886efac)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.quiz_outlined, size: 12, color: Color(0xff86efac)),
                            const SizedBox(width: 3),
                            Text(
                              '${passage.clozeQuestions.length} Cloze',
                              style: const TextStyle(
                                color: Color(0xff86efac),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],

                  // Button: Highlight trực tiếp lên file PDF
                  InkWell(
                    key: const Key('btn_export_pdf_highlights'),
                    onTap: () => PdfAnnotationExporter.applyHighlightDirectlyToPdf(context, studio),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x3389b4fa),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xff89b4fa), width: 1.1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.draw_rounded, size: 12, color: Color(0xff89b4fa)),
                          SizedBox(width: 3),
                          Text(
                            'Ghi vào PDF',
                            style: TextStyle(
                              color: Color(0xff89b4fa),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Close / Dismiss Highlight Button
                  InkWell(
                    onTap: () => studio.removePdfDgnlPassage(passage.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0x28ffffff),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 12, color: Color(0xffa6adc8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 4. Floating Lecturer Explanation Card (Directly on the document file)
    if (activeSpan != null) {
      final cardTop = (pTop + pHeight + 10).clamp(8.0, pageRect.height - 130).toDouble();
      final cardWidth = math.max(pWidth, 420.0).clamp(340.0, pageRect.width - 24).toDouble();
      final cardLeft = pLeft.clamp(8.0, math.max(8.0, pageRect.width - cardWidth - 8)).toDouble();

      Color categoryColor = const Color(0xff89b4fa);
      if (activeSpan.category == 'collocation') {
        categoryColor = const Color(0xff86efac);
      } else if (activeSpan.level == 'C1' || activeSpan.level == 'C2') {
        categoryColor = const Color(0xffcba6f7);
      } else if (activeSpan.level == 'B2') {
        categoryColor = const Color(0xfff9e2af);
      }

      widgets.add(
        Positioned(
          left: cardLeft,
          top: cardTop,
          width: cardWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xf8111a15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: categoryColor.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xbb000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Title & Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            activeSpan.category == 'grammar'
                                ? Icons.auto_stories_outlined
                                : Icons.lightbulb_outline,
                            size: 16,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              activeSpan.type,
                              style: TextStyle(
                                color: categoryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: categoryColor.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        activeSpan.category == 'grammar'
                            ? 'GRAMMAR'
                            : (activeSpan.category == 'collocation' ? 'COLLOCATION' : activeSpan.level),
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => PdfAnnotationExporter.applyHighlightDirectlyToPdf(context, studio),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x2889b4fa),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x6689b4fa)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.draw_rounded, size: 11, color: Color(0xff89b4fa)),
                            SizedBox(width: 3),
                            Text(
                              'Áp lên file',
                              style: TextStyle(
                                color: Color(0xff89b4fa),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Note description
                Text(
                  activeSpan.note,
                  style: const TextStyle(
                    color: Color(0xffe2e8f0),
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),

                // Target text snippet
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x22ffffff),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '📌 "${activeSpan.text}"',
                    style: TextStyle(
                      color: categoryColor.withValues(alpha: 0.95),
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),

                // Stepper Navigation Footer for Fast Lecturing
                Builder(
                  builder: (context) {
                    final canGoPrev = _activeSpanIndex > 0;
                    final canGoNext = _activeSpanIndex < visibleSpans.length - 1;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: canGoPrev
                              ? () {
                                  setState(() {
                                    _activeSpanIndex--;
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: canGoPrev ? 1.0 : 0.35,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: canGoPrev ? const Color(0x22ffffff) : const Color(0x0affffff),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: canGoPrev ? Colors.white24 : Colors.transparent,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chevron_left,
                                    size: 14,
                                    color: canGoPrev ? Colors.white : Colors.white38,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Trước',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: canGoPrev ? Colors.white : Colors.white38,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${_activeSpanIndex + 1} / ${visibleSpans.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xff94a3b8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          onTap: canGoNext
                              ? () {
                                  setState(() {
                                    _activeSpanIndex++;
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: canGoNext ? 1.0 : 0.35,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: canGoNext
                                    ? categoryColor.withValues(alpha: 0.25)
                                    : const Color(0x0affffff),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: canGoNext
                                      ? categoryColor.withValues(alpha: 0.6)
                                      : Colors.transparent,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Tiếp theo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: canGoNext ? categoryColor : Colors.white38,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 14,
                                    color: canGoNext ? categoryColor : Colors.white38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildLegendChip({
    required String label,
    required int count,
    required Color color,
    required bool isDashed,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: isDashed
              ? null
              : Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.6),
                  width: isSelected ? 1.4 : 1.0,
                ),
        ),
        child: CustomPaint(
          painter: isDashed
              ? _DashedBorderPainter(
                  color: isSelected ? color : color.withValues(alpha: 0.8),
                  strokeWidth: isSelected ? 1.4 : 1.0,
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: isDashed ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isDashed ? BorderRadius.circular(1) : null,
                  ),
                ),
                const SizedBox(width: 3.5),
                Text(
                  count > 0 ? '$label ($count)' : label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClozeModal(BuildContext context, PdfDgnlPassage passage) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xf6111a15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xff89b4fa), width: 1.2),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.quiz, color: Color(0xff86efac), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bài tập Đục lỗ (Cloze Test) tự sinh theo chuẩn ĐGNL',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: passage.clozeQuestions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final q = passage.clozeQuestions[idx];
                  final sentence = q['sentence']?.toString() ?? '';
                  final options = (q['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
                  final answer = q['answer']?.toString() ?? '';
                  final explanation = q['explanation']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x1effffff),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x28ffffff)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Câu ${idx + 1}: $sentence',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (int optIdx = 0; optIdx < options.length; optIdx++) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: options[optIdx] == answer ? const Color(0x3386efac) : const Color(0x18ffffff),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: options[optIdx] == answer ? const Color(0x8886efac) : const Color(0x28ffffff),
                                  ),
                                ),
                                child: Text(
                                  '${String.fromCharCode(65 + optIdx)}. ${options[optIdx]}',
                                  style: TextStyle(
                                    color: options[optIdx] == answer ? const Color(0xff86efac) : const Color(0xffcdd6f4),
                                    fontSize: 11.5,
                                    fontWeight: options[optIdx] == answer ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (explanation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '💡 $explanation',
                            style: const TextStyle(color: Color(0xff94a3b8), fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
