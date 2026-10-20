import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'board_sticker_card.dart';
import 'grid_painter.dart';
import 'stroke_canvas.dart';
import 'smart_chalk_overlay.dart';

class InteractiveChalkboard extends StatefulWidget {
  const InteractiveChalkboard({
    super.key,
    required this.studio,
    this.interactive = true,
  });

  final StudioState studio;
  final bool interactive;

  @override
  State<InteractiveChalkboard> createState() => _InteractiveChalkboardState();
}

class _InteractiveChalkboardState extends State<InteractiveChalkboard> {
  final TransformationController _transformController =
      TransformationController();
  bool _isSpacePressed = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final nextScale = (scale * factor).clamp(0.5, 3.0);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);
    final sceneCenter = _transformController.toScene(center);
    _transformController.value = Matrix4.identity()
      ..setEntry(0, 0, nextScale)
      ..setEntry(1, 1, nextScale)
      ..setEntry(0, 3, center.dx - sceneCenter.dx * nextScale)
      ..setEntry(1, 3, center.dy - sceneCenter.dy * nextScale);
  }

  @override
  Widget build(BuildContext context) {
    final isPanMode = _isSpacePressed || widget.studio.tool == 'pan';

    return Focus(
      autofocus: true,
      onFocusChange: (focused) {
        if (!focused && _isSpacePressed) {
          setState(() => _isSpacePressed = false);
          widget.studio.setSpacePressed(false);
        }
      },
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.space) {
          final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
          if (_isSpacePressed != isDown) {
            setState(() => _isSpacePressed = isDown);
            widget.studio.setSpacePressed(isDown);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 3.0,
            panEnabled: isPanMode,
            scaleEnabled: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: GridPainter()),
                ),
                Positioned.fill(
                  child: StrokeCanvas(
                    studio: widget.studio,
                    interactive: widget.interactive && !isPanMode,
                  ),
                ),
                Positioned.fill(
                  child: SmartChalkOverlay(
                    studio: widget.studio,
                    onDelete: (id) => widget.studio.removeChalkAnnotation(id),
                  ),
                ),
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: widget.studio,
                    builder: (context, _) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          final stickers = widget.studio.currentStickers;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              for (final s in stickers)
                                Positioned(
                                  left: s.normalizedRect.left * size.width,
                                  top: s.normalizedRect.top * size.height,
                                  width: (s.normalizedRect.width * size.width)
                                      .clamp(
                                        200.0,
                                        size.width > 200 ? size.width : 200.0,
                                      ),
                                  child: BoardStickerCard(
                                    sticker: s,
                                    parentSize: size,
                                    onDelete: () =>
                                        widget.studio.removeSticker(s.id),
                                    onUpdateRect: (r) => widget.studio
                                        .updateStickerRect(s.id, r),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.interactive)
            Positioned(
              right: 16,
              top: 16,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: ValueListenableBuilder<Matrix4>(
                  valueListenable: _transformController,
                  builder: (context, matrix, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Thu nhỏ bảng',
                        onPressed: () => _zoom(1 / 1.2),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      TextButton(
                        onPressed: () =>
                            _transformController.value = Matrix4.identity(),
                        child: Text(
                          '${(matrix.getMaxScaleOnAxis() * 100).round()}%',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Phóng to bảng',
                        onPressed: () => _zoom(1.2),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
