import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as mac;
import 'package:webview_windows/webview_windows.dart' as win;

class FlatHost extends StatefulWidget {
  const FlatHost({
    super.key,
    required this.url,
    this.onMessage,
    this.onControllerReady,
  });
  final String url;
  final ValueChanged<dynamic>? onMessage;
  final ValueChanged<void Function(String js)>? onControllerReady;

  @override
  State<FlatHost> createState() => _FlatHostState();
}

class _FlatHostState extends State<FlatHost> {
  win.WebviewController? windows;
  mac.WebViewController? macos;
  StreamSubscription? _windowsMsgSub;
  bool ready = false;
  String? error;

  @override
  void initState() {
    super.initState();
    initialize();
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
      final targetUrl = _resolveUrl(widget.url);
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
        _windowsMsgSub = controller.webMessage.listen((msg) {
          widget.onMessage?.call(msg);
        });
        await controller.loadUrl(targetUrl);
        widget.onControllerReady?.call(_evalJs);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final controller = mac.WebViewController()
          ..setJavaScriptMode(mac.JavaScriptMode.unrestricted);
        macos = controller;
        await controller.loadRequest(Uri.parse(targetUrl));
        widget.onControllerReady?.call(_evalJs);
      } else {
        throw StateError('Host hỗ trợ Windows và macOS');
      }
      if (mounted) setState(() => ready = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
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
    return windows != null
        ? win.Webview(windows!)
        : mac.WebViewWidget(controller: macos!);
  }

  @override
  void dispose() {
    _windowsMsgSub?.cancel();
    if (ready) windows?.dispose();
    super.dispose();
  }
}

