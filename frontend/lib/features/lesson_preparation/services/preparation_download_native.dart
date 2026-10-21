import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../domain/models/preparation_document.dart';
import 'preparation_api.dart';

Future<bool> downloadPreparationAsset(
  PreparationApi api,
  PreparationMap asset,
) async {
  final directory = await FilePicker.getDirectoryPath(
    dialogTitle: 'Chọn thư mục lưu học liệu',
  );
  if (directory == null) return false;
  final name = '${asset['name'] ?? 'hoc-lieu'}'.replaceAll(
    RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
    '_',
  );
  var file = File('$directory${Platform.pathSeparator}$name');
  if (await file.exists()) {
    file = File(
      '$directory${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}-$name',
    );
  }
  final response = await api.assetStream('${asset['id']}');
  final output = file.openWrite();
  try {
    await output.addStream(
      response.stream.timeout(const Duration(seconds: 60)),
    );
    await output.flush();
    await output.close();
    return true;
  } catch (_) {
    await output.close();
    if (await file.exists()) await file.delete();
    rethrow;
  }
}
