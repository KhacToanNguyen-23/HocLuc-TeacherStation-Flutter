import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';

class StudioInspectorPanel extends StatelessWidget {
  const StudioInspectorPanel({
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

  @override
  Widget build(BuildContext context) {
    const muted = AppColors.muted;
    const line = AppColors.line;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: line)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Chuẩn bị buổi dạy',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Điều khiển riêng của giáo viên',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 22),
          _sectionLabel('ĐẦU RA CHO MEETING'),
          const SizedBox(height: 10),
          Container(
            height: 128,
            decoration: BoxDecoration(
              color: const Color(0xffeef1e7),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_outlined, size: 27, color: muted),
                const SizedBox(height: 9),
                const Text('Camera chưa kết nối', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 5),
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
          _statusLine(Icons.videocam_outlined, 'Camera ảo', 'Cần native bridge'),
          _statusLine(Icons.mic_none_outlined, 'Micro ảo', 'Cần native bridge'),
          const SizedBox(height: 18),
          const Divider(color: line),
          const SizedBox(height: 14),
          _sectionLabel('ÂM THANH & API AI'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: studio.microphone,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Microphone'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Chọn thiết bị', style: TextStyle(fontSize: 11)),
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
            onChanged: (value) =>
                studio.change(() => studio.microphone = value ?? ''),
          ),
          const SizedBox(height: 7),
          const Text(
            'Danh sách từ JavaSound; chưa thu âm.',
            style: TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 7),
          Material(
            color: Colors.white,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Yêu cầu lọc tiếng ồn',
                style: TextStyle(fontSize: 11),
              ),
              subtitle: const Text(
                'Tùy chọn cho API sau này',
                style: TextStyle(fontSize: 10, color: muted),
              ),
              value: studio.denoise,
              onChanged: (v) => studio.change(() => studio.denoise = v),
            ),
          ),
          const Text(
            'Hiện chỉ lưu cấu hình. Chưa gọi AI, chưa phát âm thanh.',
            style: TextStyle(fontSize: 10, color: muted, height: 1.6),
          ),
          const SizedBox(height: 18),
          const Divider(color: line),
          const SizedBox(height: 14),
          if (studio.view == 'question') ...[
            _sectionLabel('CÂU HỎI MẪU'),
            const SizedBox(height: 12),
            TextField(
              controller: questionController,
              minLines: 2,
              maxLines: 4,
              onChanged: (v) => studio.change(() => studio.question = v),
              decoration: const InputDecoration(hintText: 'Nội dung câu hỏi…'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bản khung dùng bốn phương án và đáp án B của bài mẫu.',
              style: TextStyle(fontSize: 10, color: muted, height: 1.6),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => studio.change(
                () => studio.reveal = !studio.reveal,
                persist: false,
              ),
              icon: Icon(
                studio.reveal
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
              ),
              label: Text(studio.reveal ? 'Ẩn đáp án' : 'Hiện đáp án'),
            ),
            const SizedBox(height: 16),
          ],
          _sectionLabel('GHI CHÚ RIÊNG'),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            minLines: 3,
            maxLines: 5,
            onChanged: (v) => studio.change(() => studio.notes = v),
            decoration: const InputDecoration(
              hintText: 'Điểm cần nhấn mạnh, câu hỏi gợi mở…',
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Không xuất trong khung trình bày.',
            style: TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${(studio.seconds ~/ 60).toString().padLeft(2, '0')}:${(studio.seconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: studio.timerRunning ? 'Dừng đồng hồ' : 'Bắt đầu 2 phút',
                onPressed: studio.toggleTimer,
                icon: Icon(
                  studio.timerRunning
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Bản thử không có lab. Kết nối Meet tự động sẽ phát triển sau.',
            style: TextStyle(fontSize: 10, color: muted, height: 1.6),
          ),
        ],
      ),
    );
  }

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
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
        Text(
          status,
          style: const TextStyle(fontSize: 10, color: Color(0xff9b7246)),
        ),
      ],
    ),
  );
}
