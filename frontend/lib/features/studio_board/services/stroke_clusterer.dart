import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

class StrokeClusterer {
  static const double _proximityRadius =
      0.045; // Tight proximity: ~40-50px, never trigger on empty space
  static const double _wordGapThreshold = 0.016;

  static SmartChalkAnnotation? clusterAndAnalyze({
    required Offset touchPoint,
    required List<BoardStroke> strokes,
    int pageIndex = 0,
    String? hintText,
  }) {
    if (strokes.isEmpty) return null;

    // 1. Calculate bounding box for each stroke
    final strokeBounds = <BoardStroke, Rect>{};
    for (final s in strokes) {
      if (s.isEraser || s.points.isEmpty) continue;
      double minX = s.points.first.dx;
      double maxX = s.points.first.dx;
      double minY = s.points.first.dy;
      double maxY = s.points.first.dy;

      for (final p in s.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      strokeBounds[s] = Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    if (strokeBounds.isEmpty) return null;

    // 2. Filter strokes directly at or within tight proximity of touchPoint
    final nearbyStrokes = strokeBounds.entries.where((entry) {
      final rect = entry.value;
      final dist = (rect.center - touchPoint).distance;
      return dist <= _proximityRadius ||
          rect.inflate(0.015).contains(touchPoint);
    }).toList();

    // MUST NOT create annotation if user clicked empty board space
    if (nearbyStrokes.isEmpty) return null;

    // 3. Find the target Y level and group strokes on the same line
    final targetY =
        nearbyStrokes.map((e) => e.value.center.dy).reduce((a, b) => a + b) /
        nearbyStrokes.length;

    final lineStrokes = strokeBounds.entries.where((entry) {
      final rect = entry.value;
      final verticalOverlap =
          rect.bottom >= (targetY - 0.12) && rect.top <= (targetY + 0.12);
      final centerClose = (rect.center.dy - targetY).abs() <= 0.11;
      return verticalOverlap || centerClose;
    }).toList();

    if (lineStrokes.isEmpty) return null;

    // 4. Compute overall sentence bounding box
    double lineMinX = lineStrokes.first.value.left;
    double lineMaxX = lineStrokes.first.value.right;
    double lineMinY = lineStrokes.first.value.top;
    double lineMaxY = lineStrokes.first.value.bottom;

    for (final entry in lineStrokes) {
      final r = entry.value;
      lineMinX = math.min(lineMinX, r.left);
      lineMaxX = math.max(lineMaxX, r.right);
      lineMinY = math.min(lineMinY, r.top);
      lineMaxY = math.max(lineMaxY, r.bottom);
    }

    final lineWidth = (lineMaxX - lineMinX).clamp(0.08, 1.0);
    final lineHeight = (lineMaxY - lineMinY).clamp(0.04, 0.4);
    final lineBounds = Rect.fromLTWH(lineMinX, lineMinY, lineWidth, lineHeight);

    // 5. Sort strokes from left to right and cluster into words
    lineStrokes.sort((a, b) => a.value.left.compareTo(b.value.left));

    final wordClusters = <Rect>[];
    Rect? currentWordRect;

    for (final entry in lineStrokes) {
      final r = entry.value;
      if (currentWordRect == null) {
        currentWordRect = r;
      } else {
        final isTinyPunctuation = r.width < 0.015 && r.height < 0.015;
        final dynamicGap = (currentWordRect.width < 0.04)
            ? 0.012
            : _wordGapThreshold;
        if (r.left - currentWordRect.right > dynamicGap && !isTinyPunctuation) {
          wordClusters.add(currentWordRect);
          currentWordRect = r;
        } else {
          currentWordRect = Rect.fromLTRB(
            math.min(currentWordRect.left, r.left),
            math.min(currentWordRect.top, r.top),
            math.max(currentWordRect.right, r.right),
            math.max(currentWordRect.bottom, r.bottom),
          );
        }
      }
    }
    if (currentWordRect != null) {
      wordClusters.add(currentWordRect);
    }

    // Preserve stroke geometry as a plain, unclassified chalk annotation.
    final chalkTokens = <ChalkWordToken>[];
    final sentenceText = hintText?.trim().isNotEmpty == true
        ? hintText!.trim()
        : 'Handwriting';
    final words = hintText?.trim().isNotEmpty == true
        ? hintText!.trim().split(RegExp(r'\s+'))
        : List.generate(wordClusters.length, (_) => 'W');
    for (int i = 0; i < words.length; i++) {
      final relRect = i < wordClusters.length
          ? Rect.fromLTWH(
              ((wordClusters[i].left - lineBounds.left) / lineBounds.width)
                  .clamp(0.0, 1.0),
              0.0,
              (wordClusters[i].width / lineBounds.width).clamp(0.05, 1.0),
              1.0,
            )
          : Rect.fromLTWH(i / words.length, 0.0, 0.9 / words.length, 1.0);
      chalkTokens.add(ChalkWordToken(word: words[i], relativeRect: relRect));
    }
    return SmartChalkAnnotation(
      id: 'annotation',
      source: 'chalkboard',
      pageIndex: pageIndex,
      rawText: sentenceText,
      normalizedBounds: lineBounds,
      tokens: chalkTokens,
      isVisible: true,
      normalizedOffset: Offset.zero,
    );
  }

  static Future<Uint8List?> rasterizeStrokesToPng({
    required List<BoardStroke> strokes,
    required Rect bounds,
  }) async {
    try {
      if (bounds.width <= 0 || bounds.height <= 0) return null;

      // 1. Calculate natural physical aspect ratio on 16:9 canvas
      final physicalW = (bounds.width * 1600.0).clamp(60.0, 1600.0);
      final physicalH = (bounds.height * 900.0).clamp(30.0, 900.0);
      final aspectRatio = physicalW / physicalH;

      // Standardize the target text line height to the existing 80px baseline.
      const targetH = 80.0;
      final targetW = (targetH * aspectRatio).clamp(160.0, 2400.0);

      const paddingX = 28.0;
      const paddingY = 24.0;
      final width = (targetW + paddingX * 2).toInt();
      final height = (targetH + paddingY * 2).toInt();

      final scaleX = targetW / bounds.width;
      final scaleY = targetH / bounds.height;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // High-contrast pure white background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = Colors.white,
      );

      final strokePaint = Paint()
        ..color = Colors.black
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.2; // Optimal stroke width for 80px font height

      for (final s in strokes) {
        if (s.isEraser || s.points.isEmpty) continue;
        final points = s.points;

        if (points.length == 1) {
          final p = points.first;
          final x = (p.dx - bounds.left) * scaleX + paddingX;
          final y = (p.dy - bounds.top) * scaleY + paddingY;
          canvas.drawCircle(Offset(x, y), 3.0, Paint()..color = Colors.black);
          continue;
        }

        final path = Path();
        final firstX = (points[0].dx - bounds.left) * scaleX + paddingX;
        final firstY = (points[0].dy - bounds.top) * scaleY + paddingY;
        path.moveTo(firstX, firstY);

        for (int i = 1; i < points.length; i++) {
          final p0 = points[i - 1];
          final p1 = points[i];
          final x0 = (p0.dx - bounds.left) * scaleX + paddingX;
          final y0 = (p0.dy - bounds.top) * scaleY + paddingY;
          final x1 = (p1.dx - bounds.left) * scaleX + paddingX;
          final y1 = (p1.dy - bounds.top) * scaleY + paddingY;
          final midX = (x0 + x1) / 2;
          final midY = (y0 + y1) / 2;
          path.quadraticBezierTo(x0, y0, midX, midY);
        }

        final lastX = (points.last.dx - bounds.left) * scaleX + paddingX;
        final lastY = (points.last.dy - bounds.top) * scaleY + paddingY;
        path.lineTo(lastX, lastY);

        canvas.drawPath(path, strokePaint);
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
