import 'package:flutter/material.dart';
import '../../services/tutor_controller.dart';

/// Teacher controls and delivery status; provider settings live only on the backend.
class TutorSettings extends StatelessWidget {
  const TutorSettings({super.key, required this.controller});
  final TutorController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Trợ giảng AI', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          const Text(
            'Tự phản hồi câu hỏi trên Meet. Câu trả lời dự kiến ghi rõ “Chưa chắc chắn”; không cần duyệt.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                label: 'Tự động trả lời câu hỏi Meet',
                child: Switch(
                  value: controller.enabled || controller.starting,
                  onChanged: controller.config == null
                      ? null
                      : controller.setEnabled,
                ),
              ),
              Text(
                controller.starting
                    ? 'Đang bật AI…'
                    : controller.recovering
                    ? 'Đang kết nối lại chat Meet…'
                    : controller.enabled
                    ? 'Đang bật tự trả lời'
                    : 'Tạm dừng tự trả lời',
              ),
            ],
          ),
          Text(controller.displayStatus),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                controller.recovering
                    ? 'Chờ kết nối chat'
                    : controller.busy
                    ? 'Đang xử lý'
                    : 'Sẵn sàng',
              ),
              Text('Đang chờ: ${controller.queued}'),
              Text('Đã gửi: ${controller.sentCount}'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Nhật ký sự cố (${controller.reviews.length})',
            style: theme.textTheme.titleSmall,
          ),
          if (controller.reviews.isEmpty)
            const Text(
              'Lỗi xử lý hoặc chưa gửi được sẽ hiện ở đây. Không có câu trả lời chờ duyệt.',
            ),
          for (final review in controller.reviews) ...[
            const Divider(height: 24),
            Text(review.sender, style: theme.textTheme.labelLarge),
            Text(review.question),
            const SizedBox(height: 4),
            Text(review.reason),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => controller.dismissReview(review),
                child: const Text('Bỏ qua'),
              ),
            ),
          ],
        ],
      );
    },
  );
}
