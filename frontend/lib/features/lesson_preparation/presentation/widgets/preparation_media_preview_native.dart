import 'dart:convert';
import 'dart:typed_data';
import '../../domain/models/preparation_captions.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:teaching_companion/features/classroom_meet/services/webview_environment_service.dart';

class PreparationMediaPreview extends StatefulWidget {
  const PreparationMediaPreview({
    super.key,
    required this.bytes,
    required this.mime,
    this.initialPosition = 0,
    this.subtitleText,
  });
  final Uint8List bytes;
  final String mime;
  final double initialPosition;
  final String? subtitleText;
  @override
  State<PreparationMediaPreview> createState() => _PreviewState();
}

class _PreviewState extends State<PreparationMediaPreview> {
  final _controller = WebviewController();
  String? _error;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    if (!widget.mime.contains('pdf') && !widget.mime.startsWith('image/')) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      await WebviewEnvironmentService.ensureInitialized();
      await _controller.initialize();
      final tag = widget.mime.startsWith('audio/') ? 'audio' : 'video';
      final track = widget.subtitleText == null || tag == 'audio'
          ? ''
          : '<track default kind="subtitles" srclang="en" label="Phụ đề đã soạn" src="data:text/vtt;base64,${base64Encode(utf8.encode(preparationWebVtt(widget.subtitleText!)))}">';
      await _controller.loadStringContent(
        '''<!doctype html><html><head>
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; media-src data:; style-src 'unsafe-inline'">
<style>body{margin:0;background:#101828;display:grid;place-items:center;height:100vh}video,audio{width:100%;max-height:100vh}</style></head><body>
<$tag controls src="data:${widget.mime};base64,${base64Encode(widget.bytes)}#t=${widget.initialPosition}">$track</$tag></body></html>''',
      );
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mime.contains('pdf')) {
      return PdfViewer.data(widget.bytes, sourceName: 'HocLuc preview');
    }
    if (widget.mime.startsWith('image/')) {
      return Image.memory(widget.bytes, fit: BoxFit.contain);
    }
    if (_error != null) {
      return Center(child: SelectableText('Không mở được trình phát: $_error'));
    }
    return _ready
        ? Webview(_controller)
        : const Center(child: CircularProgressIndicator());
  }
}
