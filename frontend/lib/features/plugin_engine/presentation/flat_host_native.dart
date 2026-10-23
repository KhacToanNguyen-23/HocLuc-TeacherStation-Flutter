import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/features/plugin_engine/services/glass_region_service.dart';
import 'package:webview_flutter/webview_flutter.dart' as mac;
import 'package:webview_windows/webview_windows.dart' as win;
import 'flat_host_message.dart';
import 'glass_region_overlay.dart';

class FlatHost extends StatefulWidget {
  const FlatHost({
    super.key,
    required this.url,
    this.visible = true,
    this.transparentBackground = false,
    this.onMessage,
    this.onPluginMessage,
    this.onControllerReady,
    this.onControllerDisposed,
    this.glassPreset = GlassPreset.frosted,
  });
  final String url;
  final bool visible;
  final bool transparentBackground;
  final ValueChanged<dynamic>? onMessage;
  final ValueChanged<FlatHostMessage>? onPluginMessage;
  final ValueChanged<void Function(String js)>? onControllerReady;
  final ValueChanged<void Function(String js)>? onControllerDisposed;
  final GlassPreset glassPreset;

  @override
  State<FlatHost> createState() => _FlatHostState();
}

class _FlatHostState extends State<FlatHost> {
  static int _nextViewToken = 0;

  late final String _viewToken;
  int _navigationGeneration = 0;
  bool _navigationInProgress = false;
  win.WebviewController? windows;
  mac.WebViewController? macos;
  StreamSubscription? _windowsMsgSub;
  StreamSubscription<win.LoadingState>? _windowsLoadingSub;
  bool ready = false;
  bool _initialized = false;
  bool _transparentBackgroundApplied = false;
  bool _loadLoopRunning = false;
  String? _activeNavigationUrl;
  bool? _activeNavigationTransparency;
  String? error;

  @override
  void didUpdateWidget(covariant FlatHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      if (widget.visible) {
        _navigationGeneration =
            GlassRegionService.instance.currentGeneration(_viewToken) ??
            GlassRegionService.instance.beginNavigation(_viewToken);
        if (ready) {
          _evalJs(
            'window.__HocLucHostGeneration = $_navigationGeneration; '
            'window.HocLuc && window.HocLuc.glass && '
            'window.HocLuc.glass.refreshRegions && '
            'window.HocLuc.glass.refreshRegions();',
          );
        }
      } else {
        GlassRegionService.instance.clearViewRegions(_viewToken);
      }
    }
    if ((oldWidget.url != widget.url ||
            oldWidget.transparentBackground != widget.transparentBackground) &&
        _initialized) {
      // The old page's sender is keyed to the old plugin. Remove it before
      // navigation so future broadcasts cannot execute in the replacement page.
      oldWidget.onControllerDisposed?.call(_evalJs);
      ready = false;
      _navigationGeneration = GlassRegionService.instance.beginNavigation(
        _viewToken,
      );
      unawaited(_loadLatestUrl());
    }
  }

  @override
  void initState() {
    super.initState();
    _viewToken = 'webview-instance-${_nextViewToken++}';
    initialize();
  }

  void _beginNavigation() {
    if (_navigationInProgress) return;
    _navigationInProgress = true;
    _navigationGeneration = GlassRegionService.instance.beginNavigation(
      _viewToken,
    );
  }

  void _dispatchMessage(dynamic data) {
    // Ignore messages while a document is being replaced. The platform event
    // stream does not include its originating navigation ID.
    if (_navigationInProgress ||
        _activeNavigationUrl != widget.url ||
        _activeNavigationTransparency != widget.transparentBackground) {
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final origin = renderObject.localToGlobal(Offset.zero);
      widget.onPluginMessage?.call(
        FlatHostMessage(
          data: data,
          viewToken: _viewToken,
          navigationGeneration: _navigationGeneration,
          executeJs: _evalJs,
          webViewBounds: Rect.fromLTWH(
            origin.dx,
            origin.dy,
            renderObject.size.width,
            renderObject.size.height,
          ),
        ),
      );
    }
    widget.onMessage?.call(data);
  }

  void _evalJs(String script) {
    if (windows != null && ready) {
      windows!.executeScript(script);
    } else if (macos != null && ready) {
      macos!.runJavaScript(script);
    }
  }

  String _resolveUrl(String raw) {
    if (raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('file://')) {
      return raw;
    }

    final uriParts = raw.split('?');
    final filePath = uriParts[0];
    final query = uriParts.length > 1 ? '?${uriParts[1]}' : '';

    final candidates = [
      File(filePath),
      File('../$filePath'),
      File('../../$filePath'),
      File('plugins/$filePath'),
      File('../plugins/$filePath'),
    ];
    for (final f in candidates) {
      if (f.existsSync()) {
        return '${f.absolute.uri}$query';
      }
    }
    return raw;
  }

  Future<void> initialize() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        if (await win.WebviewController.getWebViewVersion() == null) {
          throw StateError('Cần Microsoft Edge WebView2 Runtime');
        }
        final controller = win.WebviewController();
        windows = controller;
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          return;
        }
        _windowsLoadingSub = controller.loadingState.listen((state) {
          if (state == win.LoadingState.loading) _beginNavigation();
          if (state == win.LoadingState.navigationCompleted) {
            _navigationInProgress = false;
            if (_activeNavigationUrl != widget.url ||
                _activeNavigationTransparency != widget.transparentBackground) {
              unawaited(_loadLatestUrl());
              return;
            }
            _notifyControllerReady();
          }
        });
        _windowsMsgSub = controller.webMessage.listen((msg) {
          _dispatchMessage(msg);
        });
        _initialized = true;
        await _loadLatestUrl();
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final controller = mac.WebViewController();
        await controller.setJavaScriptMode(mac.JavaScriptMode.unrestricted);
        await controller.setNavigationDelegate(
          mac.NavigationDelegate(
            onPageStarted: (_) => _beginNavigation(),
            onPageFinished: (_) {
              _navigationInProgress = false;
              if (_activeNavigationUrl != widget.url) {
                unawaited(_loadLatestUrl());
                return;
              }
              _notifyControllerReady();
            },
          ),
        );
        macos = controller;
        _initialized = true;
        await _loadLatestUrl();
      } else {
        throw StateError('Host hỗ trợ Windows và macOS');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _notifyControllerReady() {
    if (!mounted) return;
    if (!widget.visible) {
      GlassRegionService.instance.clearViewRegions(_viewToken);
    }
    if (!ready) setState(() => ready = true);
    final refreshRegions = widget.visible
        ? 'window.HocLuc && window.HocLuc.glass && '
              'window.HocLuc.glass.refreshRegions && '
              'window.HocLuc.glass.refreshRegions();'
        : '';
    _evalJs(
      'document.documentElement.dataset.hoclucTransparentBackground = '
      "'${_transparentBackgroundApplied ? 'true' : 'false'}'; "
      'window.__HocLucHostGeneration = $_navigationGeneration; $refreshRegions',
    );
    widget.onControllerReady?.call(_evalJs);
  }

  Future<void> _loadLatestUrl() async {
    if (!mounted ||
        !_initialized ||
        _loadLoopRunning ||
        _navigationInProgress) {
      return;
    }
    _loadLoopRunning = true;
    try {
      while (mounted && _initialized && !_navigationInProgress) {
        final requestedUrl = widget.url;
        final requestedTransparency = widget.transparentBackground;

        if (windows != null &&
            _transparentBackgroundApplied != requestedTransparency) {
          // WebView2 background changes must happen before navigating to the
          // next plugin document. Opaque plugins explicitly restore white.
          _transparentBackgroundApplied = false;
          try {
            await windows!.setBackgroundColor(
              requestedTransparency ? Colors.transparent : Colors.white,
            );
            _transparentBackgroundApplied = requestedTransparency;
          } catch (error) {
            debugPrint(
              'WebView2 transparency unavailable; using opaque fallback: $error',
            );
          }
        }

        // A newer widget configuration arrived while the native call was in
        // flight. Apply it before starting any navigation.
        if (!mounted ||
            requestedUrl != widget.url ||
            requestedTransparency != widget.transparentBackground) {
          continue;
        }
        _activeNavigationUrl = requestedUrl;
        _activeNavigationTransparency = requestedTransparency;
        _beginNavigation();
        final targetUrl = _resolveUrl(requestedUrl);
        if (windows != null) {
          await windows!.loadUrl(targetUrl);
        } else if (macos != null) {
          await macos!.loadRequest(Uri.parse(targetUrl));
        } else {
          return;
        }
        return;
      }
    } finally {
      _loadLoopRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)),
      );
    }
    if (!ready) return const Center(child: CircularProgressIndicator());
    return Stack(
      fit: StackFit.expand,
      children: [
        GlassRegionOverlay(viewToken: _viewToken, preset: widget.glassPreset),
        if (windows != null && !_transparentBackgroundApplied)
          const ColoredBox(
            key: ValueKey('webview-opaque-fallback'),
            color: Colors.white,
          ),
        if (windows != null)
          win.Webview(windows!)
        else
          mac.WebViewWidget(controller: macos!),
      ],
    );
  }

  @override
  void dispose() {
    _windowsMsgSub?.cancel();
    _windowsLoadingSub?.cancel();
    GlassRegionService.instance.disposeView(_viewToken);
    windows?.dispose();
    widget.onControllerDisposed?.call(_evalJs);
    super.dispose();
  }
}
