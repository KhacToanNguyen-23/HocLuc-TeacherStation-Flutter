import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as mac;
import 'package:webview_windows/webview_windows.dart' as win;

class FlatHost extends StatefulWidget {
  const FlatHost({super.key, required this.url});
  final String url;
  @override
  State<FlatHost> createState() => _FlatHostState();
}

class _FlatHostState extends State<FlatHost> {
  win.WebviewController? windows;
  mac.WebViewController? macos;
  bool ready = false;
  String? error;
  @override
  void initState() {
    super.initState();
    initialize();
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
        await controller.loadUrl(widget.url);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        macos = mac.WebViewController()
          ..setJavaScriptMode(mac.JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(widget.url));
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
    if (ready) windows?.dispose();
    super.dispose();
  }
}
