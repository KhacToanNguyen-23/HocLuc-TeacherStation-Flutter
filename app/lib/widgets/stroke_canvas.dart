import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../models/studio_state.dart';

class LaserPoint {
  LaserPoint(this.point, this.createdAt);
  final Offset point;
  final DateTime createdAt;
}

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
  final List<Offset> _activePoints = [];
  final ValueNotifier<List<Offset>?> _activeStrokeNotifier = ValueNotifier(
    null,
  );

  final List<LaserPoint> _laserPoints = [];
  final ValueNotifier<List<LaserPoint>> _laserTrailNotifier = ValueNotifier([]);
  Timer? _laserTimer;
  Offset? _laserHoverOffset;

  void _addLaserPoint(Offset norm) {
    final now = DateTime.now();
    _laserPoints.add(LaserPoint(norm, now));
    _laserTrailNotifier.value = List.of(_laserPoints);
    _startLaserTimer();
  }

  void _startLaserTimer() {
    _laserTimer ??= Timer.periodic(const Duration(milliseconds: 30), (_) {
      final now = DateTime.now();
      _laserPoints.removeWhere(
        (p) => now.difference(p.createdAt).inMilliseconds > 1500,
      );
      _laserTrailNotifier.value = List.of(_laserPoints);
      if (_laserPoints.isEmpty) {
        _laserTimer?.cancel();
        _laserTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _laserTimer?.cancel();
    _activeStrokeNotifier.dispose();
    _laserTrailNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);

        Offset normalized(Offset p) => Offset(
          (p.dx / size.width).clamp(0.0, 1.0),
          (p.dy / size.height).clamp(0.0, 1.0),
        );

        final strokes = widget.targetStrokes ?? widget.studio.strokes;

        return MouseRegion(
          cursor: widget.studio.tool == 'laser'
              ? SystemMouseCursors.none
              : widget.studio.tool == 'erase'
              ? SystemMouseCursors.grab
              : SystemMouseCursors.precise,
          onHover: (e) {
            final norm = normalized(e.localPosition);
            if (widget.studio.tool == 'laser') {
              _laserHoverOffset = norm;
              widget.studio.setLaserOffset(norm);
            }
          },
          onExit: (_) {
            if (widget.studio.tool == 'laser') {
              _laserHoverOffset = null;
              widget.studio.setLaserOffset(null);
            }
          },
          child: GestureDetector(
            onPanStart: widget.interactive
                ? (e) {
                    final norm = normalized(e.localPosition);
                    if (widget.studio.tool == 'laser') {
                      _addLaserPoint(norm);
                      widget.studio.setLaserOffset(norm);
                    } else if (widget.studio.tool == 'erase') {
                      widget.studio.erase(norm, target: widget.targetStrokes);
                    } else {
                      _activePoints.clear();
                      _activePoints.add(norm);
                      _activeStrokeNotifier.value = List.of(_activePoints);
                    }
                  }
                : null,
            onPanUpdate: widget.interactive
                ? (e) {
                    final norm = normalized(e.localPosition);
                    if (widget.studio.tool == 'laser') {
                      _addLaserPoint(norm);
                      widget.studio.setLaserOffset(norm);
                    } else if (widget.studio.tool == 'erase') {
                      widget.studio.erase(norm, target: widget.targetStrokes);
                    } else {
                      _activePoints.add(norm);
                      _activeStrokeNotifier.value = List.of(_activePoints);
                    }
                  }
                : null,
            onPanEnd: widget.interactive
                ? (_) {
                    if (widget.studio.tool == 'laser' ||
                        widget.studio.tool == 'erase') {
                      return;
                    }
                    if (_activePoints.isNotEmpty) {
                      final isHighlighter = widget.studio.tool == 'highlight';
                      final width = isHighlighter
                          ? widget.studio.highlighterWidth
                          : widget.studio.strokeWidth;
                      final stroke = BoardStroke(
                        widget.studio.ink,
                        width,
                        List.of(_activePoints),
                      );
                      stroke.getPath(size); // Precompute and cache path
                      widget.studio.addStroke(
                        stroke,
                        target: widget.targetStrokes,
                      );
                      _activePoints.clear();
                      _activeStrokeNotifier.value = null;
                    }
                  }
                : null,
            onTapDown: widget.interactive
                ? (e) {
                    final norm = normalized(e.localPosition);
                    if (widget.studio.tool == 'laser') {
                      _addLaserPoint(norm);
                      widget.studio.setLaserOffset(norm);
                    } else if (widget.studio.tool == 'erase') {
                      widget.studio.erase(norm, target: widget.targetStrokes);
                    } else {
                      final isHighlighter = widget.studio.tool == 'highlight';
                      final width = isHighlighter
                          ? widget.studio.highlighterWidth
                          : widget.studio.strokeWidth;
                      final stroke = BoardStroke(widget.studio.ink, width, [
                        norm,
                      ]);
                      stroke.getPath(size);
                      widget.studio.addStroke(
                        stroke,
                        target: widget.targetStrokes,
                      );
                    }
                  }
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1: Committed Strokes (RepaintBoundary - static cached paths)
                RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: CommittedStrokesPainter(
                      strokes: strokes,
                      revision: widget.studio.revision,
                    ),
                  ),
                ),
                // Layer 2: Active Stroke (RepaintBoundary - isolated ValueNotifier)
                RepaintBoundary(
                  child: ValueListenableBuilder<List<Offset>?>(
                    valueListenable: _activeStrokeNotifier,
                    builder: (context, activePoints, _) {
                      if (activePoints == null || activePoints.isEmpty) {
                        return const SizedBox.expand();
                      }
                      final isHighlighter = widget.studio.tool == 'highlight';
                      return CustomPaint(
                        size: size,
                        painter: ActiveStrokePainter(
                          activePoints: activePoints,
                          color: isHighlighter
                              ? widget.studio.ink.withValues(alpha: 0.35)
                              : widget.studio.ink,
                          width: isHighlighter
                              ? widget.studio.highlighterWidth
                              : widget.studio.strokeWidth,
                          isHighlight: isHighlighter,
                        ),
                      );
                    },
                  ),
                ),
                // Layer 3: Laser Trail Overlay (Auto-fade after 1.5s)
                if (widget.studio.tool == 'laser')
                  RepaintBoundary(
                    child: ValueListenableBuilder<List<LaserPoint>>(
                      valueListenable: _laserTrailNotifier,
                      builder: (context, laserPoints, _) {
                        return CustomPaint(
                          size: size,
                          painter: LaserTrailPainter(
                            laserPoints: laserPoints,
                            laserOffset:
                                widget.studio.laserOffset ?? _laserHoverOffset,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Layer 1 Painter: Renders completed strokes from cached Path objects (Zero spline recalculation)
class CommittedStrokesPainter extends CustomPainter {
  CommittedStrokesPainter({required this.strokes, required this.revision});

  final List<BoardStroke> strokes;
  final int revision;

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

      final path = stroke.getPath(size);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CommittedStrokesPainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.strokes.length != strokes.length ||
        !identical(oldDelegate.strokes, strokes);
  }
}

/// Layer 2 Painter: Only renders the single active inking stroke on drag
class ActiveStrokePainter extends CustomPainter {
  ActiveStrokePainter({
    required this.activePoints,
    required this.color,
    required this.width,
    required this.isHighlight,
  });

  final List<Offset> activePoints;
  final Color color;
  final double width;
  final bool isHighlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (activePoints.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (activePoints.length == 1) {
      final p = Offset(
        activePoints.first.dx * size.width,
        activePoints.first.dy * size.height,
      );
      canvas.drawCircle(p, width / 2, paint);
      return;
    }

    final pixelVectors = activePoints
        .map((p) => PointVector(p.dx * size.width, p.dy * size.height))
        .toList();

    final outline = getStroke(
      pixelVectors,
      options: StrokeOptions(
        size: width,
        thinning: isHighlight ? 0.0 : 0.35,
        smoothing: 0.65,
        streamline: 0.5,
        isComplete: true,
      ),
    );

    if (outline.isEmpty) return;

    final path = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (int i = 1; i < outline.length; i++) {
      path.lineTo(outline[i].dx, outline[i].dy);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) => true;
}

/// Layer 3 Painter: Glowing Laser Pointer Trail with smooth 1.5s auto-fade
class LaserTrailPainter extends CustomPainter {
  LaserTrailPainter({required this.laserPoints, required this.laserOffset});

  final List<LaserPoint> laserPoints;
  final Offset? laserOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();

    if (laserPoints.length > 1) {
      for (int i = 1; i < laserPoints.length; i++) {
        final p1 = Offset(
          laserPoints[i - 1].point.dx * size.width,
          laserPoints[i - 1].point.dy * size.height,
        );
        final p2 = Offset(
          laserPoints[i].point.dx * size.width,
          laserPoints[i].point.dy * size.height,
        );

        final ageMs = now.difference(laserPoints[i].createdAt).inMilliseconds;
        final progress = (1.0 - (ageMs / 1500.0)).clamp(0.0, 1.0);
        if (progress <= 0) continue;

        // Wide outer green glow
        final glowPaint = Paint()
          ..color = const Color(0xff00ff66).withValues(alpha: 0.3 * progress)
          ..strokeWidth = 12.0 * progress
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(p1, p2, glowPaint);

        // Vibrant neon core
        final corePaint = Paint()
          ..color = const Color(0xff77ffaa).withValues(alpha: 0.85 * progress)
          ..strokeWidth = 4.0 * progress
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(p1, p2, corePaint);

        // White hot beam center
        final beamPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.95 * progress)
          ..strokeWidth = 1.8 * progress
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(p1, p2, beamPaint);
      }
    }

    // Draw glowing head orb
    final head = laserPoints.isNotEmpty
        ? Offset(
            laserPoints.last.point.dx * size.width,
            laserPoints.last.point.dy * size.height,
          )
        : (laserOffset != null
              ? Offset(
                  laserOffset!.dx * size.width,
                  laserOffset!.dy * size.height,
                )
              : null);

    if (head != null) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff44ff88).withValues(alpha: 0.85),
            const Color(0xff00ff66).withValues(alpha: 0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: head, radius: 18));
      canvas.drawCircle(head, 18, glowPaint);

      final corePaint = Paint()
        ..color = const Color(0xff77ffaa)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(head, 5.5, corePaint);

      final centerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(head, 2.5, centerDot);
    }
  }

  @override
  bool shouldRepaint(covariant LaserTrailPainter oldDelegate) => true;
}
