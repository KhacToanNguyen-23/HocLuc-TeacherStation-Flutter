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

    Color categoryColor = const Color(0xff89b4fa);
    if (activeSpan.category == 'collocation') {
      categoryColor = const Color(0xff86efac);
    } else if (activeSpan.level == 'C1' || activeSpan.level == 'C2') {
      categoryColor = const Color(0xffcba6f7);
    } else if (activeSpan.level == 'B2') {
      categoryColor = const Color(0xfff9e2af);
    }

    return Positioned(
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
                    color: categoryColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.6),
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
                InkWell(
                  onTap: () =>
                      PdfAnnotationExporter.applyHighlightDirectlyToPdf(
                        context,
                        studio,
                      ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x2889b4fa),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x6689b4fa)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.draw_rounded,
                          size: 11,
                          color: Color(0xff89b4fa),
                        ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 18,
                  ),
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
                  final options =
                      (q['options'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (
                              int optIdx = 0;
                              optIdx < options.length;
                              optIdx++
                            ) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: options[optIdx] == answer
                                      ? const Color(0x3386efac)
                                      : const Color(0x18ffffff),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: options[optIdx] == answer
                                        ? const Color(0x8886efac)
                                        : const Color(0x28ffffff),
                                  ),
                                ),
                                child: Text(
                                  '${String.fromCharCode(65 + optIdx)}. ${options[optIdx]}',
                                  style: TextStyle(
                                    color: options[optIdx] == answer
                                        ? const Color(0xff86efac)
                                        : const Color(0xffcdd6f4),
                                    fontSize: 11.5,
                                    fontWeight: options[optIdx] == answer
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (explanation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '• $explanation',
                            style: const TextStyle(
                              color: Color(0xff94a3b8),
                              fontSize: 11,
                            ),
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


