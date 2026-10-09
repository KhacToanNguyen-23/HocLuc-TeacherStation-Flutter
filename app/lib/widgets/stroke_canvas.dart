import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../models/studio_state.dart';

class StrokeCanvas extends StatefulWidget {
  const StrokeCanvas({
    super.key,
    required this.studio,
    this.targetStrokes,
    this.interactive = true,
  });

  final StudioState studio;
  final List<BoardStroke>? targetStrokes;
  final bool interactive;

  @override
  State<StrokeCanvas> createState() => _StrokeCanvasState();
}

class _StrokeCanvasState extends State<StrokeCanvas> {
  Offset? _hoverOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);

        Offset normalized(Offset p) => Offset(
          (p.dx / size.width).clamp(0.0, 1.0),
          (p.dy / size.height).clamp(0.0, 1.0),
        );

        return MouseRegion(
          cursor: widget.studio.tool == 'laser'
              ? SystemMouseCursors.none
              : widget.studio.tool == 'erase'
              ? SystemMouseCursors.grab
              : SystemMouseCursors.precise,
          onHover: (e) {
            final norm = normalized(e.localPosition);
            setState(() => _hoverOffset = norm);
            if (widget.studio.tool == 'laser') {
              widget.studio.setLaserOffset(norm);
            }
          },
          onExit: (_) {
            setState(() => _hoverOffset = null);
            if (widget.studio.tool == 'laser') {
              widget.studio.setLaserOffset(null);
            }
          },
          child: GestureDetector(
            onPanStart: widget.interactive
                ? (e) {
                    final norm = normalized(e.localPosition);
                    if (widget.studio.tool == 'laser') {
                      widget.studio.setLaserOffset(norm);
                    } else {
                      widget.studio.startStroke(
                        norm,
                        target: widget.targetStrokes,
                      );
                    }
                  }
                : null,
            onPanUpdate: widget.interactive
                ? (e) {
                    final norm = normalized(e.localPosition);
                    if (widget.studio.tool == 'laser') {
                      widget.studio.setLaserOffset(norm);
                    } else {
                      widget.studio.extendStroke(
                        norm,
                        target: widget.targetStrokes,
                      );
                    }
                  }
                : null,
            onPanEnd: widget.interactive
                ? (_) {
                    if (widget.studio.tool != 'laser') {
                      widget.studio.finishStroke(target: widget.targetStrokes);
                    }
                  }
                : null,
            onTapDown: widget.interactive
                ? (e) {
                    final norm = normalized(e.localPosition);
                    if (widget.studio.tool == 'laser') {
                      widget.studio.setLaserOffset(norm);
                    } else {
                      widget.studio.startStroke(
                        norm,
                        target: widget.targetStrokes,
                      );
                      widget.studio.finishStroke(target: widget.targetStrokes);
                    }
                  }
                : null,
            child: CustomPaint(
              size: size,
              painter: SmoothStrokePainter(
                strokes: widget.targetStrokes ?? widget.studio.strokes,
                laserOffset: widget.studio.tool == 'laser'
                    ? widget.studio.laserOffset ?? _hoverOffset
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class SmoothStrokePainter extends CustomPainter {
  SmoothStrokePainter({required this.strokes, this.laserOffset});

  final List<BoardStroke> strokes;
  final Offset? laserOffset;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final isHighlight = stroke.width > 6;
      final paint = Paint()
        ..color = isHighlight
            ? stroke.color.withValues(alpha: 0.35)
            : stroke.color
        ..style = PaintingStyle.fill;

      if (stroke.points.length == 1) {
        final p = Offset(
          stroke.points.first.dx * size.width,
          stroke.points.first.dy * size.height,
        );
        canvas.drawCircle(p, stroke.width / 2, paint);
        continue;
      }

      final pixelVectors = stroke.points
          .map((p) => PointVector(p.dx * size.width, p.dy * size.height))
          .toList();

      final outline = getStroke(
        pixelVectors,
        options: StrokeOptions(
          size: stroke.width,
          thinning: isHighlight ? 0.0 : 0.4,
          smoothing: 0.65,
          streamline: 0.5,
          isComplete: true,
        ),
      );

      if (outline.isEmpty) continue;

      final path = Path()..moveTo(outline.first.dx, outline.first.dy);
      for (int i = 1; i < outline.length; i++) {
        path.lineTo(outline[i].dx, outline[i].dy);
      }
      path.close();

      canvas.drawPath(path, paint);
    }

    if (laserOffset != null) {
      final center = Offset(
        laserOffset!.dx * size.width,
        laserOffset!.dy * size.height,
      );

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff44ff88).withValues(alpha: 0.8),
            const Color(0xff00ff66).withValues(alpha: 0.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 18));

      canvas.drawCircle(center, 18, glowPaint);

      final corePaint = Paint()
        ..color = const Color(0xff77ffaa)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 5.5, corePaint);

      final centerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 2.5, centerDot);
    }
  }

  @override
  bool shouldRepaint(covariant SmoothStrokePainter oldDelegate) => true;
}
