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

  @override
  Widget build(BuildContext context) {
    final isPanMode = _isSpacePressed || widget.studio.tool == 'pan';

    return Focus(
      autofocus: true,
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
        ],
      ),
    );
  }
}

