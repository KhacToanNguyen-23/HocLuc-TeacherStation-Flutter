// ignore_for_file: invalid_use_of_protected_member
part of 'pdf_dgnl_passage_overlay.dart';

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedBorderPainter({required this.color, this.strokeWidth = 1.6});

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
      const Radius.circular(radius),
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

extension _PdfDgnlPassageDialogsExt on _PdfDgnlPassageOverlayState {
  Widget _buildActiveSpanExplanationCard({
    required BuildContext context,
    required StudioState studio,
    required String passageId,
    required PdfDgnlHighlightSpan activeSpan,
    required List<PdfDgnlHighlightSpan> visibleSpans,
    required Rect pageRect,
    required double pLeft,
    required double pTop,
    required double pWidth,
    required double pHeight,
  }) {
    final cardTop = (pTop + pHeight + 10)
        .clamp(8.0, pageRect.height - 130)
        .toDouble();
    final cardWidth = math
        .max(pWidth, 420.0)
        .clamp(340.0, pageRect.width - 24)
        .toDouble();
    final cardLeft = pLeft
        .clamp(8.0, math.max(8.0, pageRect.width - cardWidth - 8))
        .toDouble();

    final token = DgnlHighlightPalette.tokenForSpan(activeSpan);
    final categoryColor = token.badgeDark;

    return Positioned(
      left: cardLeft,
      top: cardTop,
      width: cardWidth,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('span_card_${activeSpan.text}_$cardLeft'),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: AppMotion.popoverDuration,
        curve: AppMotion.easeOut,
        builder: (context, value, child) {
          final scale = 0.96 + (0.04 * value);
          return Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xf8111a15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: categoryColor.withValues(alpha: 0.85),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xbb000000),
                blurRadius: 8,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: token.fill.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: categoryColor.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Text(
                      activeSpan.category == 'grammar'
                          ? 'GRAMMAR'
                          : (activeSpan.category == 'collocation'
                                ? 'COLLOCATION'
                                : activeSpan.level),
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message:
                        'Lưu điểm highlight vào tài liệu (có thể tẩy xóa và bảo toàn tệp gốc)',
                    child: InkWell(
                      onTap: () =>
                          PdfAnnotationExporter.applyHighlightDirectlyToPdf(
                            context,
                            studio,
                            passageId: passageId,
                            selectedSpans: visibleSpans,
                          ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DgnlHighlightPalette.tokenGrammar.badgeDark
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: DgnlHighlightPalette.tokenGrammar.badgeDark
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.draw_rounded,
                              size: 11,
                              color:
                                  DgnlHighlightPalette.tokenGrammar.badgeDark,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Áp lên file',
                              style: TextStyle(
                                color:
                                    DgnlHighlightPalette.tokenGrammar.badgeDark,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x22ffffff),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '"${activeSpan.text}"',
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
                          duration: AppMotion.duration(
                            context,
                            milliseconds: 150,
                          ),
                          curve: AppMotion.stateCurve,
                          opacity: canGoPrev ? 1.0 : 0.35,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: canGoPrev
                                  ? const Color(0x22ffffff)
                                  : const Color(0x0affffff),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: canGoPrev
                                    ? Colors.white24
                                    : Colors.transparent,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chevron_left,
                                  size: 14,
                                  color: canGoPrev
                                      ? Colors.white
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Trước',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: canGoPrev
                                        ? Colors.white
                                        : Colors.white38,
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
                          duration: AppMotion.duration(
                            context,
                            milliseconds: 150,
                          ),
                          curve: AppMotion.stateCurve,
                          opacity: canGoNext ? 1.0 : 0.35,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
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
                                    color: canGoNext
                                        ? categoryColor
                                        : Colors.white38,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: canGoNext
                                      ? categoryColor
                                      : Colors.white38,
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
          color: isSelected
              ? color.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: isDashed
              ? null
              : Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.7),
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

  Widget _buildCefrDropdownChip({
    required int pedagogicalCount,
    required int totalCefrCount,
    required int a1Count,
    required int a2Count,
    required int b1Count,
    required int b2Count,
    required int c1Count,
    required int c2Count,
    int unknownCount = 0,
  }) {
    final active = _activeCategoryFilter;
    final isCefrActive =
        active == 'vocabulary' ||
        active == 'vocabulary_all' ||
        active == 'unknown' ||
        active == 'A1' ||
        active == 'A2' ||
        active == 'B1' ||
        active == 'B2' ||
        active == 'C1' ||
        active == 'C2';

    final token = DgnlHighlightPalette.tokenForCategory(
      active ?? 'vocabulary',
      active,
    );
    final activeColor = token.badgeDark;
    final displayLabel = switch (active) {
      'A1' => 'A1 ($a1Count)',
      'A2' => 'A2 ($a2Count)',
      'B1' => 'B1 ($b1Count)',
      'B2' => 'B2 ($b2Count)',
      'C1' => 'C1 ($c1Count)',
      'C2' => 'C2 ($c2Count)',
      'unknown' => 'Unknown ($unknownCount)',
      'vocabulary_all' => 'Tất cả từ ($totalCefrCount)',
      _ => 'CEFR ($pedagogicalCount/$totalCefrCount)',
    };

    return Theme(
      data: Theme.of(context).copyWith(cardColor: const Color(0xf6181825)),
      child: PopupMenuButton<String>(
        tooltip: 'Lọc cấp độ từ vựng CEFR',
        offset: const Offset(0, 24),
        color: const Color(0xf6181825),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xff45475a), width: 1),
        ),
        onSelected: (val) {
          setState(() {
            if (val == 'clear' || _activeCategoryFilter == val) {
              _activeCategoryFilter = null;
              widget.studio.setPedagogicalPolicy(
                PedagogicalHighlightPolicy.defaultPolicy,
              );
            } else {
              _activeCategoryFilter = val;
              if (val == 'vocabulary_all') {
                widget.studio.setPedagogicalPolicy(
                  PedagogicalHighlightPolicy.allVocabulary,
                );
              }
            }
            _activeSpanIndex = 0;
          });
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'vocabulary',
            height: 32,
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 14,
                  color: DgnlHighlightPalette.tokenAllVocab.badgeDark,
                ),
                const SizedBox(width: 8),
                Text(
                  'Từ vựng Trọng tâm B1-C2 ($pedagogicalCount)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_activeCategoryFilter == 'vocabulary') ...[
                  const Spacer(),
                  Icon(
                    Icons.check,
                    size: 14,
                    color: DgnlHighlightPalette.tokenAllVocab.badgeDark,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'vocabulary_all',
            height: 32,
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: DgnlHighlightPalette.tokenFocused.badgeDark,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tất cả từ vựng A1-C2 ($totalCefrCount)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_activeCategoryFilter == 'vocabulary_all') ...[
                  const Spacer(),
                  Icon(
                    Icons.check,
                    size: 14,
                    color: DgnlHighlightPalette.tokenFocused.badgeDark,
                  ),
                ],
              ],
            ),
          ),
          const PopupMenuDivider(height: 6),
          if (a1Count > 0)
            _buildCefrMenuItem(
              'A1',
              'Cơ bản',
              a1Count,
              DgnlHighlightPalette.tokenA1.badgeDark,
            ),
          if (a2Count > 0)
            _buildCefrMenuItem(
              'A2',
              'Sơ cấp',
              a2Count,
              DgnlHighlightPalette.tokenA2.badgeDark,
            ),
          if (b1Count > 0)
            _buildCefrMenuItem(
              'B1',
              'Trung cấp',
              b1Count,
              DgnlHighlightPalette.tokenB1.badgeDark,
            ),
          if (b2Count > 0)
            _buildCefrMenuItem(
              'B2',
              'Trung cao',
              b2Count,
              DgnlHighlightPalette.tokenB2.badgeDark,
            ),
          if (c1Count > 0)
            _buildCefrMenuItem(
              'C1',
              'Cao cấp',
              c1Count,
              DgnlHighlightPalette.tokenC1.badgeDark,
            ),
          if (c2Count > 0)
            _buildCefrMenuItem(
              'C2',
              'Thành thạo',
              c2Count,
              DgnlHighlightPalette.tokenC2.badgeDark,
            ),
          if (unknownCount > 0) ...[
            const PopupMenuDivider(height: 6),
            _buildCefrMenuItem(
              'unknown',
              'Chưa định danh (Proper/Rare)',
              unknownCount,
              DgnlHighlightPalette.tokenUnknown.badgeDark,
            ),
          ],
          if (isCefrActive) ...[
            const PopupMenuDivider(height: 6),
            const PopupMenuItem<String>(
              value: 'clear',
              height: 28,
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_off_outlined,
                    size: 13,
                    color: Color(0xfff38ba8),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Bỏ lọc CEFR',
                    style: TextStyle(fontSize: 10.5, color: Color(0xfff38ba8)),
                  ),
                ],
              ),
            ),
          ],
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
          decoration: BoxDecoration(
            color: isCefrActive
                ? activeColor.withValues(alpha: 0.3)
                : activeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isCefrActive
                  ? activeColor
                  : activeColor.withValues(alpha: 0.6),
              width: isCefrActive ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3.5),
              Text(
                displayLabel,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 10,
                  fontWeight: isCefrActive ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 1),
              Icon(Icons.arrow_drop_down, size: 13, color: activeColor),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildCefrMenuItem(
    String level,
    String levelName,
    int count,
    Color color,
  ) {
    final isSelected = _activeCategoryFilter == level;
    return PopupMenuItem<String>(
      value: level,
      height: 30,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            level,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '· $levelName ($count)',
            style: const TextStyle(fontSize: 10.5, color: Color(0xffcdd6f4)),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check, size: 14, color: color),
          ],
        ],
      ),
    );
  }
}
