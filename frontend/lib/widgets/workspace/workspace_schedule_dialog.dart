import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/google_workspace_api.dart';

class WorkspaceScheduleDialog extends StatefulWidget {
  const WorkspaceScheduleDialog({
    super.key,
    required this.api,
    required this.course,
    required this.start,
    required this.isNow,
    required this.onSuccess,
  });

  final GoogleWorkspaceApi api;
  final Map<String, dynamic> course;
  final DateTime start;
  final bool isNow;
  final void Function(Map<String, dynamic> result) onSuccess;

  static Future<void> show(
    BuildContext context, {
    required GoogleWorkspaceApi api,
    required Map<String, dynamic> course,
    required DateTime start,
    required bool isNow,
    required void Function(Map<String, dynamic> result) onSuccess,
  }) async {
    final dialogRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WorkspaceScheduleDialog(
        api: api,
        course: course,
        start: start,
        isNow: isNow,
        onSuccess: onSuccess,
      ),
    );
    await Navigator.of(context).push(dialogRoute);
    await dialogRoute.completed;
  }

  @override
  State<WorkspaceScheduleDialog> createState() => _WorkspaceScheduleDialogState();
}

class _WorkspaceScheduleDialogState extends State<WorkspaceScheduleDialog> {
  final _duration = TextEditingController(text: '90');
  final _requestId = GoogleWorkspaceApi.requestId();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  static String _message(Object e) => e is FormatException
      ? e.message
      : e.toString().replaceFirst('Bad state: ', '');

  static String _date(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _submit() async {
    final minutes = int.tryParse(_duration.text);
    if (minutes == null || minutes < 1 || minutes > 1440) {
      setState(() => _error = 'Thời lượng từ 1–1440 phút.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await widget.api.call(
        'courses/${widget.course['id']}/schedule',
        post: true,
        body: {
          'requestId': _requestId,
          'start': widget.start.toUtc().toIso8601String(),
          'end': widget.start.add(Duration(minutes: minutes)).toUtc().toIso8601String(),
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
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          widget.isNow ? 'Chuẩn bị phòng Calendar' : 'Lên lịch và tạo phòng Meet',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.course['title']} · ${_date(widget.start.toIso8601String())}',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _duration,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời lượng (phút)',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tạo một buổi Calendar có phòng Meet mới và gửi lời mời tới các email đã chọn trong lớp. Link cũ sẽ được thay bằng link buổi này. Thời gian theo múi giờ máy của bạn.',
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
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
              ],
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
            child: const Text('Tạo phòng và gửi lời mời'),
          ),
        ],
      ),
    );
  }
}
