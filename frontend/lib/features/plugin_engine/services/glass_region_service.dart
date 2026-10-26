import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A visual-only rectangle registered by one plugin WebView through HocLuc.
class GlassRegion {
  const GlassRegion({
    required this.viewToken,
    required this.pluginId,
    required this.regionId,
    required this.navigationGeneration,
    required this.bounds,
    required this.localBounds,
  });

  final String viewToken;
  final String pluginId;
  final String regionId;
  final int navigationGeneration;

  /// Bounds in Flutter logical coordinates relative to the host view origin.
  final Rect bounds;
  final Rect localBounds;
}

/// Validates plugin-reported CSS viewport geometry and scopes it to a WebView.
///
/// Each WebView gets a monotonically increasing navigation generation. Region
/// messages from previous documents are ignored after navigation or disposal.
class GlassRegionService extends ChangeNotifier {
  static final GlassRegionService instance = GlassRegionService();

  GlassRegionService({
    this.coalesceInterval = const Duration(milliseconds: 16),
  });

  static const int maxRegionsPerView = 16;
  static const double maxCssDimension = 8192;
  static const double maxRegionDimension = 4096;
  static const int maxRegionIdLength = 128;
  static final RegExp _validRegionId = RegExp(r'^[A-Za-z0-9_.:-]+$');

  final Duration coalesceInterval;
  final Map<String, int> _generations = {};
  final Map<(String, String), GlassRegion> _regions = {};
  Timer? _notifyTimer;

  int beginNavigation(String viewToken) {
    if (viewToken.isEmpty) return 0;
    final generation = (_generations[viewToken] ?? 0) + 1;
    _generations[viewToken] = generation;
    final removed = _regions.keys
        .where((key) => key.$1 == viewToken)
        .toList(growable: false);
    for (final key in removed) {
      _regions.remove(key);
    }
    if (removed.isNotEmpty) _scheduleNotify();
    return generation;
  }

  int? currentGeneration(String viewToken) => _generations[viewToken];

  List<GlassRegion> regionsFor(String viewToken) => List.unmodifiable(
    _regions.entries
        .where((entry) => entry.key.$1 == viewToken)
        .map((entry) => entry.value),
  );

  GlassRegion? regionFor(String viewToken, String regionId) =>
      _regions[(viewToken, regionId)];

  /// Handles one typed glass action. `webViewBounds` is measured by the host
  /// RenderBox in logical pixels; CSS pixels are scaled from the reported
  /// viewport size independently on each axis, without multiplying by DPR.
  bool handleMessage({
    required String viewToken,
    required String pluginId,
    required int navigationGeneration,
    required String action,
    required Map<String, dynamic> payload,
    required Rect webViewBounds,
  }) {
    if (viewToken.isEmpty ||
        pluginId.isEmpty ||
        currentGeneration(viewToken) != navigationGeneration) {
      return false;
    }

    final regionId = payload['region_id'];
    if (regionId is! String || !_isValidRegionId(regionId)) return false;
    final key = (viewToken, regionId);

    if (action == 'glass:unregister') {
      final removed = _regions.remove(key) != null;
      if (removed) _scheduleNotify();
      return true;
    }
    if (action != 'glass:register' && action != 'glass:update') return false;

    final rawVisible = payload['visible'];
    if (rawVisible is! bool) return false;
    final visible = rawVisible;
    if (!visible) {
      final removed = _regions.remove(key) != null;
      if (removed) _scheduleNotify();
      return true;
    }

    final viewport = _parseSize(payload['viewport']);
    final rawCssRect = _parseRect(payload['bounds']);
    if (viewport == null ||
        rawCssRect == null ||
        !_isValidWebViewBounds(webViewBounds)) {
      return false;
    }
    if (rawCssRect.width > maxRegionDimension ||
        rawCssRect.height > maxRegionDimension) {
      return false;
    }
    final cssRect = rawCssRect.intersect(
      Rect.fromLTWH(0, 0, viewport.width, viewport.height),
    );
    if (cssRect.isEmpty) {
      final removed = _regions.remove(key) != null;
      if (removed) _scheduleNotify();
      return true;
    }

    if (!_regions.containsKey(key) &&
        _regions.keys.where((entry) => entry.$1 == viewToken).length >=
            maxRegionsPerView) {
      return false;
    }

    final scaleX = webViewBounds.width / viewport.width;
    final scaleY = webViewBounds.height / viewport.height;
    if (!scaleX.isFinite || !scaleY.isFinite || scaleX <= 0 || scaleY <= 0) {
      return false;
    }
    final logicalBounds = Rect.fromLTWH(
      webViewBounds.left + cssRect.left * scaleX,
      webViewBounds.top + cssRect.top * scaleY,
      cssRect.width * scaleX,
      cssRect.height * scaleY,
    );
    final localBounds = Rect.fromLTWH(
      cssRect.left * scaleX,
      cssRect.top * scaleY,
      cssRect.width * scaleX,
      cssRect.height * scaleY,
    );
    if (!_isFiniteRect(logicalBounds) || !_isFiniteRect(localBounds)) {
      return false;
    }

    _regions[key] = GlassRegion(
      viewToken: viewToken,
      pluginId: pluginId,
      regionId: regionId,
      navigationGeneration: navigationGeneration,
      bounds: logicalBounds,
      localBounds: localBounds,
    );
    _scheduleNotify();
    return true;
  }

  void disposeView(String viewToken) {
    clearViewRegions(viewToken);
    _generations.remove(viewToken);
  }

  void clearViewRegions(String viewToken) {
    final removed = _regions.keys
        .where((key) => key.$1 == viewToken)
        .toList(growable: false);
    for (final key in removed) {
      _regions.remove(key);
    }
    if (removed.isNotEmpty) _scheduleNotify();
  }

  bool _isValidRegionId(String value) =>
      value.isNotEmpty &&
      value.length <= maxRegionIdLength &&
      _validRegionId.hasMatch(value);

  Size? _parseSize(Object? raw) {
    if (raw is! Map) return null;
    final width = _finiteNumber(raw['width']);
    final height = _finiteNumber(raw['height']);
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        width > maxCssDimension ||
        height > maxCssDimension) {
      return null;
    }
    return Size(width, height);
  }

  Rect? _parseRect(Object? raw) {
    if (raw is! Map) return null;
    final left = _finiteNumber(raw['x']);
    final top = _finiteNumber(raw['y']);
    final width = _finiteNumber(raw['width']);
    final height = _finiteNumber(raw['height']);
    if (left == null ||
        top == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  double? _finiteNumber(Object? raw) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    return value.isFinite ? value : null;
  }

  bool _isValidWebViewBounds(Rect bounds) =>
      _isFiniteRect(bounds) &&
      bounds.width > 0 &&
      bounds.height > 0 &&
      bounds.width <= maxCssDimension &&
      bounds.height <= maxCssDimension;

  bool _isFiniteRect(Rect rect) =>
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.width.isFinite &&
      rect.height.isFinite;

  void _scheduleNotify() {
    if (_notifyTimer != null) return;
    _notifyTimer = Timer(coalesceInterval, () {
      _notifyTimer = null;
      if (!isDisposed) notifyListeners();
    });
  }

  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _regions.clear();
    _generations.clear();
    super.dispose();
  }
}
