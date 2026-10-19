import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'exam_file.dart';

Future<List<ExamFile>> pickExamFolder() async {
  final root = await FilePicker.getDirectoryPath(
    dialogTitle: 'Chọn thư mục PDF nguồn',
  );
  if (root == null) return [];
  final result = <ExamFile>[];
  await for (final entity in Directory(
    root,
  ).list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
      if (await entity.length() > 30 * 1024 * 1024) {
        throw StateError('PDF quá 30 MB: ${entity.path}');
      }
      final relative = entity.path
          .substring(root.length + 1)
          .replaceAll('\\', '/');
      result.add(
        ExamFile(
          relative.split('/').last,
          relative,
          await entity.readAsBytes(),
        ),
      );
    }
  }
  return result;
}

Future<void> saveExamFile(Uint8List bytes, String filename) async {
  await FilePicker.saveFile(
    dialogTitle: 'Lưu tài liệu',
    fileName: filename,
    bytes: bytes,
  );
}

