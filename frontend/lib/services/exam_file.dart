import 'dart:typed_data';

class ExamFile {
  ExamFile(this.name, this.relativePath, this.bytes);
  final String name;
  final String relativePath;
  final Uint8List bytes;
}
