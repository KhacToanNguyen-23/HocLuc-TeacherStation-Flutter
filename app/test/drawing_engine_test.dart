import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:teaching_companion/models/studio_state.dart';

void main() {
  test('perfect_freehand computes outline points for input points', () {
    final points = [
      PointVector(10, 10),
      PointVector(20, 20),
      PointVector(30, 25),
      PointVector(40, 30),
    ];

    final outline = getStroke(
      points,
      options: StrokeOptions(
        size: 8,
        thinning: 0.4,
        smoothing: 0.5,
        streamline: 0.5,
      ),
    );

    expect(outline.isNotEmpty, isTrue);
    expect(outline.length, greaterThan(points.length));

    final path = Path();
    path.moveTo(outline.first.dx, outline.first.dy);
    for (int i = 1; i < outline.length; i++) {
      path.lineTo(outline[i].dx, outline[i].dy);
    }
    path.close();

    expect(path.getBounds().width, greaterThan(0));
    expect(path.getBounds().height, greaterThan(0));
  });

  test('BoardStroke getPath returns smooth cached path', () {
    final stroke = BoardStroke(Colors.white, 4.0, [
      const Offset(0.1, 0.1),
      const Offset(0.2, 0.2),
      const Offset(0.3, 0.25),
    ]);

    final path1 = stroke.getPath();
    final path2 = stroke.getPath();
    expect(identical(path1, path2), isTrue);

    stroke.points.add(const Offset(0.4, 0.3));
    stroke.invalidatePath();
    final path3 = stroke.getPath();
    expect(identical(path1, path3), isFalse);
  });

  test('StudioState laser mode updates laserOffset without adding strokes', () {
    final state = StudioState();
    expect(state.strokes.isEmpty, isTrue);

    state.tool = 'laser';
    state.startStroke(const Offset(0.5, 0.5));
    expect(state.laserOffset, equals(const Offset(0.5, 0.5)));
    expect(state.strokes.isEmpty, isTrue);

    state.extendStroke(const Offset(0.6, 0.6));
    expect(state.laserOffset, equals(const Offset(0.6, 0.6)));
    expect(state.strokes.isEmpty, isTrue);

    state.tool = 'pen';
    state.startStroke(const Offset(0.1, 0.1));
    state.extendStroke(const Offset(0.2, 0.2));
    expect(state.strokes.length, equals(1));
    expect(state.strokes.first.points.length, equals(2));
  });
}
