import 'dart:typed_data';
import 'board_stroke.dart';

class ImportedDocument {
  ImportedDocument({
    required this.id,
    required this.name,
    this.path,
    this.bytes,
    this.totalPages = 1,
  });

  final String id;
  final String name;
  final String? path;
  final Uint8List? bytes;
  int totalPages;
  final Map<int, List<BoardStroke>> annotations = {};

  int get sizeBytes => bytes?.lengthInBytes ?? 0;
  String get formattedSize {
    final b = sizeBytes;
    if (b <= 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
