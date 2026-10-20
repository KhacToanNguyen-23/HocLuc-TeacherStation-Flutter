import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../domain/models/ink_path.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

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
    this.displayStrokes,
    this.interactive = true,
    this.smartSnapEnabled = false,
    this.onSmartTap,
    this.deferTapToOverlay = false,
  });

  final StudioState studio;
  final List<BoardStroke>? targetStrokes;
  final List<BoardStroke>? displayStrokes;
  final bool interactive;
  final bool smartSnapEnabled;
  final ValueChanged<Offset>? onSmartTap;
  final bool deferTapToOverlay;

  @override
  State<StrokeCanvas> createState() => _StrokeCanvasState();
}

class _StrokeCanvasState extends State<StrokeCanvas> {
  final List<Offset> _activePoints = [];
  final ValueNotifier<List<Offset>?> _activeStrokeNotifier = ValueNotifier(
    null,
  );

  final List<LaserPoint> _laserPoints = [];
  final Map<int, Offset> _smartPointerDowns = {};
  final ValueNotifier<List<LaserPoint>> _laserTrailNotifier = ValueNotifier([]);
  Timer? _laserTimer;
  Offset? _laserHoverOffset;
  bool _smartPointerMovedBeyondTapSlop = false;

  void _trackSmartPointerDown(PointerDownEvent event) {
    if (!widget.deferTapToOverlay) return;
    _smartPointerDowns[event.pointer] = event.localPosition;
    _smartPointerMovedBeyondTapSlop = false;
  }

  void _trackSmartPointerMove(PointerMoveEvent event) {
    final down = _smartPointerDowns[event.pointer];
    if (down != null && (event.localPosition - down).distance > kTouchSlop) {
      _smartPointerMovedBeyondTapSlop = true;
    }
  }

  void _trackSmartPointerUp(PointerEvent event) {
    final down = _smartPointerDowns.remove(event.pointer);
    if (down != null && (event.localPosition - down).distance > kTouchSlop) {
      _smartPointerMovedBeyondTapSlop = true;
    }
  }

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

        final strokes =
            widget.displayStrokes ??
            widget.targetStrokes ??
            widget.studio.strokes;

        final isSvoMode = widget.studio.activeSubjectTool == 'svo';

        return MouseRegion(
          cursor: isSvoMode
              ? SystemMouseCursors.click
              : widget.studio.tool == 'laser'
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
          child: Listener(
            onPointerDown: _trackSmartPointerDown,
            onPointerMove: _trackSmartPointerMove,
            onPointerUp: _trackSmartPointerUp,
            onPointerCancel: (event) {
              _smartPointerDowns.remove(event.pointer);
              _smartPointerMovedBeyondTapSlop = false;
              _activePoints.clear();
              _activeStrokeNotifier.value = null;
            },
            child: GestureDetector(
              onPanStart: widget.interactive
                  ? (e) {
                      if (isSvoMode) return;
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
                      if (isSvoMode) return;
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
                      if (isSvoMode) return;
                      if (widget.studio.tool == 'laser' ||
                          widget.studio.tool == 'erase') {
                        return;
                      }
                      if (widget.deferTapToOverlay &&
                          _activePoints.length <= 1 &&
                          !_smartPointerMovedBeyondTapSlop) {
                        // A tap is classified by PdfStage's overlay. Pan can
                        // also win for a stationary tap, so do not persist that
                        // recognizer's one-point dot. A deliberate drag beyond
                        // tap slop continues through the normal stroke path.
                        _activePoints.clear();
                        _activeStrokeNotifier.value = null;
                        _smartPointerMovedBeyondTapSlop = false;
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
                          isHighlighter: isHighlighter,
                        );
                        stroke.getPath(size); // Precompute and cache path
                        widget.studio.addStroke(
                          stroke,
                          target: widget.targetStrokes,
                        );
                        _activePoints.clear();
                        _activeStrokeNotifier.value = null;
                      }
                      _smartPointerMovedBeyondTapSlop = false;
                    }
                  : null,
              onTapUp:
                  widget.interactive &&
                      (!widget.deferTapToOverlay ||
                          (widget.smartSnapEnabled &&
                              widget.onSmartTap != null))
                  ? (e) {
                      if (widget.smartSnapEnabled &&
                          widget.onSmartTap != null) {
                        widget.onSmartTap!(normalized(e.localPosition));
                        return;
                      }
                      // Smart mode waits for Flutter's tap recognizer to win so
                      // a tap dot is never committed before answer classification.
                      if (widget.deferTapToOverlay ||
                          (widget.smartSnapEnabled &&
                              widget.onSmartTap != null)) {
                        return;
                      }
                      final norm = normalized(e.localPosition);
                      if (isSvoMode) {
                        widget.studio.analyzeHandwritingAt(norm);
                        return;
                      }
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
                        ], isHighlighter: isHighlighter);
                        stroke.getPath(size);
                        widget.studio.addStroke(
                          stroke,
                          target: widget.targetStrokes,
                        );
                      }
                    }
                  : null,
              onPanCancel: widget.interactive
                  ? () {
                      _activePoints.clear();
                      _activeStrokeNotifier.value = null;
                      _smartPointerMovedBeyondTapSlop = false;
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
                  for (final stroke in strokes.where((s) => s.isSmartPenOval))
                    TweenAnimationBuilder<double>(
                      key: ValueKey(
                        '${stroke.smartPenGroupId}:${stroke.smartPenLabel}',
                      ),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 260),
                      builder: (context, progress, _) => CustomPaint(
                        size: size,
                        painter: SmartPenOvalPainter(
                          stroke: stroke,
                          progress: progress,
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
                  // Repaints from its own notifiers only (trail + pointer), so
                  // laser movement never rebuilds the surrounding screen.
                  if (widget.studio.tool == 'laser')
                    RepaintBoundary(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          _laserTrailNotifier,
                          widget.studio.laserOffsetListenable,
                        ]),
                        builder: (context, _) {
                          return CustomPaint(
                            size: size,
                            painter: LaserTrailPainter(
                              laserPoints: _laserTrailNotifier.value,
                              laserOffset:
                                  widget.studio.laserOffset ??
                                  _laserHoverOffset,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
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
      if (stroke.isSmartPenOval) continue;
      if (stroke.points.isEmpty && stroke.rect == null) continue;

      final isHighlight = stroke.isHighlighter || stroke.rect != null;
      final paint = Paint()
        ..color = stroke.isHollow
            ? stroke.color.withValues(alpha: 0.95)
            : (isHighlight
                  ? stroke.color.withValues(
                      alpha: stroke.rect != null ? 0.38 : 0.35,
                    )
                  : stroke.color)
        ..style = stroke.isHollow ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = stroke.isHollow
            ? (stroke.width <= 3.0 ? stroke.width : 1.6)
            : stroke.width;

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

class SmartPenOvalPainter extends CustomPainter {
  const SmartPenOvalPainter({required this.stroke, required this.progress});

  final BoardStroke stroke;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (stroke.points.length < 2 || progress <= 0) return;
    final path = Path()
      ..moveTo(
        stroke.points.first.dx * size.width,
        stroke.points.first.dy * size.height,
      );
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    path.close();
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final revealed = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      revealed,
      Paint()
        ..color = stroke.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant SmartPenOvalPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      !identical(oldDelegate.stroke, stroke);
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

    final pixelPoints = activePoints
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final path = buildInkPath(pixelPoints, width, highlight: isHighlight);
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
