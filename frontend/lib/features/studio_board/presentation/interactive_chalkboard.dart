import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'board_sticker_card.dart';
import 'board_sticker_floating_bar.dart';
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
        if (event.logicalKey == LogicalKeyboardKey.escape && event is KeyDownEvent) {
          if (widget.studio.selectedStickerId != null) {
            widget.studio.selectSticker(null);
            return KeyEventResult.handled;
          }
        }
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
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => widget.studio.selectSticker(null),
                    child: const CustomPaint(painter: GridPainter()),
                  ),
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
                          final selectedId = widget.studio.selectedStickerId;
                          final selSticker = selectedId != null
                              ? stickers.where((s) => s.id == selectedId).firstOrNull
                              : null;
                          return Stack(
                            fit: StackFit.expand,
                            clipBehavior: Clip.none,
                            children: [
                              if (widget.studio.selectedStickerId != null)
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => widget.studio.selectSticker(null),
                                  ),
                                ),
                              for (final s in stickers)
                                Positioned(
                                  left: s.normalizedRect.left * size.width,
                                  top: s.normalizedRect.top * size.height,
                                  width: (s.normalizedRect.width * size.width)
                                      .clamp(
                                        200.0,
                                        size.width > 200 ? size.width : 200.0,
                                      ),
                                  height: (s.normalizedRect.height * size.height)
                                      .clamp(
                                        120.0,
                                        size.height > 120 ? size.height : 120.0,
                                      ),
                                  child: BoardStickerCard(
                                    sticker: s,
                                    isSelected: widget.studio.selectedStickerId == s.id,
                                    showFloatingBar: false,
                                    onSelect: () => widget.studio.selectSticker(s.id),
                                    onDeselect: () => widget.studio.selectSticker(null),
                                    parentSize: size,
                                    onDelete: () =>
                                        widget.studio.removeSticker(s.id),
                                    onUpdateRect: (r) => widget.studio
                                        .updateStickerRect(s.id, r),
                                    onUpdateRotation: (rot) => widget.studio
                                        .updateStickerRotation(s.id, rot),
                                    onDuplicate: () => widget.studio
                                        .duplicateSticker(s.id),
                                    onEdit: () => _handleEdit(s),
                                  ),
                                ),
                              // Canva Selection Overlay Layer: Top-most Floating Action Bar
                              if (selSticker != null)
                                Positioned(
                                  left: _calculateBarLeft(selSticker, size),
                                  top: _calculateBarTop(selSticker, size),
                                  width: 540.0,
                                  height: 38.0,
                                  child: BoardStickerFloatingBar(
                                    sticker: selSticker,
                                    onDeselect: () => widget.studio.selectSticker(null),
                                    onToggleRevolve: () => _handleRevolveOrEdit(selSticker),
                                    onEdit: () => _handleEdit(selSticker),
                                    onDuplicate: () => widget.studio.duplicateSticker(selSticker.id),
                                    onDelete: () => widget.studio.removeSticker(selSticker.id),
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

  double _calculateBarLeft(BoardSticker s, Size size) {
    const barWidth = 540.0;
    final stickerLeft = s.normalizedRect.left * size.width;
    final stickerWidth = (s.normalizedRect.width * size.width)
        .clamp(200.0, size.width > 200 ? size.width : 200.0);
    final centerDx = stickerLeft + (stickerWidth - barWidth) / 2.0;
    return centerDx.clamp(
      12.0,
      size.width > barWidth + 24.0 ? (size.width - barWidth - 12.0) : 12.0,
    );
  }

  double _calculateBarTop(BoardSticker s, Size size) {
    final stickerTop = s.normalizedRect.top * size.height;
    final stickerHeight = (s.normalizedRect.height * size.height)
        .clamp(120.0, size.height > 120 ? size.height : 120.0);
    return (stickerTop < 54.0)
        ? (stickerTop + stickerHeight + 12.0)
        : (stickerTop - 48.0);
  }

  void _handleEdit(BoardSticker s) {
    InstalledPlugin? plugin = PluginManager.instance.getPlugin(s.type);
    if (plugin == null) {
      final all = [
        ...PluginManager.instance.installedPlugins,
        ...PluginManager.instance.availablePlugins,
      ].whereType<InstalledPlugin>().toList();

      plugin = all.where((p) =>
        p.id == s.type ||
        p.manifest.id == s.type ||
        s.type.contains(p.id) ||
        p.id.contains(s.type) ||
        s.type.contains(p.manifest.id) ||
        p.manifest.id.contains(s.type) ||
        (s.svgContent != null && p.manifest.id.contains('math'))
      ).firstOrNull ?? all.firstOrNull;
    }
    if (plugin != null) {
      widget.studio.openPlugin(plugin, editingSticker: s);
    }
  }

  void _handleRevolveOrEdit(BoardSticker s) {
    _handleEdit(s);
  }
}
