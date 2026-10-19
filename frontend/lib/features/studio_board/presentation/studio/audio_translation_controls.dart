import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/features/classroom_meet/services/audio_translation_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class AudioTranslationControls extends StatelessWidget {
  const AudioTranslationControls({
    super.key,
    required this.audio,
    required this.onPreferencesChanged,
  });
  final AudioTranslationService audio;
  final VoidCallback onPreferencesChanged;
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      onPreferencesChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _preview(BuildContext context) async {
    final file = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );
    if (file.isEmpty || !context.mounted) return;
    final picked = file.single;
    final length = await picked.length();
    if (length == null || length > 4000000) {
      throw StateError('Chọn WAV tối đa 4 MB, 15 giây.');
    }
    if (!context.mounted) return;
    final outputs = audio.devices
        .where(
          (d) =>
              d['input'] == false &&
              !(d['name'] as String).toLowerCase().contains('cable'),
        )
        .toList();
    final monitor = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Nghe thử trên loa / tai nghe'),
        children: outputs
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, d['id'] as String),
                child: Text(d['name'] as String),
              ),
            )
            .toList(),
      ),
    );
    if (monitor == null) return;
    final bytes = await picked.readAsByteStream().fold<List<int>>([], (
      buffer,
      chunk,
    ) {
      if (buffer.length + chunk.length > 4000000) {
        throw StateError('WAV quá lớn.');
      }
      buffer.addAll(chunk);
      return buffer;
    });
    await audio.previewFile(Uint8List.fromList(bytes), monitor);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: audio,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'ÂM THANH CHO HỌC SINH',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => _run(context, audio.refreshDevices),
              tooltip: 'Làm mới thiết bị âm thanh',
              icon: const Icon(Icons.refresh, size: 19),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('audio-input-${audio.inputId}'),
          initialValue: audio.inputId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Micro giáo viên'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Chọn micro')),
            ...audio.devices
                .where(audio.isTeacherInput)
                .map(
                  (d) => DropdownMenuItem(
                    value: d['id'] as String,
                    child: Text(
                      d['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          onChanged: audio.supported
              ? (v) => _run(context, () => audio.selectDevice(input: v ?? ''))
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('audio-output-${audio.outputId}'),
          initialValue: audio.outputId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Thiết bị đầu ra'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Chọn đầu ra audio')),
            ...audio.devices
                .where((d) => d['input'] == false)
                .map(
                  (d) => DropdownMenuItem(
                    value: d['id'] as String,
                    child: Text(
                      d['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          onChanged: audio.supported
              ? (v) => _run(context, () => audio.selectDevice(output: v ?? ''))
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('audio-language-${audio.language}'),
          initialValue: audio.language,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ngôn ngữ đầu ra'),
          items: const [
            DropdownMenuItem(
              value: 'vi',
              child: Text('Tiếng Việt (giọng gốc)'),
            ),
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(
              value: 'ja',
              enabled: false,
              child: Text('日本語 — chưa hỗ trợ'),
            ),
            DropdownMenuItem(
              value: 'ko',
              enabled: false,
              child: Text('한국어 — chưa hỗ trợ'),
            ),
            DropdownMenuItem(
              value: 'fr',
              enabled: false,
              child: Text('Français — chưa hỗ trợ'),
            ),
          ],
          onChanged: (v) =>
              _run(context, () => audio.selectLanguage(v ?? 'vi')),
        ),
        Material(
          color: Colors.transparent,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Phát bản dịch tiếng Anh',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              audio.requested
                  ? 'Chỉ phát khi model đã sẵn sàng.'
                  : 'Chọn English rồi chủ động bật để dịch.',
              style: const TextStyle(fontSize: 11),
            ),
            value: audio.requested,
            onChanged: audio.requested || audio.canTranslate
                ? (v) => _run(context, () => audio.setTranslation(v))
                : null,
          ),
        ),
        if (audio.language == 'en') ...[
          DropdownButtonFormField<String>(
            initialValue: audio.voice,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Giọng đọc tiếng Anh'),
            items: const [
              DropdownMenuItem(value: 'af_heart', child: Text('Heart — nữ')),
              DropdownMenuItem(
                value: 'am_michael',
                child: Text('Michael — nam'),
              ),
              DropdownMenuItem(value: 'af_bella', child: Text('Bella — nữ')),
            ],
            onChanged: (value) => _run(context, () async {
              await audio.setTranslation(false);
              audio.voice = value ?? 'af_heart';
            }),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed:
                  audio.supported &&
                      !audio.muted &&
                      !audio.requested &&
                      !audio.captureReady &&
                      audio.mode != 'file_preparing' &&
                      audio.mode != 'preview'
                  ? () => _run(context, () => _preview(context))
                  : null,
              icon: const Icon(Icons.headphones_outlined, size: 17),
              label: const Text('Nghe thử WAV'),
            ),
            OutlinedButton.icon(
              onPressed:
                  audio.supported &&
                      audio.inputId.isNotEmpty &&
                      audio.outputId.isNotEmpty
                  ? () => _run(context, audio.startOriginal)
                  : null,
              icon: const Icon(Icons.volume_up_outlined, size: 17),
              label: const Text('Phát giọng gốc'),
            ),
            OutlinedButton.icon(
              onPressed: () => _run(context, TeacherMediaService().toggleMic),
              icon: Icon(audio.muted ? Icons.mic_off : Icons.mic, size: 17),
              label: Text(audio.muted ? 'Bật mic' : 'Tắt mic'),
            ),
            TextButton(
              onPressed:
                  audio.captureReady ||
                      audio.mode == 'file_preparing' ||
                      audio.mode == 'preview'
                  ? () => _run(context, audio.stop)
                  : null,
              child: const Text('Dừng audio'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          audio.statusLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: audio.mode == 'english'
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(audio.message, style: const TextStyle(fontSize: 11)),
        if (audio.captureReady)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              value: audio.level.clamp(0, 1),
              minHeight: 3,
            ),
          ),
        if (audio.vi.isNotEmpty || audio.en.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(audio.vi, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            audio.en,
            style: const TextStyle(fontSize: 12, color: AppColors.primary),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'Trong Meet, chọn capture endpoint của audio ảo làm micro. Dùng tai nghe khi kiểm tra giọng gốc để tránh thu lại âm thanh từ loa.',
          style: TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}


