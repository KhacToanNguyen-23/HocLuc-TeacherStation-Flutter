import 'dart:typed_data';
import '../../domain/models/preparation_captions.dart';
import 'dart:ui_web' as ui;
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  late final String _id, _url;
  String? _trackUrl;
  @override
  void initState() {
    super.initState();
    _id = 'preparation-preview-${DateTime.now().microsecondsSinceEpoch}';
    _url = web.URL.createObjectURL(
      web.Blob(
        [widget.bytes.toJS].toJS,
        web.BlobPropertyBag(type: widget.mime),
      ),
    );
    if (widget.subtitleText != null && widget.mime.startsWith('video/')) {
      _trackUrl = web.URL.createObjectURL(
        web.Blob(
          [preparationWebVtt(widget.subtitleText!).toJS].toJS,
          web.BlobPropertyBag(type: 'text/vtt'),
        ),
      );
    }
    ui.platformViewRegistry.registerViewFactory(_id, (_) {
      if (widget.mime.startsWith('video/')) {
        final video = web.HTMLVideoElement()
          ..src = _url
          ..controls = true;
        video.style
          ..width = '100%'
          ..height = '100%';
        if (_trackUrl != null) {
          final track = web.HTMLTrackElement()
            ..kind = 'subtitles'
            ..label = 'Phụ đề đã soạn'
            ..srclang = 'en'
            ..src = _trackUrl!
            ..default_ = true;
          video.appendChild(track);
        }
        video.src = '$_url#t=${widget.initialPosition}';
        return video;
      }
      final frame = web.HTMLIFrameElement()
        ..src = '$_url#t=${widget.initialPosition}';
      frame.style
        ..width = '100%'
        ..height = '100%'
        ..border = '0';
      return frame;
    });
  }

  @override
  void dispose() {
    web.URL.revokeObjectURL(_url);
    if (_trackUrl != null) web.URL.revokeObjectURL(_trackUrl!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _id);
}
