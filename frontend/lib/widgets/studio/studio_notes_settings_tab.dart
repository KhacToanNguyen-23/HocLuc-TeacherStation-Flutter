import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import 'audio_translation_studio_button.dart';

class StudioNotesSettingsTab extends StatelessWidget {
  const StudioNotesSettingsTab({
    super.key,
    required this.studio,
    required this.notesController,
    required this.questionController,
    required this.endpointController,
    required this.onPreview,
  });

  final StudioState studio;
  final TextEditingController notesController;
  final TextEditingController questionController;
  final TextEditingController endpointController;
  final VoidCallback onPreview;

  static Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
    ),
  );

  static Widget _statusLine(IconData icon, String text, String status) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
            Text(
              status,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    const muted = AppColors.muted;
    const line = AppColors.line;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Thiết bị & Đầu ra Meet',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        const Text(
          'Điều khiển riêng của giáo viên',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        const SizedBox(height: 18),
        _sectionLabel('ĐẦU RA CHO MEETING'),
        const SizedBox(height: 10),
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xffeef1e7),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 24, color: muted),
              const SizedBox(height: 7),
              const Text(
                'Khung trình bày bảng vẽ',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onPreview,
                child: const Text(
                  'Xem khung trình bày →',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _statusLine(
          Icons.videocam_outlined,
          'Camera bảng vẽ',
          '1080p WGC Sẵn sàng',
        ),
        _statusLine(Icons.mic_none_outlined, 'Micro thu âm', 'Theo thiết bị'),
        const SizedBox(height: 16),
        const Divider(color: line),
        const SizedBox(height: 12),
        _sectionLabel('DỊCH GIỌNG NÓI & TRỢ NĂNG'),
        const SizedBox(height: 8),
        AudioTranslationStudioButton(studio: studio),
        const SizedBox(height: 16),
        const Divider(color: line),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.security_rounded, size: 16, color: AppColors.success),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bảo mật buổi dạy: Học sinh trên Meet chỉ nhìn thấy khung bảng vẽ. Toàn bộ thanh công cụ, ghi chú diễn giả và màn hình điều khiển này hoàn toàn riêng tư.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
