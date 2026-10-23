import 'package:flutter/material.dart';

class WorkspaceCourseLifecycleDialogs {
  static Future<bool> confirmArchive(
    BuildContext context, {
    required String title,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu trữ lớp học?'),
        content: Text(
          '“$title” sẽ được lưu trữ trong Google Classroom. Bạn có thể khôi phục lớp sau đó.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  static Future<bool> confirmDelete(
    BuildContext context, {
    required String title,
    required bool remote,
    required bool archived,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(archived ? 'Xóa vĩnh viễn lớp học?' : 'Xóa lớp học?'),
        content: Text(
          remote
              ? archived
                    ? '“$title” sẽ bị xóa khỏi HocLucStation và Google Classroom. Bài đăng và bình luận trong Classroom có thể bị xóa; tệp trên Drive vẫn được giữ. Không thể hoàn tác.'
                    : 'Chỉ có thể xóa vĩnh viễn lớp sau khi lưu trữ.'
              : '“$title” sẽ bị xóa khỏi danh sách HocLucStation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(archived ? 'Xóa vĩnh viễn' : 'Xóa'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
