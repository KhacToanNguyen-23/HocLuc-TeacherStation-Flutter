import 'dart:io' show Platform;
import 'package:custom_mouse_cursor/custom_mouse_cursor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Centralized manager for board mouse cursors (Pen, Eraser, Select, Laser, Pan).
/// Preloads custom asset cursors with precise hotspots and falls back gracefully
/// to system cursors if asset loading fails or is still pending.
class BoardCursorManager {
  BoardCursorManager._();

  static MouseCursor? _penCursor;
  static MouseCursor? _eraserCursor;
  static bool _initialized = false;
  static bool _isLoading = false;

  static MouseCursor? get penCursor => _penCursor;
  static MouseCursor? get eraserCursor => _eraserCursor;
  static bool get isInitialized => _initialized;

  /// Hotspot coordinates (pixel locations within 32x32 cursor assets):
  /// - Pen: Tip is at top-left corner (x: 1, y: 1)
  static const int penHotX = 1;
  static const int penHotY = 1;

  /// - Eraser: Wiping contact point is at bottom corner (x: 13, y: 27)
  static const int eraserHotX = 13;
  static const int eraserHotY = 27;

  /// Check whether execution is inside a Flutter test runner where native cursors
  /// should not monkey-patch TestPlatformDispatcher metrics.
  static bool get isTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Preload custom cursors from asset images.
  /// Can be called multiple times safely.
  static Future<void> init() async {
    if (_initialized || _isLoading) return;
    _isLoading = true;

    if (isTestEnvironment) {
      _initialized = true;
      _isLoading = false;
      return;
    }

    try {
      final pen = await CustomMouseCursor.asset(
        'assets/images/pen_cursor.png',
        hotX: penHotX,
        hotY: penHotY,
      );
      _penCursor = pen;
    } catch (e) {
      debugPrint('[BoardCursorManager] Pen cursor fallback to precise: $e');
    }

    try {
      final eraser = await CustomMouseCursor.asset(
        'assets/images/eraser_cursor.png',
        hotX: eraserHotX,
        hotY: eraserHotY,
      );
      _eraserCursor = eraser;
    } catch (e) {
      debugPrint('[BoardCursorManager] Eraser cursor fallback to grab: $e');
    }

    _initialized = true;
    _isLoading = false;
  }

  /// Resolves the cursor according to current board tool and input state.
  static MouseCursor getCursorForTool(
    String tool, {
    bool capturesBoardInput = false,
    bool isSpacePressed = false,
  }) {
    if (capturesBoardInput) {
      return SystemMouseCursors.click;
    }

    if (isSpacePressed || tool == 'pan') {
      return SystemMouseCursors.grab;
    }

    switch (tool) {
      case 'laser':
        return SystemMouseCursors.none;
      case 'erase':
        return _eraserCursor ?? SystemMouseCursors.grab;
      case 'pen':
      case 'highlight':
        return _penCursor ?? SystemMouseCursors.precise;
      case 'select':
      default:
        return SystemMouseCursors.basic;
    }
  }

  @visibleForTesting
  static void setMockCursors({MouseCursor? pen, MouseCursor? eraser}) {
    _penCursor = pen;
    _eraserCursor = eraser;
    _initialized = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _penCursor = null;
    _eraserCursor = null;
    _initialized = false;
    _isLoading = false;
  }
}
