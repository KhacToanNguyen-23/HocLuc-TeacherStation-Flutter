import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import '../../services/preparation_controller.dart';

class PreparationJobsPanel extends StatelessWidget {
  const PreparationJobsPanel({
    super.key,
    required this.controller,
    required this.onApply,
    required this.onPreview,
    required this.onAction,
    this.onCreatePdf,
  });
  final PreparationController controller;
  final VoidCallback? onCreatePdf;
  final ValueChanged<PreparationMap> onApply, onPreview;
  final void Function(String, String) onAction;
  static String _kind(dynamic value) =>
      const {
        'author': 'Đề xuất nội dung',
        'transcribe': 'Chép lời bản ghi',
        'translate': 'Dịch nội dung',
        'speech': 'Tạo giọng đọc',
        'render': 'Dựng video',
        'export_pdf': 'Xuất PDF',
      }['$value'] ??
      'Xử lý nội dung';
  static String _status(dynamic value) =>
      const {
        'queued': 'Đang chờ',
        'running': 'Đang xử lý',
        'succeeded': 'Hoàn tất',
        'failed': 'Cần xử lý lỗi',
        'cancelled': 'Đã hủy',
      }['$value'] ??
      'Đang cập nhật';
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Tài liệu đã tạo và kết quả cần duyệt',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      if (controller.jobs.isEmpty &&
          controller.document.rows('artifacts').isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chưa có tài liệu xuất từ bài này.'),
              const SizedBox(height: 8),
              const Text(
                'Tạo PDF để phát cho học sinh hoặc lưu bản giáo viên có lời nhắc riêng.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreatePdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Tạo PDF học sinh'),
              ),
            ],
          ),
        ),
      for (final job in controller.jobs)
        ExpansionTile(
          title: Text('${_kind(job['kind'])} · ${_status(job['status'])}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (job['status'] == 'running' || job['status'] == 'queued')
                LinearProgressIndicator(
                  value: job['progress'] is num
                      ? ((job['progress'] as num).toDouble() /
                                ((job['progress'] as num) > 1 ? 100 : 1))
                            .clamp(0, 1)
                      : null,
                ),
              if (job['error'] != null)
                Text(
                  '${job['error']}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              Text('Bản bài: ${job['revision'] ?? '—'}'),
            ],
          ),
          children: [
            for (final artifact in preparationRows(
              job['result'] is Map ? (job['result'] as Map)['artifacts'] : null,
            ))
              TextButton.icon(
                onPressed: () => onPreview(artifact),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(
                  'Xem / nghe ${artifact['name'] ?? artifact['kind'] ?? 'học liệu'}',
                ),
              ),
            if (job['result'] is Map && (job['result'] as Map)['text'] != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText('${(job['result'] as Map)['text']}'),
              ),
            if (job['result'] is Map &&
                preparationRows((job['result'] as Map)['sections']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${preparationRows((job['result'] as Map)['sections']).length} phần nội dung cần duyệt trước khi đưa vào bài.',
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                if (job['status'] == 'succeeded')
                  TextButton.icon(
                    onPressed: () => onApply(job),
                    icon: const Icon(Icons.check),
                    label: const Text('Duyệt / áp dụng'),
                  ),
                if (job['status'] == 'running' || job['status'] == 'queued')
                  TextButton(
                    onPressed: () => onAction('${job['id']}', 'cancel'),
                    child: const Text('Hủy'),
                  ),
                if ((job['status'] == 'failed' ||
                        job['status'] == 'cancelled') &&
                    job['kind'] == 'author' &&
                    job['inputMode'] != 'script')
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Chọn Thêm nội dung để sửa yêu cầu và xác nhận gửi API lại.',
                    ),
                  ),
                if ((job['status'] == 'failed' ||
                        job['status'] == 'cancelled') &&
                    (job['kind'] != 'author' || job['inputMode'] == 'script'))
                  TextButton(
                    onPressed: () => onAction('${job['id']}', 'retry'),
                    child: const Text('Thử lại'),
                  ),
              ],
            ),
          ],
        ),
      const Divider(),
      for (final asset in controller.document.rows('artifacts'))
        ListTile(
          leading: const Icon(Icons.play_circle_outline),
          title: Text('${asset['name'] ?? asset['kind'] ?? asset['id']}'),
          subtitle: Text(
            asset['revision'] == controller.document.revision
                ? 'Bản hiện tại'
                : 'Khác revision hiện tại — kiểm tra trước khi dùng',
          ),
          onTap: () => onPreview(asset),
        ),
    ],
  );
}
