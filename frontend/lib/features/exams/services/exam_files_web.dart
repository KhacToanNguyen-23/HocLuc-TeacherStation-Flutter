import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;
import 'exam_file.dart';

Future<List<ExamFile>> pickExamFolder() {
  final done = Completer<List<ExamFile>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..accept = '.pdf';
  input.setAttribute('webkitdirectory', '');
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!done.isCompleted) done.complete([]);
    }).toJS,
  );
  Future<void> readSelection() async {
    try {
      final result = <ExamFile>[];
      final files = input.files;
      if (files != null) {
        for (var i = 0; i < files.length; i++) {
          final file = files.item(i)!;
          if (!file.name.toLowerCase().endsWith('.pdf')) continue;
          if (file.size > 30 * 1024 * 1024) {
            throw StateError('PDF quá 30 MB: ${file.name}');
          }
          final relative = file.webkitRelativePath;
          result.add(
            ExamFile(
              file.name,
              relative.isEmpty ? file.name : relative,
              (await file.arrayBuffer().toDart).toDart.asUint8List(),
            ),
          );
        }
      }
      if (!done.isCompleted) done.complete(result);
    } catch (e, st) {
      if (!done.isCompleted) done.completeError(e, st);
    }
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      unawaited(readSelection());
    }).toJS,
  );
  input.click();
  return done.future;
}

Future<void> saveExamFile(Uint8List bytes, String filename) async {
  await FilePicker.saveFile(
    dialogTitle: 'Lưu tài liệu',
    fileName: filename,
    bytes: bytes,
  );
}

