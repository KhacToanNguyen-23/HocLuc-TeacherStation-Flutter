import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';

class PreparationCapabilitiesStatus extends StatelessWidget {
  const PreparationCapabilitiesStatus({super.key, required this.capabilities});
  final PreparationMap capabilities;
  @override
  Widget build(BuildContext context) {
    final models = capabilities['models'] is Map
        ? capabilities['models'] as Map
        : {};
    final author = capabilities['authoring'] is Map
        ? capabilities['authoring'] as Map
        : {};
    final ffmpeg = capabilities['ffmpeg'] is Map
        ? capabilities['ffmpeg'] as Map
        : {};
    final packages = capabilities['packages'] is Map
        ? capabilities['packages'] as Map
        : {};
    Widget row(String label, bool ready, [String? detail]) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ready ? Icons.check_circle_outline : Icons.error_outline,
        color: ready
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
      title: Text(label),
      subtitle: Text(
        detail ??
            (ready
                ? 'Sẵn sàng'
                : 'Chưa sẵn sàng — kiểm tra đường dẫn và thành phần đã cài'),
      ),
    );
    return Column(
      children: [
        row(
          'Python / worker',
          capabilities['pythonReady'] == true &&
              capabilities['workerReady'] == true,
        ),
        row('Dựng video / ghi nguồn', ffmpeg['ready'] == true),
        for (final item in const [
          ('asr', 'STT tiếng Việt'),
          ('translation', 'Dịch Việt → Anh'),
          ('tts', 'Giọng đọc tiếng Anh'),
        ])
          row(
            item.$2,
            models[item.$1] is Map &&
                (models[item.$1] as Map)['present'] == true &&
                packages['torch'] == true &&
                packages[item.$1 == 'tts' ? 'kokoro' : 'transformers'] == true,
            models[item.$1] is Map
                ? '${(models[item.$1] as Map)['path'] ?? ''}\nTrạng thái thư mục và thư viện local; chất lượng model được kiểm tra khi chạy.'
                : null,
          ),
        row(
          'Sinh giáo án · API bên thứ ba',
          author['ready'] == true,
          author['ready'] == true
              ? '${author['model']} · ${author['baseUrl']}\nĐã cấu hình; chưa gọi thử API.'
              : author['keyConfigured'] == false
              ? 'Backend chưa cấu hình HOCLUC_AUTHORING_API_KEY. Soạn thủ công và chia cảnh từ script vẫn dùng được.'
              : '${author['message'] ?? 'Cấu hình API base URL và model để sinh giáo án.'}',
        ),
      ],
    );
  }
}
