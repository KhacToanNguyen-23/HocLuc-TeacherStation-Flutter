import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';

/// Only public question-image IDs enter the live lesson projection.
class PreparationAssetImage extends StatefulWidget {
  const PreparationAssetImage({super.key, required this.assetId});
  final String assetId;
  @override
  State<PreparationAssetImage> createState() => _LessonAssetImageState();
}

class _LessonAssetImageState extends State<PreparationAssetImage> {
  final _api = PreparationApi();
  late Future<Uint8List> _image;
  @override
  void initState() {
    super.initState();
    _image = _load();
  }

  Future<Uint8List> _load() async {
    final response = await _api.assetStream(widget.assetId);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > 10_000_000) {
        throw StateError('Ảnh vượt 10 MB.');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  @override
  void didUpdateWidget(covariant PreparationAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) _image = _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _image,
    builder: (_, snapshot) => snapshot.hasError
        ? const Center(
            child: Text(
              'Không tải được hình câu hỏi',
              style: TextStyle(color: Colors.white),
            ),
          )
        : snapshot.hasData
        ? Image.memory(snapshot.data!, fit: BoxFit.contain, cacheWidth: 1280)
        : const Center(child: CircularProgressIndicator()),
  );
}
