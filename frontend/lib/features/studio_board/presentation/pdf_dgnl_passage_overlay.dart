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

    final policy = studio.pedagogicalPolicy;

    // Filter spans according to active display mode or category:
    // Mode A (null): Chế độ trọng tâm sư phạm mặc định (Ngữ pháp + Collocation + B2-C2/AWL + B1 chọn lọc)
    // Mode B ('vocabulary_all'): Chế độ tất cả từ vựng A1-C2 (Ngữ pháp + Collocation + A1-C2 từ vựng đã chuẩn hóa)
    // Mode Unknown ('unknown'): Bộ lọc riêng cho các từ chưa định danh
    final visibleSpans = _activeCategoryFilter == null
        ? policy.filterSpans(passage.spans)
        : passage.spans.where((s) {
            if (_activeCategoryFilter == 'grammar') {
              return s.category == 'grammar';
            }
            if (_activeCategoryFilter == 'collocation') {
              return s.category == 'collocation';
            }
            if (_activeCategoryFilter == 'vocabulary') {
              return s.category == 'vocabulary' &&
                  policy.isEligibleForHighlight(s);
            }
            if (_activeCategoryFilter == 'vocabulary_all') {
              if (s.category == 'vocabulary') {
                return s.level != 'Unknown' &&
                    !s.isFunctionWord &&
                    !s.isNumber &&
                    !s.isProperNoun;
              }
              return true;
            }
            if (_activeCategoryFilter == 'unknown') {
              return s.category == 'vocabulary' && s.level == 'Unknown';
            }
            if (_activeCategoryFilter == 'A1') {
              return s.category == 'vocabulary' &&
                  s.level == 'A1' &&
                  !s.isFunctionWord &&
                  !s.isNumber &&
                  !s.isProperNoun;
            }
            if (_activeCategoryFilter == 'A2') {
              return s.category == 'vocabulary' &&
                  s.level == 'A2' &&
                  !s.isFunctionWord &&
                  !s.isNumber &&
                  !s.isProperNoun;
            }
            if (_activeCategoryFilter == 'B1') {
              return s.category == 'vocabulary' &&
                  s.level == 'B1' &&
                  !s.isFunctionWord &&
                  !s.isNumber &&
                  !s.isProperNoun;
            }
            if (_activeCategoryFilter == 'B2') {
              return s.category == 'vocabulary' &&
                  s.level == 'B2' &&
                  !s.isFunctionWord &&
                  !s.isNumber &&
                  !s.isProperNoun;
            }
            if (_activeCategoryFilter == 'C1') {
              return s.category == 'vocabulary' &&
                  s.level == 'C1' &&
                  !s.isFunctionWord &&
                  !s.isNumber &&
                  !s.isProperNoun;
            }
            if (_activeCategoryFilter == 'C2') {
              return s.category == 'vocabulary' &&
                  s.level == 'C2' &&
                  !s.isFunctionWord &&
                  !s.isNumber &&
                  !s.isProperNoun;
            }
            return true;
          }).toList();

    final grammarCount = passage.spans
        .where((s) => s.category == 'grammar')
        .length;
    final collocCount = passage.spans
        .where((s) => s.category == 'collocation')
        .length;

    // Số điểm nhấn trọng tâm sư phạm theo policy (Mode A)
    final focusedCount = policy.filterSpans(passage.spans).length;

    // Khử trùng lặp từ vựng khi đếm số lượng học thuật (Unique Lemmas/Terms)
    final uniqueA1Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'A1' && !s.isFunctionWord)
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniqueA2Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'A2' && !s.isFunctionWord)
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniqueB1Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'B1')
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniqueB2Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'B2')
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniqueC1Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'C1')
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniqueC2Count = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'C2')
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniqueUnknownCount = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level == 'Unknown')
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniquePedagogicalVocabCount = passage.spans
        .where(
          (s) => s.category == 'vocabulary' && policy.isEligibleForHighlight(s),
        )
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniqueTotalCefrCount = passage.spans
        .where((s) => s.category == 'vocabulary' && s.level != 'Unknown' && !s.isFunctionWord)
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
        .toSet()
        .length;
    final uniqueTotalVocabCount = passage.spans
        .where((s) => s.category == 'vocabulary')
        .map((s) => (s.lemma ?? s.text).toLowerCase().trim())
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
    if (studio.pdfHighlightsVisible) {
      for (int spanIdx = 0; spanIdx < passage.spans.length; spanIdx++) {
      final span = passage.spans[spanIdx];
      final isCurrentActive = activeSpan != null && identical(span, activeSpan);

      final matchesFilter = visibleSpans.contains(span);
      final spanOpacity = matchesFilter ? 1.0 : 0.12;

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

        final colors = DgnlHighlightPalette.resolveOverlayColors(
          span: span,
          isCurrentActive: isCurrentActive,
          isNestedVocab: isNestedVocab,
        );
        final bgColor = colors.background;

        widgets.add(
          Positioned(
            left: sLeft,
            top: sTop,
            width: sWidth,
            height: sHeight,
            child: Opacity(
              opacity: spanOpacity,
              child: Tooltip(
                message: _buildCompactTooltipMessage(span),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xf0111a15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.token.badgeDark, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 2),
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
                            color: isCurrentActive ? Colors.white : colors.stroke,
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
                                          ? colors.stroke.withValues(alpha: 0.95)
                                          : colors.stroke.withValues(
                                              alpha: 0.85,
                                            )),
                                width: isCurrentActive
                                    ? 1.6
                                    : (isNestedVocab ? 1.2 : 0.8),
                              ),
                        boxShadow: isCurrentActive
                            ? [
                                BoxShadow(
                                  color: colors.stroke.withValues(alpha: 0.6),
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

                        // Chip: Trọng tâm (Mode A: Ngữ pháp + Collocation + B1-C2/AWL)
                        _buildLegendChip(
                          label: 'Trọng tâm',
                          count: focusedCount,
                          color: DgnlHighlightPalette.tokenFocused.badgeDark,
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
                          color: DgnlHighlightPalette.tokenGrammar.badgeDark,
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
                          color: DgnlHighlightPalette.tokenCollocation.badgeDark,
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

                        // Smart CEFR Dropdown Chip (Consolidates 6 levels + Mode B + Unknown into 1 interactive popup)
                        if (uniqueTotalVocabCount > 0) ...[
                          _buildCefrDropdownChip(
                            pedagogicalCount: uniquePedagogicalVocabCount,
                            totalCefrCount: uniqueTotalCefrCount,
                            a1Count: uniqueA1Count,
                            a2Count: uniqueA2Count,
                            b1Count: uniqueB1Count,
                            b2Count: uniqueB2Count,
                            c1Count: uniqueC1Count,
                            c2Count: uniqueC2Count,
                            unknownCount: uniqueUnknownCount,
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
                                color: DgnlHighlightPalette.tokenAllVocab.badgeDark.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: DgnlHighlightPalette.tokenAllVocab.badgeDark,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 12,
                                    color: DgnlHighlightPalette.tokenAllVocab.badgeDark,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Độ khó',
                                    style: TextStyle(
                                      color: DgnlHighlightPalette.tokenAllVocab.badgeDark,
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
                                color: DgnlHighlightPalette.tokenCollocation.badgeDark.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: DgnlHighlightPalette.tokenCollocation.badgeDark.withValues(alpha: 0.7),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.quiz_outlined,
                                    size: 12,
                                    color: DgnlHighlightPalette.tokenCollocation.badgeDark,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${passage.clozeQuestions.length} Cloze',
                                    style: TextStyle(
                                      color: DgnlHighlightPalette.tokenCollocation.badgeDark,
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

                        // Button: Ẩn/Hiện lớp Highlight
                        InkWell(
                          key: const Key('btn_toggle_pdf_highlights'),
                          onTap: () => studio.togglePdfHighlightsVisible(),
                          borderRadius: BorderRadius.circular(6),
                          child: Tooltip(
                            message: studio.pdfHighlightsVisible
                                ? 'Ẩn lớp Highlight (Ctrl+H)'
                                : 'Hiện lớp Highlight (Ctrl+H)',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: studio.pdfHighlightsVisible
                                    ? const Color(0x3389b4fa)
                                    : const Color(0x33f38ba8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: studio.pdfHighlightsVisible
                                      ? const Color(0xff89b4fa)
                                      : const Color(0xfff38ba8),
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                studio.pdfHighlightsVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 12,
                                color: studio.pdfHighlightsVisible
                                    ? const Color(0xff89b4fa)
                                    : const Color(0xfff38ba8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Button: Xóa lớp Highlight
                        InkWell(
                          key: const Key('btn_clear_pdf_highlights'),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xff1e1e2e),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                title: const Text(
                                  'Xóa Highlight trên trang?',
                                  style: TextStyle(
                                    color: Color(0xffcdd6f4),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                content: const Text(
                                  'Chỉ xóa các điểm highlight từ vựng và ngữ pháp đã quét trên trang này. Nét vẽ tay và tệp PDF gốc không bị thay đổi.',
                                  style: TextStyle(
                                    color: Color(0xffa6adc8),
                                    fontSize: 12,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Hủy'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xfff38ba8),
                                      foregroundColor: const Color(0xff11111b),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Xóa'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              studio.clearPdfHighlights(pageNumber: passage.pageNumber);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Tooltip(
                            message: 'Xóa toàn bộ highlight trên trang này',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x22f38ba8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0x66f38ba8),
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.layers_clear_outlined,
                                size: 12,
                                color: Color(0xfff38ba8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

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
                                color: DgnlHighlightPalette.tokenGrammar.badgeDark.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: DgnlHighlightPalette.tokenGrammar.badgeDark,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.draw_rounded,
                                    size: 12,
                                    color: DgnlHighlightPalette.tokenGrammar.badgeDark,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Ghi PDF',
                                    style: TextStyle(
                                      color: DgnlHighlightPalette.tokenGrammar.badgeDark,
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

  /// Builds a single-line, ultra-compact hover tooltip message:
  /// e.g. '[AWL] researcher', 'B1 · researcher', '[Collocation] bitter taste'
  static String _buildCompactTooltipMessage(PdfDgnlHighlightSpan span) {
    final type = span.type.trim();
    final text = span.text.trim();
    if (type.toUpperCase() == 'AWL' || span.isAcademic) {
      return '[AWL] $text';
    }
    const cefrLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};
    if (cefrLevels.contains(type.toUpperCase())) {
      return '${type.toUpperCase()} · $text';
    }
    final level = span.level.trim().toUpperCase();
    if (cefrLevels.contains(level)) {
      return '$level · $text';
    }
    return '[$type] $text';
  }
}
