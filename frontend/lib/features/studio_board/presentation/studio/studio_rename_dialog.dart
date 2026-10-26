import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';

class StudioRenameDialog extends StatefulWidget {
  const StudioRenameDialog({super.key, required this.initialTitle});

  final String initialTitle;

  static Future<String?> show(BuildContext context, String currentTitle) {
    return showAppModalDialog<String>(
      context: context,
      builder: (_) => StudioRenameDialog(initialTitle: currentTitle),
    );
  }

  @override
  State<StudioRenameDialog> createState() => _StudioRenameDialogState();
}

class _StudioRenameDialogState extends State<StudioRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tên bài giảng'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(
          hintText: 'Nhập tên bài giảng mới...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Đổi tên'),
        ),
      ],
    );
  }
}

