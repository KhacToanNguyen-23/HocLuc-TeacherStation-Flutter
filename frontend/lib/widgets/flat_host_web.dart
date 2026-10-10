import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class FlatHost extends StatefulWidget {
  const FlatHost({super.key, required this.url});
  final String url;
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
}
