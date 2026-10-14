import 'media_broadcast_controls.dart';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';

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

  static Widget _statusLine(IconData icon, String text, String status) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
            Text(
              status,
              style: const TextStyle(fontSize: 10, color: Color(0xff16a34a), fontWeight: FontWeight.w600),
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
          'Chuẩn bị buổi dạy',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        const Text(
          'Điều khiển riêng của giáo viên',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        const SizedBox(height: 18),
        _sectionLabel('ĐẦU RA CHO MEETING'),
        MediaBroadcastControlsButton(studio: studio),
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
              const Text('Khung trình bày bảng vẽ', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onPreview,
                child: const Text('Xem khung trình bày →', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _statusLine(Icons.videocam_outlined, 'Camera bảng vẽ', '1080p WGC Sẵn sàng'),
        _statusLine(Icons.mic_none_outlined, 'Micro thu âm', 'Khử ồn tự động'),
        const SizedBox(height: 16),
        const Divider(color: line),
        const SizedBox(height: 12),
        _sectionLabel('ÂM THANH & API AI'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: studio.microphone,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Microphone'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Chọn thiết bị mic', style: TextStyle(fontSize: 11)),
            ),
            ...studio.microphones.map(
              (m) => DropdownMenuItem(
                value: m['id'] as String,
                child: Text(
                  m['name'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
          onChanged: (value) => studio.change(() => studio.microphone = value ?? ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: endpointController,
          decoration: const InputDecoration(
            labelText: 'API AI của bạn',
            hintText: 'https://ai.example.vn',
          ),
          style: const TextStyle(fontSize: 12),
          onChanged: (v) => studio.change(() => studio.endpoint = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: studio.language,
          decoration: const InputDecoration(labelText: 'Ngôn ngữ đầu ra'),
          items: ['English', 'Tiếng Việt', '日本語', '한국어', 'Français']
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (s) {
            if (s != null) studio.change(() => studio.language = s);
          },
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lọc tạp âm AI thông minh', style: TextStyle(fontSize: 11)),
            value: studio.denoise,
            onChanged: (v) => studio.change(() => studio.denoise = v),
          ),
        ),
        const SizedBox(height: 14),
        const Divider(color: line),
        const SizedBox(height: 12),
        _sectionLabel('GHI CHÚ RIÊNG CỦA THẦY/CÔ'),
        const SizedBox(height: 10),
        TextField(
          controller: notesController,
          minLines: 3,
          maxLines: 5,
          onChanged: (v) => studio.change(() => studio.notes = v),
          decoration: const InputDecoration(
            hintText: 'Điểm cần nhấn mạnh, câu hỏi gợi mở cho học sinh…',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ghi chú cá nhân, không hiển thị cho học sinh trên Meet.',
          style: TextStyle(fontSize: 10, color: muted),
        ),
      ],
    );
  }
}
