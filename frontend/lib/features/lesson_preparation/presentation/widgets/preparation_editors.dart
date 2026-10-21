import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import 'preparation_activity_panel.dart';
import 'preparation_support_panel.dart';

class PreparationField extends StatefulWidget {
  const PreparationField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.lines = 1,
  });
  final String label, value;
  final ValueChanged<String> onChanged;
  final int lines;
  @override
  State<PreparationField> createState() => _FieldState();
}

class _FieldState extends State<PreparationField> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(PreparationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _text.text) {
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: _text,
      minLines: widget.lines,
      maxLines: widget.lines == 1 ? 1 : null,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    ),
  );
}

class PreparationSectionEditor extends StatelessWidget {
  const PreparationSectionEditor({
    super.key,
    required this.section,
    required this.onChange,
    required this.onDelete,
    this.showTeacherNotes = true,
  });
  final PreparationMap section;
  final bool showTeacherNotes;
  final void Function(String, dynamic) onChange;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PreparationField(
        label: 'Tên phần / hoạt động',
        value: '${section['title'] ?? ''}',
        onChanged: (v) => onChange('title', v),
      ),
      PreparationField(
        label: 'Nội dung bài và hướng dẫn hoạt động',
        value: '${section['body'] ?? ''}',
        lines: 7,
        onChanged: (v) => onChange('body', v),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Mục tiêu và thời lượng (tùy chọn)'),
        children: [
          PreparationField(
            label: 'Mục tiêu (tùy chọn)',
            value: '${section['objective'] ?? ''}',
            onChanged: (v) => onChange('objective', v),
          ),
          PreparationField(
            label: 'Thời lượng (phút)',
            value: '${section['minutes'] ?? 5}',
            onChanged: (v) => onChange('minutes', int.tryParse(v) ?? 0),
          ),
        ],
      ),
      if (showTeacherNotes) ...[
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text('Ghi chú riêng giáo viên — không xuất cho học sinh'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PreparationField(
          label: 'Lời nhắc, đáp án riêng',
          value: '${section['teacherNotes'] ?? ''}',
          lines: 3,
          onChanged: (v) => onChange('teacherNotes', v),
        ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Xóa phần này'),
        ),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Hoạt động học tập và phân hóa'),
        children: [
          PreparationActivityPanel(
            section: section,
            onChanged: (rows) => onChange('activities', rows),
          ),
          PreparationSupportPanel(
            section: section,
            onChanged: (rows) => onChange('supportCards', rows),
          ),
        ],
      ),
    ],
  );
}

class PreparationSceneEditor extends StatelessWidget {
  const PreparationSceneEditor({
    super.key,
    required this.scene,
    required this.onChange,
    required this.onAction,
    required this.onDelete,
    this.voice = 'af_heart',
    this.onVoiceChanged,
  });
  final PreparationMap scene;
  final String voice;
  final ValueChanged<String>? onVoiceChanged;
  final void Function(String, dynamic) onChange;
  final ValueChanged<String> onAction;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PreparationField(
        label: 'Tên cảnh',
        value: '${scene['title'] ?? ''}',
        onChanged: (v) => onChange('title', v),
      ),
      DropdownButtonFormField<String>(
        key: ValueKey(voice),
        initialValue: voice,
        decoration: const InputDecoration(
          labelText: 'Giọng đọc tiếng Anh',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'af_heart', child: Text('Heart · English')),
          DropdownMenuItem(
            value: 'am_michael',
            child: Text('Michael · English'),
          ),
          DropdownMenuItem(value: 'af_bella', child: Text('Bella · English')),
        ],
        onChanged: (v) {
          if (v != null) onVoiceChanged?.call(v);
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: scene['template'] == 'text'
            ? 'slide'
            : '${scene['template'] ?? 'slide'}',
        decoration: const InputDecoration(
          labelText: 'Cách trình bày',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'slide', child: Text('Chữ và chuyển cảnh')),
          DropdownMenuItem(value: 'diagram', child: Text('Sơ đồ đơn giản')),
          DropdownMenuItem(value: 'highlight', child: Text('Chữ nhấn mạnh')),
          DropdownMenuItem(value: 'image', child: Text('Hình minh họa')),
        ],
        onChanged: (v) => onChange('template', v),
      ),
      const SizedBox(height: 16),
      PreparationField(
        label: 'Nội dung hiển thị / phụ đề',
        value: '${scene['text'] ?? ''}',
        lines: 4,
        onChanged: (v) => onChange('text', v),
      ),
      PreparationField(
        label: 'Script lời đọc tiếng Anh',
        value: '${scene['narration'] ?? ''}',
        lines: 5,
        onChanged: (v) => onChange('narration', v),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => onAction('translate'),
            icon: const Icon(Icons.translate),
            label: const Text('Dịch sang Anh'),
          ),
          OutlinedButton.icon(
            onPressed: () => onAction('speech'),
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('Tạo giọng đọc'),
          ),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Xóa cảnh'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        'Giọng đọc tiếng Anh dùng model local. Nghe file hoàn tất trong Tác vụ / Học liệu trước khi dựng video.',
      ),
    ],
  );
}
