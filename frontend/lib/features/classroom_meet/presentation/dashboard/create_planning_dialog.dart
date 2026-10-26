import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';

/// Result object returned by [CreatePlanningDialog].
class CreatePlanningResult {
  const CreatePlanningResult({required this.title, required this.subject});
  final String title;
  final String subject;
}

/// Dialog for creating a new lesson planning document.
class CreatePlanningDialog extends StatefulWidget {
  const CreatePlanningDialog({super.key, required this.subjectOptions});

  final List<String> subjectOptions;

  static Future<CreatePlanningResult?> show(
    BuildContext context, {
    required List<String> subjectOptions,
  }) {
    return showAppModalDialog<CreatePlanningResult>(
      context: context,
      builder: (_) => CreatePlanningDialog(subjectOptions: subjectOptions),
    );
  }

  @override
  State<CreatePlanningDialog> createState() => _CreatePlanningDialogState();
}

class _CreatePlanningDialogState extends State<CreatePlanningDialog> {
  late final TextEditingController _titleController;
  late String _selectedSub;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Kế hoạch bài giảng mới');
    final validSubjects = widget.subjectOptions.where((s) => s != 'Tất cả');
    _selectedSub = validSubjects.isNotEmpty ? validSubjects.first : 'Tiếng Anh';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      title: const Row(
        children: [
          Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            'Soạn kế hoạch bài giảng mới',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tên kế hoạch bài giảng',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Nhập tên bài giảng...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Môn học',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: AppColors.slate300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSub,
                isExpanded: true,
                items: widget.subjectOptions
                    .where((s) => s != 'Tất cả')
                    .map(
                      (s) => DropdownMenuItem<String>(value: s, child: Text(s)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSub = val);
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Hủy',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim().isNotEmpty
                ? _titleController.text.trim()
                : 'Kế hoạch bài giảng mới';
            Navigator.of(
              context,
            ).pop(CreatePlanningResult(title: title, subject: _selectedSub));
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
          ),
          child: const Text('Bắt đầu soạn'),
        ),
      ],
    );
  }
}
