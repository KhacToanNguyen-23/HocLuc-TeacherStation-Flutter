import 'package:flutter/material.dart';
import '../../services/exam_api.dart';
import '../../screens/exams/exam_workspace_screen.dart';

/// Keeps exam navigation outside the teaching toolbar and board lifecycle.
class ExamStudioButton extends StatelessWidget {
  const ExamStudioButton({super.key, this.api});
  final ExamApi? api;

  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
    heroTag: 'exam-studio',
    tooltip: 'Đề thi & năng lực',
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
    child: const Icon(Icons.assignment_outlined),
  );
}
