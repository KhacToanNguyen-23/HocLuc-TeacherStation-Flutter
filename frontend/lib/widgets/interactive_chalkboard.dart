import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/studio_state.dart';
import 'grid_painter.dart';
import 'stroke_canvas.dart';

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
  final ValueNotifier<double> _scaleNotifier = ValueNotifier(1.0);
  bool _isSpacePressed = false;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((_scaleNotifier.value - scale).abs() > 0.005) {
      _scaleNotifier.value = scale;
    }
  }

  void _zoomBy(double factor) {
    final current = _transformController.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.5, 3.0);
    final ratio = target / current;
    final matrix = _transformController.value.clone()
      ..scaleByDouble(ratio, ratio, 1.0, 1.0);
    _transformController.value = matrix;
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    _scaleNotifier.value = 1.0;
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _scaleNotifier.dispose();
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
              ],
            ),
          ),
          // Mini Zoom Bar overlay at bottom-right of board
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildMiniZoomBar(isPanMode),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniZoomBar(bool isPanMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xee1e2d27),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33ffffff)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hand tool toggle
          Tooltip(
            message: isPanMode
                ? 'Đang bật Pan (Kéo bảng)'
                : 'Bật kéo bảng (Pan Tool / Giữ Space)',
            child: InkWell(
              onTap: () {
                widget.studio.change(() {
                  widget.studio.tool = widget.studio.tool == 'pan'
                      ? 'pen'
                      : 'pan';
                }, persist: false);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isPanMode
                      ? const Color(0x3344ff88)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pan_tool_outlined,
                  size: 16,
                  color: isPanMode ? const Color(0xff77ffaa) : Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Zoom out
          InkWell(
            onTap: () => _zoomBy(0.85),
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.remove, size: 16, color: Colors.white70),
            ),
          ),
          // % Zoom indicator (tap to reset 100%)
          ValueListenableBuilder<double>(
            valueListenable: _scaleNotifier,
            builder: (context, scale, _) {
              final pct = (scale * 100).round();
              return Tooltip(
                message: 'Bấm để đặt lại 100%',
                child: InkWell(
                  onTap: _resetZoom,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Zoom in
          InkWell(
            onTap: () => _zoomBy(1.15),
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.add, size: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
