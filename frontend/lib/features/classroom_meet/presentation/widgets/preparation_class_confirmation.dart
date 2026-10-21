import 'package:flutter/material.dart';

Future<bool> confirmPreparationClass(
  BuildContext context, {
  String? preferredCourseId,
  String? preferredName,
  String? selectedCourseId,
  required String selectedName,
}) async {
  final different = preferredCourseId != null
      ? preferredCourseId != selectedCourseId
      : preferredName != null && preferredName != selectedName;
  if (!different) return true;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dạy biến thể cho lớp khác?'),
          content: Text(
            'Bài này được soạn cho ${preferredName ?? 'lớp đã gắn'}. Bạn đang chọn $selectedName. Nội dung và liên kết lớp của bài không tự thay đổi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Chọn lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      ) ??
      false;
}
