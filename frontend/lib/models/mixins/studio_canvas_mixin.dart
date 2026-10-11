import 'package:flutter/material.dart';
import '../board_stroke.dart';

/// Mixin quản lý nét vẽ, công cụ vẽ (bút, dạ quang, tẩy, laser), màu mực và trang bảng
mixin StudioCanvasMixin on ChangeNotifier {
  int page = 0;
  Color ink = const Color(0xfff0f3ed);
  double strokeWidth = 3.5;
  Offset? laserOffset;
  List<List<BoardStroke>> pages = [[], [], []];
  String tool = 'pen';

  bool dirty = false;
  int revision = 0;

  List<BoardStroke> get strokes => pages[page];

  void setLaserOffset(Offset? offset) {
    laserOffset = offset;
    notifyListeners();
  }

  void startStroke(Offset point, {List<BoardStroke>? target}) {
    if (tool == 'laser') {
      setLaserOffset(point);
      return;
    }
    final list = target ?? strokes;
    if (tool == 'erase') {
      erase(point, target: list);
      return;
    }
    final w = tool == 'highlight' ? 18.0 : strokeWidth;
    list.add(BoardStroke(ink, w, [point]));
    revision++;
    dirty = true;
    notifyListeners();
  }

  void extendStroke(Offset point, {List<BoardStroke>? target}) {
    if (tool == 'laser') {
      setLaserOffset(point);
      return;
    }
    final list = target ?? strokes;
    if (tool == 'erase') {
      erase(point, target: list);
      return;
    }
    if (list.isEmpty) return;
    list.last.points.add(point);
    list.last.invalidatePath();
    revision++;
    dirty = true;
    notifyListeners();
  }

  void erase(Offset point, {List<BoardStroke>? target}) {
    final list = target ?? strokes;
    list.removeWhere(
      (stroke) => stroke.points.any((p) => (p - point).distance < .035),
    );
    revision++;
    dirty = true;
    notifyListeners();
  }

  void undo() {
    if (strokes.isNotEmpty) {
      strokes.removeLast();
      revision++;
      dirty = true;
      notifyListeners();
    }
  }

  void clearPage() {
    strokes.clear();
    revision++;
    dirty = true;
    notifyListeners();
  }

  void finishStroke({List<BoardStroke>? target}) {
    final list = target ?? strokes;
    if (list.isNotEmpty) {
      list.last.invalidatePath();
    }
  }
}
