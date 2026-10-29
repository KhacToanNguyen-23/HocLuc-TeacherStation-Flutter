import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:teaching_companion/features/studio_board/domain/models/board_sticker.dart';
import 'board_sticker_floating_bar.dart';

class DashedRectPainter extends CustomPainter {
  const DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashGap = 4.0,
    this.borderRadius = 0.0,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashWidth, metric.length - distance);
        final extractPath = metric.extractPath(distance, distance + len);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashWidth != oldDelegate.dashWidth ||
      dashGap != oldDelegate.dashGap ||
      borderRadius != oldDelegate.borderRadius;
}

class BoardStickerCard extends StatelessWidget {
  const BoardStickerCard({
    super.key,
    required this.sticker,
    required this.onDelete,
    required this.onUpdateRect,
    this.onUpdateRotation,
    this.onEdit,
    this.onDuplicate,
    this.onToggleRevolve,
    this.onSelect,
    this.onDeselect,
    this.isSelected = true,
    this.showFloatingBar = false,
    this.parentSize,
  });

  final BoardSticker sticker;
  final VoidCallback onDelete;
  final ValueChanged<Rect> onUpdateRect;
  final ValueChanged<double>? onUpdateRotation;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleRevolve;
  final VoidCallback? onSelect;
  final VoidCallback? onDeselect;
  final bool isSelected;
  final bool showFloatingBar;
  final Size? parentSize;

  Widget _buildCanvaHandle({
    required Offset offset,
    required GestureDragUpdateCallback onPanUpdate,
    required MouseCursor cursor,
    bool isCorner = true,
  }) {
    final visualSize = isCorner ? 9.0 : 7.0;
    const hitSize = 16.0;
    return Positioned(
      left: offset.dx - hitSize / 2,
      top: offset.dy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onPanUpdate,
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Container(
              width: visualSize,
              height: visualSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.0),
                border: Border.all(color: const Color(0xFF8B1D24), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSvgCard = sticker.svgContent != null && sticker.svgContent!.isNotEmpty;

    // Deselected State: Pure transparent vector graphics on chalkboard
    if (!isSelected) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final boxH = constraints.maxHeight.isFinite ? constraints.maxHeight : null;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelect,
            child: Transform.rotate(
              angle: sticker.rotation,
              child: Container(
                color: Colors.transparent,
                child: _buildContent(availableHeight: boxH),
              ),
            ),
          );
        },
      );
    }

    // Selected State: Canva Transform Controls
    final isCloseToTop = (parentSize != null) &&
        (sticker.normalizedRect.top * parentSize!.height < 48);

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;
        // Border is 1.5 top + 1.5 bottom = 3.0. Inner content height must not exceed boxH - 3.5 to prevent RenderFlex overflow!
        final innerContentH = (boxH.isFinite && boxH > 40)
            ? (boxH - 3.5)
            : null;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // LAYER 1: Rotated Content & 8 Canva Handles (Transform.rotate)
            Positioned.fill(
              child: Transform.rotate(
                angle: sticker.rotation,
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // LAYER 1: Card Body & Move/Drag GestureDetector
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: _handleMove,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSvgCard ? Colors.transparent : const Color(0xf2181825),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: CustomPaint(
                              painter: const DashedRectPainter(
                                color: Color(0xFF8B1D24),
                                strokeWidth: 1.5,
                                dashWidth: 6.0,
                                dashGap: 4.0,
                                borderRadius: 4.0,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Optional header for text/token cards only
                                      if (!isSvgCard)
                                      Container(
                                        padding: const EdgeInsets.only(left: 10, right: 14, top: 6, bottom: 4),
                                        decoration: const BoxDecoration(
                                          color: Color(0x22ffffff),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(5),
                                            topRight: Radius.circular(5),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.push_pin, size: 12, color: Color(0xFFFDE047)),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                sticker.title ?? 'Ghi chú bài học',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (onEdit != null) ...[
                                              InkWell(
                                                onTap: onEdit,
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  child: Text('Sửa', style: TextStyle(fontSize: 10, color: Colors.white)),
                                                ),
                                              ),
                                            ],
                                            InkWell(
                                              onTap: onDelete,
                                              child: const Icon(Icons.close, size: 13, color: Color(0xFFFB7185)),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Content (SVG / Tokens / Image)
                                    _buildContent(
                                      availableHeight: isSvgCard
                                          ? innerContentH
                                          : (innerContentH != null ? innerContentH - 36 : null),
                                    ),
                                  ],
                                ),

                                // Translucent Formula / Title Badge on Selected Object
                                if (sticker.title != null)
                                  Positioned(
                                    left: 6,
                                    bottom: 6,
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: math.max(100.0, boxW - 12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sticker.title!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ),
                    ),

                    // LAYER 2: 8 Canva Transform Handles with 28px Hit Area & Mouse Cursors
                    if (boxW > 20 && boxH > 20) ...[
                      // 4 Corner Handles (Proportional scale)
                      _buildCanvaHandle(
                        offset: Offset.zero,
                        isCorner: true,
                        cursor: SystemMouseCursors.resizeUpLeftDownRight,
                        onPanUpdate: (d) => _handleCornerResize(d, isTop: true, isLeft: true),
                      ),
                      _buildCanvaHandle(
                        offset: Offset(boxW, 0),
                        isCorner: true,
                        cursor: SystemMouseCursors.resizeUpRightDownLeft,
                        onPanUpdate: (d) => _handleCornerResize(d, isTop: true, isLeft: false),
                      ),
                      _buildCanvaHandle(
                        offset: Offset(0, boxH),
                        isCorner: true,
                        cursor: SystemMouseCursors.resizeUpRightDownLeft,
                        onPanUpdate: (d) => _handleCornerResize(d, isTop: false, isLeft: true),
                      ),
                      _buildCanvaHandle(
                        offset: Offset(boxW, boxH),
                        isCorner: true,
                        cursor: SystemMouseCursors.resizeUpLeftDownRight,
                        onPanUpdate: (d) => _handleCornerResize(d, isTop: false, isLeft: false),
                      ),

                      // 4 Edge Center Handles (1-Axis stretch)
                      _buildCanvaHandle(
                        offset: Offset(boxW / 2, 0),
                        isCorner: false,
                        cursor: SystemMouseCursors.resizeUpDown,
                        onPanUpdate: (d) => _handleEdgeResize(d, isVertical: true, isTop: true),
                      ),
                      _buildCanvaHandle(
                        offset: Offset(boxW / 2, boxH),
                        isCorner: false,
                        cursor: SystemMouseCursors.resizeUpDown,
                        onPanUpdate: (d) => _handleEdgeResize(d, isVertical: true, isTop: false),
                      ),
                      _buildCanvaHandle(
                        offset: Offset(0, boxH / 2),
                        isCorner: false,
                        cursor: SystemMouseCursors.resizeLeftRight,
                        onPanUpdate: (d) => _handleEdgeResize(d, isVertical: false, isLeft: true),
                      ),
                      _buildCanvaHandle(
                        offset: Offset(boxW, boxH / 2),
                        isCorner: false,
                        cursor: SystemMouseCursors.resizeLeftRight,
                        onPanUpdate: (d) => _handleEdgeResize(d, isVertical: false, isLeft: false),
                      ),
                    ],

                    // Canva Rotation Stem & Handle (Top-Center)
                    Positioned(
                      top: -28,
                      left: (boxW - 28) / 2,
                      width: 28,
                      height: 28,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) {
                            if (onUpdateRotation == null || parentSize == null) return;
                            final curAngle = sticker.rotation;
                            final radius = ((parentSize!.height * sticker.normalizedRect.height) / 2) + 20;
                            final tangent = details.delta.dx * math.cos(curAngle) +
                                details.delta.dy * math.sin(curAngle);
                            final dAngle = tangent / (radius > 10 ? radius : 50);
                            var nextAngle = (curAngle + dAngle) % (2 * math.pi);
                            if (!nextAngle.isFinite) return;
                            for (final snap in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2, 2 * math.pi]) {
                              if ((nextAngle - snap).abs() < 0.05) {
                                nextAngle = snap % (2 * math.pi);
                                break;
                              }
                            }
                            onUpdateRotation!(nextAngle);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF8B1D24), width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.rotate_right_rounded,
                                    size: 11,
                                    color: Color(0xFF8B1D24),
                                  ),
                                ),
                              ),
                              Container(
                                width: 1.5,
                                height: 10,
                                color: const Color(0xFF8B1D24),
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

            // LAYER 2: Canva Floating Action Bar (If showFloatingBar is enabled, for tests or standalone mode)
            if (showFloatingBar)
              Positioned(
                top: isCloseToTop ? null : -46,
                bottom: isCloseToTop ? -46 : null,
                left: (boxW - 360.0) / 2,
                width: 360.0,
                height: 38.0,
                child: BoardStickerFloatingBar(
                  sticker: sticker,
                  onDelete: onDelete,
                  onEdit: onEdit,
                  onDuplicate: onDuplicate,
                  onToggleRevolve: onToggleRevolve,
                  onDeselect: onDeselect,
                  onSelect: onSelect,
                ),
              ),
          ],
        );
      },
    );
  }

  void _handleMove(DragUpdateDetails details) {
    if (parentSize == null || parentSize!.width <= 0 || parentSize!.height <= 0) return;
    final dxNorm = details.delta.dx / parentSize!.width;
    final dyNorm = details.delta.dy / parentSize!.height;
    if (!dxNorm.isFinite || !dyNorm.isFinite) return;
    final rect = sticker.normalizedRect;
    final maxLeft = (1.0 - rect.width).clamp(0.0, 1.0);
    final maxTop = (1.0 - rect.height).clamp(0.0, 1.0);
    final nextLeft = (rect.left + dxNorm).clamp(0.0, maxLeft);
    final nextTop = (rect.top + dyNorm).clamp(0.0, maxTop);
    if (!nextLeft.isFinite || !nextTop.isFinite) return;
    onUpdateRect(Rect.fromLTWH(nextLeft, nextTop, rect.width, rect.height));
  }

  void _handleCornerResize(
    DragUpdateDetails details, {
    required bool isTop,
    required bool isLeft,
  }) {
    if (parentSize == null || parentSize!.width <= 0 || parentSize!.height <= 0) return;
    final r = sticker.normalizedRect;
    if (r.height <= 0.001 || r.width <= 0.001) return;
    final aspect = r.width / r.height;
    if (!aspect.isFinite || aspect <= 0) return;

    // Project mouse delta into rotated local coordinate frame
    final cosTheta = math.cos(-sticker.rotation);
    final sinTheta = math.sin(-sticker.rotation);
    final normDx = details.delta.dx / parentSize!.width;
    final normDy = details.delta.dy / parentSize!.height;
    final localDx = normDx * cosTheta - normDy * sinTheta;
    final localDy = normDx * sinTheta + normDy * cosTheta;

    final dirX = isLeft ? -1.0 : 1.0;
    final dirY = isTop ? -1.0 : 1.0;

    // Proportional scale factor locking aspect ratio
    final deltaScale = (localDx * dirX + localDy * dirY * aspect) / 2.0;
    final minW = (180.0 / parentSize!.width).clamp(0.06, 0.5);
    final minH = (120.0 / parentSize!.height).clamp(0.05, 0.5);
    double newW = (r.width + deltaScale).clamp(minW, 0.95);
    double newH = (newW / aspect).clamp(minH, 0.95);
    newW = newH * aspect;

    double newLeft = r.left;
    double newTop = r.top;

    if (isLeft) {
      newLeft = r.right - newW;
      if (newLeft < 0.0) {
        newLeft = 0.0;
        newW = r.right;
        newH = newW / aspect;
      }
    } else {
      if (newLeft + newW > 1.0) {
        newW = 1.0 - newLeft;
        newH = newW / aspect;
      }
    }

    if (isTop) {
      newTop = r.bottom - newH;
      if (newTop < 0.0) {
        newTop = 0.0;
        newH = r.bottom;
        newW = newH * aspect;
        if (isLeft) {
          newLeft = r.right - newW;
        }
      }
    } else {
      if (newTop + newH > 1.0) {
        newH = 1.0 - newTop;
        newW = newH * aspect;
        if (isLeft) {
          newLeft = r.right - newW;
        }
      }
    }

    if (!newLeft.isFinite || !newTop.isFinite || !newW.isFinite || !newH.isFinite) return;

    onUpdateRect(
      Rect.fromLTWH(
        newLeft.clamp(0.0, 0.95),
        newTop.clamp(0.0, 0.95),
        newW.clamp(minW, 0.95),
        newH.clamp(minH, 0.95),
      ),
    );
  }

  void _handleEdgeResize(
    DragUpdateDetails details, {
    required bool isVertical,
    bool? isTop,
    bool? isLeft,
  }) {
    if (parentSize == null || parentSize!.width <= 0 || parentSize!.height <= 0) return;
    final r = sticker.normalizedRect;
    final minW = (180.0 / parentSize!.width).clamp(0.06, 0.5);
    final minH = (120.0 / parentSize!.height).clamp(0.05, 0.5);

    final cosTheta = math.cos(-sticker.rotation);
    final sinTheta = math.sin(-sticker.rotation);
    final normDx = details.delta.dx / parentSize!.width;
    final normDy = details.delta.dy / parentSize!.height;

    if (isVertical) {
      final localDy = normDx * sinTheta + normDy * cosTheta;
      if (isTop == true) {
        final nextTop = (r.top + localDy).clamp(0.0, r.bottom - minH);
        final nextH = r.bottom - nextTop;
        if (nextTop.isFinite && nextH.isFinite) {
          onUpdateRect(Rect.fromLTWH(r.left, nextTop, r.width, nextH));
        }
      } else {
        final nextH = (r.height + localDy).clamp(minH, 1.0 - r.top);
        if (nextH.isFinite) {
          onUpdateRect(Rect.fromLTWH(r.left, r.top, r.width, nextH));
        }
      }
    } else {
      final localDx = normDx * cosTheta - normDy * sinTheta;
      if (isLeft == true) {
        final nextLeft = (r.left + localDx).clamp(0.0, r.right - minW);
        final nextW = r.right - nextLeft;
        if (nextLeft.isFinite && nextW.isFinite) {
          onUpdateRect(Rect.fromLTWH(nextLeft, r.top, nextW, r.height));
        }
      } else {
        final nextW = (r.width + localDx).clamp(minW, 1.0 - r.left);
        if (nextW.isFinite) {
          onUpdateRect(Rect.fromLTWH(r.left, r.top, nextW, r.height));
        }
      }
    }
  }

  Widget _buildContent({double? availableHeight}) {
    if (sticker.svgContent != null && sticker.svgContent!.isNotEmpty) {
      return RepaintBoundary(
        child: Container(
          height: availableHeight,
          padding: const EdgeInsets.all(2),
          alignment: Alignment.center,
          child: SvgPicture.string(
            sticker.svgContent!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (sticker.imageBase64 != null && sticker.imageBase64!.isNotEmpty) {
      final rawBase64 = sticker.imageBase64!;
      final isSvg = rawBase64.contains('image/svg+xml');
      final base64Data =
          rawBase64.contains(',') ? rawBase64.split(',').last : rawBase64;
      try {
        final bytes = base64Decode(base64Data);
        return Container(
          height: availableHeight,
          padding: const EdgeInsets.all(4),
          alignment: Alignment.center,
          child: isSvg
              ? SvgPicture.memory(bytes, fit: BoxFit.contain)
              : Image.memory(bytes, fit: BoxFit.contain),
        );
      } catch (_) {
        // Fallback to text if decoding fails
      }
    }

    if (sticker.tokens.isNotEmpty) {
      return _buildTokensContent();
    }

    if (sticker.rawText.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          sticker.rawText,
          style: const TextStyle(
            color: Color(0xffcdd6f4),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTokensContent() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: sticker.tokens.map((token) {
              final text = token['text'] as String? ?? '';
              const tokenColor = Color(0x88d4e8a6);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: tokenColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: tokenColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
