import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';

/// Per-request confirmation; never persists approval across lessons or jobs.
class PreparationAuthoringConsent {
  static Future<bool> confirm(
    BuildContext context, {
    required PreparationMap capabilities,
    required String text,
  }) async {
    final author = capabilities['authoring'] is Map
        ? capabilities['authoring'] as Map
        : <String, dynamic>{};
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Gửi nội dung để AI sinh giáo án?'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('API: ${author['baseUrl'] ?? 'Chưa cấu hình'}'),
                    Text('Model: ${author['model'] ?? 'Chưa cấu hình'}'),
                    const SizedBox(height: 12),
                    const Text(
                      'Nội dung bên dưới sẽ được gửi đến nhà cung cấp API để tạo bản nháp. Có thể phát sinh phí theo tài khoản API. Kiểm tra và loại thông tin riêng trước khi gửi.',
                    ),
                    const SizedBox(height: 12),
                    const Text('Nội dung sẽ gửi:'),
                    SelectableText(text),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Gửi và tạo bản nháp'),
              ),
            ],
          ),
        ) ==
        true;
  }
}
