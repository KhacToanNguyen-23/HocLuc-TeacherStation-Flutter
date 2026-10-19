import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';

class WorkspaceInviteDialog extends StatefulWidget {
  const WorkspaceInviteDialog({
    super.key,
    required this.api,
    this.course,
    required this.onSuccess,
  });

  final GoogleWorkspaceApi api;
  final Map<String, dynamic>? course;
  final void Function(Map<String, dynamic> result) onSuccess;

  static Future<void> show(
    BuildContext context, {
    required GoogleWorkspaceApi api,
    Map<String, dynamic>? course,
    required void Function(Map<String, dynamic> result) onSuccess,
  }) async {
    final dialogRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          WorkspaceInviteDialog(api: api, course: course, onSuccess: onSuccess),
    );
    await Navigator.of(context).push(dialogRoute);
    await dialogRoute.completed;
  }

  @override
  State<WorkspaceInviteDialog> createState() => _WorkspaceInviteDialogState();
}

class _WorkspaceInviteDialogState extends State<WorkspaceInviteDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _emails = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _requestId = GoogleWorkspaceApi.requestId();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _emails.dispose();
    super.dispose();
  }

  static String _message(Object e) => e is FormatException
      ? e.message
      : e.toString().replaceFirst('Bad state: ', '');

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final course = widget.course;
      final result = await widget.api.call(
        course == null ? 'courses' : 'courses/${course['id']}/invite',
        post: true,
        body: {
          if (course == null) ...{
            'requestId': _requestId,
            'title': _title.text.trim(),
            'description': _description.text.trim(),
          },
          'emails': GoogleWorkspaceApi.parseEmails(_emails.text),
        },
      );
      widget.onSuccess(result);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _message(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(course == null ? 'Tạo lớp học' : 'Mời học sinh'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (course == null) ...[
                    TextFormField(
                      controller: _title,
                      enabled: !_saving,
                      maxLength: 200,
                      decoration: const InputDecoration(labelText: 'Tên lớp'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập tên lớp.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      enabled: !_saving,
                      maxLength: 2000,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả lớp (không bắt buộc)',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emails,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Email học sinh',
                      hintText: 'Mỗi dòng một email, tối đa 50 email',
                    ),
                    validator: (v) {
                      try {
                        final parsed = GoogleWorkspaceApi.parseEmails(v ?? '');
                        return parsed.isEmpty
                            ? 'Nhập ít nhất một email.'
                            : null;
                      } catch (e) {
                        return _message(e);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Thêm email vào danh sách lớp. Chuẩn bị phòng Calendar để gửi lời mời Meet; không cần học sinh chấp nhận Classroom.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(
              course == null ? 'Tạo lớp và mời học sinh' : 'Gửi lời mời',
            ),
          ),
        ],
      ),
    );
  }
}


