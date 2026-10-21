import 'package:file_picker/file_picker.dart';
import '../domain/models/preparation_document.dart';
import 'preparation_api.dart';

Future<bool> downloadPreparationAsset(
  PreparationApi api,
  PreparationMap asset,
) async {
  if ((asset['size'] as num? ?? 0) > 20 * 1024 * 1024) {
    throw StateError(
      'File lớn hơn 20 MB. Hãy dùng bản Windows để lưu theo luồng, tránh đầy bộ nhớ trình duyệt.',
    );
  }
  final bytes = await api.bytes('${asset['id']}');
  return await FilePicker.saveFile(
        fileName: '${asset['name'] ?? 'hoc-lieu'}',
        bytes: bytes,
      ) !=
      null;
}
