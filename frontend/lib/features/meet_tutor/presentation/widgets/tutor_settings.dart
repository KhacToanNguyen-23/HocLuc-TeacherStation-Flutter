import 'package:flutter/material.dart';
import '../../domain/models/tutor_models.dart';
import '../../services/tutor_controller.dart';

/// Session-only provider settings. A successful test never enables the tutor.
class TutorSettings extends StatefulWidget {
  const TutorSettings({super.key, required this.controller});
  final TutorController controller;

  @override
  State<TutorSettings> createState() => _TutorSettingsState();
}

class _TutorSettingsState extends State<TutorSettings> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _model;
  late final TextEditingController _key;
  TutorConfig? _tested;
  bool _testing = false;
  bool _dirty = false;
  int _revision = 0;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    final config = widget.controller.config;
    _url = TextEditingController(text: config?.baseUrl ?? '');
    _model = TextEditingController(text: config?.model ?? '');
    _key = TextEditingController(text: config?.apiKey ?? '');
  }

  @override
  void didUpdateWidget(covariant TutorSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.discardConfigurationDraft();
      _revision++;
      _testing = false;
      _tested = null;
      _dirty = false;
      _feedback = null;
      final config = widget.controller.config;
      _url.text = config?.baseUrl ?? '';
      _model.text = config?.model ?? '';
      _key.text = config?.apiKey ?? '';
    }
  }

  void _edited(String _) {
    setState(() {
      _revision++;
      _dirty = true;
      _tested = null;
      _feedback = null;
    });
    widget.controller.markConfigurationPending();
  }

  Future<void> _test() async {
    if (!_form.currentState!.validate()) return;
    final draft = TutorConfig(
      baseUrl: _url.text.trim(),
      model: _model.text.trim(),
      apiKey: _key.text.trim(),
    );
    final revision = _revision;
    final controller = widget.controller;
    setState(() {
      _testing = true;
      _tested = null;
      _feedback = null;
    });
    try {
      await controller.gateway.test(draft);
      if (!mounted ||
          controller != widget.controller ||
          revision != _revision) {
        return;
      }
      setState(() {
        _tested = draft;
        _feedback = 'Kết nối thành công. Có thể áp dụng cấu hình.';
      });
    } catch (_) {
      if (!mounted ||
          controller != widget.controller ||
          revision != _revision) {
        return;
      }
      setState(() {
        // Never echo provider errors: they can contain credentials or payloads.
        _feedback =
            'Không kết nối được. Kiểm tra URL, model, API key và hạn mức.';
      });
    } finally {
      if (mounted && controller == widget.controller) {
        setState(() => _testing = false);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.discardConfigurationDraft();
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final theme = Theme.of(context);
      return Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Trợ giảng AI', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            const Text(
              'Tự phản hồi mọi câu hỏi nhận được: trả lời, báo ngoài phạm vi, hoặc thông báo lỗi. Câu dự kiến ghi “Chưa chắc chắn”; không cần duyệt.',
            ),
            const SizedBox(height: 8),
            const Text('API tương thích OpenAI (OpenAI-compatible)'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://…/v1',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: _edited,
              validator: (value) {
                final uri = Uri.tryParse(value?.trim() ?? '');
                if (uri == null ||
                    !uri.hasAuthority ||
                    uri.host.isEmpty ||
                    !['http', 'https'].contains(uri.scheme) ||
                    uri.userInfo.isNotEmpty ||
                    uri.hasQuery ||
                    uri.hasFragment) {
                  return 'Nhập URL API hợp lệ, không chứa thông tin đăng nhập.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Model'),
              autocorrect: false,
              onChanged: _edited,
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Nhập tên model.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _key,
              decoration: const InputDecoration(
                labelText: 'API key',
                hintText: 'Để trống nếu API không yêu cầu',
              ),
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: _edited,
            ),
            const SizedBox(height: 8),
            const Text(
              'API key chỉ giữ trong bộ nhớ phiên này. Khởi động lại ứng dụng cần nhập lại; không lưu vào tùy chọn.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _testing ? null : _test,
                  child: Text(_testing ? 'Đang kiểm tra…' : 'Kiểm tra kết nối'),
                ),
                FilledButton(
                  onPressed: _tested == null || _testing
                      ? null
                      : () {
                          controller.configure(_tested!);
                          setState(() {
                            _tested = null;
                            _dirty = false;
                            _feedback =
                                'Đã áp dụng. Bật trợ giảng khi sẵn sàng.';
                          });
                        },
                  child: const Text('Áp dụng'),
                ),
              ],
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 8),
              Text(_feedback!, semanticsLabel: _feedback),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  label: 'Tự động trả lời câu hỏi Meet',
                  child: Switch(
                    value: controller.enabled || controller.starting,
                    onChanged: controller.config == null || _testing || _dirty
                        ? null
                        : controller.setEnabled,
                  ),
                ),
                Text(
                  controller.starting
                      ? 'Đang bật AI…'
                      : controller.enabled
                      ? 'Đang bật tự trả lời'
                      : 'Tạm dừng tự trả lời',
                ),
              ],
            ),
            Text(controller.status),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(controller.busy ? 'Đang xử lý' : 'Sẵn sàng'),
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
        ),
      );
    },
  );
}
