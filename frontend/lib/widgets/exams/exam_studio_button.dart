import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/exam_api.dart';
import '../../screens/exams/exam_workspace_screen.dart';

/// Keeps exam navigation outside the teaching toolbar and board lifecycle.
class ExamStudioButton extends StatelessWidget {
  const ExamStudioButton({super.key, this.api, this.onDarkSurface = false});
  final ExamApi? api;
  final bool onDarkSurface;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Đề thi & năng lực',
    child: TextButton.icon(
      style: onDarkSurface
          ? TextButton.styleFrom(foregroundColor: AppColors.overlayAccent)
          : null,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Đề thi & năng lực'),
          children: [
            for (final item in const [
              (1, 'Ngân hàng câu hỏi'),
              (2, 'Tạo đề thi'),
              (3, 'Thư viện đề'),
            ])
              SimpleDialogOption(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          ExamWorkspaceScreen(api: api, initialPage: item.$1),
                    ),
                  );
                },
                child: Text(item.$2),
              ),
          ],
        ),
      ),
      icon: const Icon(Icons.assignment_outlined),
      label: const Text('Đề thi & năng lực'),
    ),
  );
}
