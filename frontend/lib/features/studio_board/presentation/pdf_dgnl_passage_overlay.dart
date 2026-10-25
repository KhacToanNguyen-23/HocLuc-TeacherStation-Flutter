import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import '../services/pdf_annotation_exporter.dart';
import 'widgets/text_profiler_dialog.dart';

part 'pdf_dgnl_passage_dialogs.dart';

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
  String?
  _activeCategoryFilter; // null = all, or 'grammar', 'collocation', 'vocabulary'

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.studio,
      builder: (context, _) {
        final passages = widget.studio.getPdfDgnlPassagesForPage(
          widget.pageNumber,
        );
        if (passages.isEmpty) return const SizedBox.shrink();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final passage in passages)
              ..._buildPassageWidgets(context, passage),
          ],
        );
      },
    );
  }

  bool _isSpanContained(
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

  List<Widget> _buildPassageWidgets(
    BuildContext context,
    PdfDgnlPassage passage,
  ) {
    final widgets = <Widget>[];
    final pageRect = widget.pageRect;
    final studio = widget.studio;

    final pLeft = passage.normalizedBounds.left * pageRect.width;
    final pTop = passage.normalizedBounds.top * pageRect.height;
    final pWidth = passage.normalizedBounds.width * pageRect.width;
    final pHeight = passage.normalizedBounds.height * pageRect.height;

    bool isPedagogicalVocab(PdfDgnlHighlightSpan s) {
      if (s.category != 'vocabulary') return false;
      final lvl = s.level.toUpperCase();
      return lvl == 'B1' ||
          lvl == 'B2' ||
          lvl == 'C1' ||
          lvl == 'C2' ||
          s.type.contains('AWL') ||
          s.type.contains('Dạy trước') ||
          s.note.contains('AWL') ||
          s.note.contains('trọng tâm');
    }

    // Filter spans if category selected:
    // null = Tất cả (Chế độ sư phạm chọn lọc mặc định: Ngữ pháp + Collocation + Từ vựng B1-C2/AWL)
    // Các từ cơ bản A1-A2 chỉ hiển thị khi người dùng chủ động chọn lọc theo cấp độ
    final visibleSpans = _activeCategoryFilter == null
        ? passage.spans.where((s) {
            if (s.category == 'vocabulary') {
              return isPedagogicalVocab(s);
            }
            return true;
          }).toList()
        : passage.spans.where((s) {
            if (_activeCategoryFilter == 'grammar') {
              return s.category == 'grammar';
            }
            if (_activeCategoryFilter == 'collocation') {
              return s.category == 'collocation';
            }
            if (_activeCategoryFilter == 'vocabulary') {
              return s.category == 'vocabulary' && isPedagogicalVocab(s);
            }
            if (_activeCategoryFilter == 'vocabulary_all') {
              return s.category == 'vocabulary';
            }
            if (_activeCategoryFilter == 'A1') {
              return s.category == 'vocabulary' && s.level == 'A1';
            }
            if (_activeCategoryFilter == 'A2') {
              return s.category == 'vocabulary' && s.level == 'A2';
            }
            if (_activeCategoryFilter == 'B1') {
              return s.category == 'vocabulary' && s.level == 'B1';
            }
            if (_activeCategoryFilter == 'B2') {
              return s.category == 'vocabulary' && s.level == 'B2';
            }
            if (_activeCategoryFilter == 'C1') {
              return s.category == 'vocabulary' && s.level == 'C1';
            }
            if (_activeCategoryFilter == 'C2') {
              return s.category == 'vocabulary' && s.level == 'C2';
            }
            return true;
          }).toList();

    final grammarCount = passage.spans
        .where((s) => s.category == 'grammar')
        .length;
    final collocCount = passage.spans
        .where((s) => s.category == 'collocation')
        .length;

    // Khử trùng lặp từ vựng khi đếm số lượng học thuật (Unique Lemmas/Terms)
    final uniqueA1Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'A1')
        .map((s) => s.text.toLowerCase().trim())
        .toSet()
        .length;
    final uniqueA2Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'A2')
        .map((s) => s.text.toLowerCase().trim())
        .toSet()
        .length;
    final uniqueB1Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'B1')
        .map((s) => s.text.toLowerCase().trim())
        .toSet()
        .length;
    final uniqueB2Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'B2')
        .map((s) => s.text.toLowerCase().trim())
        .toSet()
        .length;
    final uniqueC1Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'C1')
        .map((s) => s.text.toLowerCase().trim())
        .toSet()
        .length;
    final uniqueC2Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'C2')
        .map((s) => s.text.toLowerCase().trim())
        .toSet()
        .length;
    final uniquePedagogicalVocabCount = passage.spans
        .where(isPedagogicalVocab)
        .map((s) => s.text.toLowerCase().trim())
        .toSet()
        .length;
    final uniqueTotalVocabCount = passage.spans
        .where((s) => s.category == 'vocabulary')
        .map((s) => s.text.toLowerCase().trim())
        .toSet()
        .length;

    // Ensure active index is within bounds
    if (_activeSpanIndex >= visibleSpans.length && visibleSpans.isNotEmpty) {
      _activeSpanIndex = 0;
    }
    final activeSpan = visibleSpans.isNotEmpty
        ? visibleSpans[_activeSpanIndex]
        : null;

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
              border: Border.all(color: const Color(0x5589b4fa), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 8,
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

      final matchesFilter =
          _activeCategoryFilter == null ||
          (_activeCategoryFilter == 'grammar' && span.category == 'grammar') ||
          (_activeCategoryFilter == 'collocation' &&
              span.category == 'collocation') ||
          (_activeCategoryFilter == 'A1' &&
              span.category == 'vocabulary' &&
              span.level == 'A1') ||
          (_activeCategoryFilter == 'A2' &&
              span.category == 'vocabulary' &&
              span.level == 'A2') ||
          (_activeCategoryFilter == 'B1' &&
              span.category == 'vocabulary' &&
              span.level == 'B1') ||
          (_activeCategoryFilter == 'B2' &&
              span.category == 'vocabulary' &&
              span.level == 'B2') ||
          (_activeCategoryFilter == 'C1' &&
              span.category == 'vocabulary' &&
              span.level == 'C1') ||
          (_activeCategoryFilter == 'C2' &&
              span.category == 'vocabulary' &&
              span.level == 'C2');

      final spanOpacity = matchesFilter ? 1.0 : 0.14;

      // Check if vocabulary span is nested inside a collocation span
      final isNestedVocab =
          span.category == 'vocabulary' &&
          passage.spans.any(
            (other) =>
                other.category == 'collocation' &&
                _isSpanContained(span, other),
          );

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
          bgColor = isCurrentActive
              ? const Color(0x2289b4fa)
              : Colors.transparent;
          accentColor = const Color(0xff89b4fa); // Neon blue
        } else if (span.category == 'collocation') {
          // Collocation: Soft green pastel fill
          bgColor = isCurrentActive
              ? const Color(0x4d86efac)
              : const Color(0x2886efac);
          accentColor = const Color(0xff86efac); // Vibrant green
        } else if (span.level == 'A1') {
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x3522c55e) : Colors.transparent)
              : (isCurrentActive
                    ? const Color(0x5522c55e)
                    : const Color(0x2822c55e));
          accentColor = const Color(0xff22c55e); // Green A1
        } else if (span.level == 'A2') {
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x3514b8a6) : Colors.transparent)
              : (isCurrentActive
                    ? const Color(0x5514b8a6)
                    : const Color(0x2814b8a6));
          accentColor = const Color(0xff14b8a6); // Teal A2
        } else if (span.level == 'B1') {
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x353b82f6) : Colors.transparent)
              : (isCurrentActive
                    ? const Color(0x553b82f6)
                    : const Color(0x283b82f6));
          accentColor = const Color(0xff3b82f6); // Blue B1
        } else if (span.level == 'B2') {
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x35f59e0b) : Colors.transparent)
              : (isCurrentActive
                    ? const Color(0x55f59e0b)
                    : const Color(0x28f59e0b));
          accentColor = const Color(0xfff59e0b); // Amber B2
        } else if (span.level == 'C1') {
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x35f97316) : Colors.transparent)
              : (isCurrentActive
                    ? const Color(0x55f97316)
                    : const Color(0x28f97316));
          accentColor = const Color(0xfff97316); // Orange C1
        } else if (span.level == 'C2') {
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x35a855f7) : Colors.transparent)
              : (isCurrentActive
                    ? const Color(0x55a855f7)
                    : const Color(0x28a855f7));
          accentColor = const Color(0xffa855f7); // Purple C2
        } else {
          bgColor = isNestedVocab
              ? (isCurrentActive ? const Color(0x3594a3b8) : Colors.transparent)
              : (isCurrentActive
                    ? const Color(0x5594a3b8)
                    : const Color(0x2894a3b8));
          accentColor = const Color(0xff94a3b8); // Gray Unknown
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
                message: '[${span.type}] ${span.text}\n• ${span.note}',
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
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
                                  : (span.level == 'C1' || span.level == 'C2'
                                        ? 'C1'
                                        : 'B2'));
                      }
                      final targetVisible = _activeCategoryFilter == null
                          ? passage.spans
                          : passage.spans.where((s) {
                              if (_activeCategoryFilter == 'grammar') {
                                return s.category == 'grammar';
                              }
                              if (_activeCategoryFilter == 'collocation') {
                                return s.category == 'collocation';
                              }
                              if (_activeCategoryFilter == 'B2') {
                                return s.category == 'vocabulary' &&
                                    s.level == 'B2';
                              }
                              if (_activeCategoryFilter == 'C1') {
                                return s.category == 'vocabulary' &&
                                    (s.level == 'C1' || s.level == 'C2');
                              }
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
                        borderRadius: BorderRadius.circular(
                          isGrammar ? 4.5 : 3.5,
                        ),
                        border: isGrammar
                            ? null
                            : Border.all(
                                color: isCurrentActive
                                    ? Colors.white
                                    : (isNestedVocab
                                          ? accentColor.withValues(alpha: 0.95)
                                          : accentColor.withValues(
                                              alpha: 0.45,
                                            )),
                                width: isCurrentActive
                                    ? 1.6
                                    : (isNestedVocab ? 1.2 : 0.8),
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
    const estimatedBarWidth = 490.0;
    final headerLeft =
        ((pLeft + estimatedBarWidth > pageRect.width - 8.0)
                ? (pageRect.width - estimatedBarWidth - 8.0).clamp(8.0, pLeft)
                : pLeft.clamp(8.0, math.max(8.0, pageRect.width - 100.0)))
            .toDouble();
    final maxBarWidth = (pageRect.width - headerLeft - 8.0)
        .clamp(120.0, pageRect.width)
        .toDouble();

    widgets.add(
      Positioned(
        left: headerLeft,
        top: headerTop,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBarWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xf6111a15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xff89b4fa), width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrollable category filters & quick actions
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 13,
                          color: Color(0xff89b4fa),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Bóc tách Đa tầng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Chip: Tất cả các tầng (Lớp phủ sư phạm mặc định)
                        _buildLegendChip(
                          label: 'Tất cả',
                          count: visibleSpans.length,
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
                        const SizedBox(width: 4),

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
                                  _activeCategoryFilter == 'grammar'
                                  ? null
                                  : 'grammar';
                              _activeSpanIndex = 0;
                            });
                          },
                        ),
                        const SizedBox(width: 4),

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
                                  _activeCategoryFilter == 'collocation'
                                  ? null
                                  : 'collocation';
                              _activeSpanIndex = 0;
                            });
                          },
                        ),
                        const SizedBox(width: 4),

                        // Smart CEFR Dropdown Chip (Consolidates 6 levels into 1 interactive popup)
                        if (uniqueTotalVocabCount > 0) ...[
                          _buildCefrDropdownChip(
                            totalVocabCount: uniquePedagogicalVocabCount > 0
                                ? uniquePedagogicalVocabCount
                                : uniqueTotalVocabCount,
                            a1Count: uniqueA1Count,
                            a2Count: uniqueA2Count,
                            b1Count: uniqueB1Count,
                            b2Count: uniqueB2Count,
                            c1Count: uniqueC1Count,
                            c2Count: uniqueC2Count,
                          ),
                          const SizedBox(width: 4),
                        ],

                        // Button: Hồ sơ độ khó Ngữ liệu (English Text Profiler)
                        InkWell(
                          key: const Key('btn_open_text_profiler'),
                          onTap: () =>
                              TextProfilerDialog.show(context, passage),
                          borderRadius: BorderRadius.circular(6),
                          child: Tooltip(
                            message: 'Hồ sơ độ khó Ngữ liệu (Text Profiler)',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x33cba6f7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xffcba6f7),
                                  width: 1.0,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 12,
                                    color: Color(0xffcba6f7),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Độ khó',
                                    style: TextStyle(
                                      color: Color(0xffcba6f7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Cloze Test Button
                        if (passage.clozeQuestions.isNotEmpty) ...[
                          InkWell(
                            onTap: () => _showClozeModal(context, passage),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x3386efac),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0x8886efac),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.quiz_outlined,
                                    size: 12,
                                    color: Color(0xff86efac),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${passage.clozeQuestions.length} Cloze',
                                    style: const TextStyle(
                                      color: Color(0xff86efac),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],

                        // Button: Highlight trực tiếp lên file PDF
                        InkWell(
                          key: const Key('btn_export_pdf_highlights'),
                          onTap: () =>
                              PdfAnnotationExporter.applyHighlightDirectlyToPdf(
                                context,
                                studio,
                              ),
                          borderRadius: BorderRadius.circular(6),
                          child: Tooltip(
                            message: 'Ghi chú thích trực tiếp lên file PDF',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x3389b4fa),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xff89b4fa),
                                  width: 1.0,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.draw_rounded,
                                    size: 12,
                                    color: Color(0xff89b4fa),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Ghi PDF',
                                    style: TextStyle(
                                      color: Color(0xff89b4fa),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
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

                const SizedBox(width: 6),
                // Subtle separator
                Container(width: 1, height: 14, color: const Color(0x4489b4fa)),
                const SizedBox(width: 5),

                // Pinned Close / Dismiss Button (ALWAYS 100% VISIBLE)
                InkWell(
                  key: const Key('btn_close_dgnl_overlay'),
                  onTap: () => studio.removePdfDgnlPassage(passage.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Tooltip(
                    message: 'Đóng bóc tách đoạn văn',
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: Color(0x28ffffff),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 13,
                        color: Color(0xffcdd6f4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 4. Floating Lecturer Explanation Card (Directly on the document file)
    if (activeSpan != null) {
      widgets.add(
        _buildActiveSpanExplanationCard(
          context: context,
          studio: studio,
          activeSpan: activeSpan,
          visibleSpans: visibleSpans,
          pageRect: pageRect,
          pLeft: pLeft,
          pTop: pTop,
          pWidth: pWidth,
          pHeight: pHeight,
        ),
      );
    }

    return widgets;
  }
}
