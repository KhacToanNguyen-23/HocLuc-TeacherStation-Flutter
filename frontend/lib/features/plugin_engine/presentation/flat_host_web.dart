import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:web/web.dart' as web;
import 'flat_host_message.dart';

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
    this.isPdfMode = false,
  });
  final String url;
  final bool visible;
  final bool transparentBackground;
  final ValueChanged<dynamic>? onMessage;
  final ValueChanged<FlatHostMessage>? onPluginMessage;
  final ValueChanged<void Function(String js)>? onControllerReady;
  final ValueChanged<void Function(String js)>? onControllerDisposed;
  final GlassPreset glassPreset;
  final bool isPdfMode;
  @override
  State<FlatHost> createState() => _FlatHostState();
}

class _FlatHostState extends State<FlatHost> {
  static int count = 0;
  late final String type;
  @override
  void initState() {
    super.initState();
    type = 'flat-host-${count++}';
    ui.platformViewRegistry.registerViewFactory(
      type,
      (_) => web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%',
    );
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: type);

  @override
  void dispose() {
    widget.onControllerDisposed?.call((_) {});
    super.dispose();
  }
}
