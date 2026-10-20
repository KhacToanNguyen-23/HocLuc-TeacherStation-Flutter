import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/core/utils/course_title.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';

class WorkspaceInviteDialog extends StatefulWidget {
  const WorkspaceInviteDialog({
    super.key,
    required this.api,
    this.course,
    this.existingCourses = const [],
    required this.onSuccess,
  });

  final GoogleWorkspaceApi api;
  final Map<String, dynamic>? course;
  final List<Map<String, dynamic>> existingCourses;
  final void Function(Map<String, dynamic> result) onSuccess;

  static Future<void> show(
    BuildContext context, {
    required GoogleWorkspaceApi api,
    Map<String, dynamic>? course,
    List<Map<String, dynamic>> existingCourses = const [],
    required void Function(Map<String, dynamic> result) onSuccess,
  }) async {
    final dialogRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WorkspaceInviteDialog(
        api: api,
        course: course,
        existingCourses: existingCourses,
        onSuccess: onSuccess,
      ),
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

  bool _hasDuplicateTitle(String value) {
    final normalizedTitle = normalizeCourseTitle(value);
    return widget.existingCourses.any((course) {
      return normalizedTitle ==
          normalizeCourseTitle(course['title'] as String? ?? '');
    });
  }

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
          width: 480,
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
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => Text('${_title.text.length}/200'),
                      decoration: const InputDecoration(labelText: 'Tên lớp'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Nhập tên lớp.';
                        }
                        if (v.length > 200) {
                          return 'Tên lớp tối đa 200 ký tự.';
                        }
                        if (widget.course == null && _hasDuplicateTitle(v)) {
                          return 'Tên lớp này đã tồn tại. Hãy chọn lớp đó hoặc nhập tên khác.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _description,
                      enabled: !_saving,
                      maxLength: 2000,
                      maxLines: 2,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => Text('${_description.text.length}/2000'),
                      decoration: const InputDecoration(
                        labelText: 'Mô tả lớp (không bắt buộc)',
                      ),
                      validator: (value) => (value?.length ?? 0) > 2000
                          ? 'Mô tả tối đa 2000 ký tự.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    controller: _emails,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
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


