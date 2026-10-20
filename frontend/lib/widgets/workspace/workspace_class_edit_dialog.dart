import 'package:flutter/material.dart';
import '../../services/google_workspace_api.dart';

class WorkspaceClassEditDialog extends StatefulWidget {
  const WorkspaceClassEditDialog({
    super.key,
    required this.api,
    required this.course,
    required this.onSuccess,
  });

  final GoogleWorkspaceApi api;
  final Map<String, dynamic> course;
  final ValueChanged<Map<String, dynamic>> onSuccess;

  static Future<void> show(
    BuildContext context, {
    required GoogleWorkspaceApi api,
    required Map<String, dynamic> course,
    required ValueChanged<Map<String, dynamic>> onSuccess,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WorkspaceClassEditDialog(
      api: api,
      course: course,
      onSuccess: onSuccess,
    ),
  );

  @override
  State<WorkspaceClassEditDialog> createState() =>
      _WorkspaceClassEditDialogState();
}

class _WorkspaceClassEditDialogState extends State<WorkspaceClassEditDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.course['title'] as String? ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.course['description'] as String? ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'Nhập tên lớp.';
      });
      return;
    }
    if (title.length > 200 || _description.text.length > 2000) {
      setState(() {
        _error = 'Tên lớp tối đa 200 ký tự; mô tả tối đa 2000 ký tự.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.api.call(
        'courses/${widget.course['id']}',
        method: 'PUT',
        body: {'title': title, 'description': _description.text.trim()},
      );
      widget.onSuccess(result);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Sửa lớp'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              enabled: !_saving,
              maxLength: 200,
              autofocus: true,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => Text('${_title.text.length}/200'),
              decoration: const InputDecoration(labelText: 'Tên lớp'),
            ),
            const SizedBox(height: 8),
            TextField(
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
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
}
