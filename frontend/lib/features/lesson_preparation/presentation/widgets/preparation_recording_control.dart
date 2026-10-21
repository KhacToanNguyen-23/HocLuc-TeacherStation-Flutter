import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import '../../services/preparation_controller.dart';

class PreparationRecordingControl extends StatefulWidget {
  const PreparationRecordingControl({
    super.key,
    required this.controller,
    required this.onRecorded,
  });
  final PreparationController controller;
  final VoidCallback onRecorded;
  @override
  State<PreparationRecordingControl> createState() => _RecordingState();
}

class _RecordingState extends State<PreparationRecordingControl> {
  PreparationMap? get _recording => widget.controller.activeRecording;
  set _recording(PreparationMap? value) {
    widget.controller.activeRecording = value;
    widget.controller.emit();
  }

  bool _busy = false;
  String? _error;
  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devices = Map<String, dynamic>.from(
        await widget.controller.api.get('recordings/devices') as Map,
      );
      if (!mounted) return;
      String? selected;
      bool screen = false, withAudio = false, confirmed = false;
      String source = 'desktop';
      final windows = preparationRows(devices['windows']);
      final names = (devices['audioDevices'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: const Text('Ghi nguồn cho bài soạn'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      value: screen,
                      title: const Text('Ghi màn hình / cửa sổ'),
                      subtitle: const Text(
                        'Tắt để thu microphone. Dừng trong app, tối đa 30 phút.',
                      ),
                      onChanged: (v) => update(() => screen = v),
                    ),
                    if (screen)
                      DropdownButtonFormField<String>(
                        initialValue: source,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Nguồn hình',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'desktop',
                            child: Text('Toàn màn hình'),
                          ),
                          for (final window in windows)
                            DropdownMenuItem(
                              value: '${window['source']}',
                              child: Text(
                                '${window['title']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => update(() {
                          source = v ?? 'desktop';
                          confirmed = false;
                        }),
                      ),
                    if (screen && source != 'desktop')
                      const Text(
                        'Ghi đúng cửa sổ đã chọn, cần FFmpeg 7 trở lên. Giữ cửa sổ mở và không thu nhỏ khi ghi.',
                      ),
                    if (screen)
                      CheckboxListTile(
                        value: withAudio,
                        title: const Text('Ghi kèm microphone'),
                        subtitle: const Text(
                          'Nếu không chọn, video ghi màn hình không có âm thanh.',
                        ),
                        onChanged: (v) => update(() => withAudio = v ?? false),
                      ),
                    if (!screen || withAudio)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selected,
                        decoration: const InputDecoration(
                          labelText: 'Microphone',
                        ),
                        items: names
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => update(() => selected = v),
                      ),
                    if (names.isEmpty && (!screen || withAudio))
                      const Text(
                        'Chưa tìm thấy microphone. Kiểm tra FFmpeg và quyền thiết bị trong Thành phần local.',
                      ),
                    CheckboxListTile(
                      value: confirmed,
                      title: const Text(
                        'Tôi đồng ý ghi nguồn đã chọn; đã đóng nội dung riêng không muốn ghi.',
                      ),
                      onChanged: (v) => update(() => confirmed = v ?? false),
                    ),
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
                onPressed:
                    confirmed && (screen && !withAudio || selected != null)
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Bắt đầu ghi'),
              ),
            ],
          ),
        ),
      );
      if (approved != true) return;
      final result = await widget.controller.api
          .post('${widget.controller.path}/recordings', {
            'kind': screen ? 'screen' : 'microphone',
            'device': selected,
            if (screen) 'source': source,
            if (screen && source != 'desktop')
              'sourceTitle': windows.firstWhere(
                (w) => w['source'] == source,
              )['title'],
            if (screen && withAudio) 'audioDevice': selected,
            'confirmed': true,
          });
      if (mounted) {
        setState(() => _recording = Map<String, dynamic>.from(result as Map));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await widget.controller.api.post('recordings/${_recording!['id']}/stop');
      final fresh =
          await widget.controller.api.get(widget.controller.path) as Map;
      final doc = fresh['document'] is Map ? fresh['document'] as Map : fresh;
      widget.controller.document.data['sources'] = doc['sources'];
      if (mounted) setState(() => _recording = null);
      await widget.controller.refreshRecordings();
      widget.onRecorded();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ bản ghi chưa lưu?'),
        content: const Text(
          'Dừng ghi và xóa file thu này. Các nguồn đã lưu trong bài vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ bản ghi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ bản ghi'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.controller.api.post(
        'recordings/${_recording!['id']}/discard',
      );
      if (mounted) {
        setState(() {
          _recording = null;
          _error = null;
        });
      }
      await widget.controller.refreshRecordings();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : _recording == null
            ? _start
            : _stop,
        icon: Icon(
          _recording == null ? Icons.mic_none : Icons.stop_circle_outlined,
        ),
        label: Text(
          _busy
              ? 'Đang xử lý…'
              : _recording == null
              ? 'Ghi microphone / màn hình'
              : _recording!['status'] == 'recoverable'
              ? 'Khôi phục và lưu bản ghi trước'
              : 'Đang ghi — Dừng và lưu nguồn',
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_error!),
        ),
      if (_recording != null)
        TextButton(
          onPressed: _busy ? null : _discard,
          child: const Text('Bỏ bản ghi chưa lưu'),
        ),
      if (_recording != null)
        Text(
          _recording!['status'] == 'recoverable'
              ? 'Có bản thu chưa lưu từ phiên trước. Khôi phục để thêm vào nguồn hoặc bỏ bản ghi. File gốc được giữ nếu khôi phục lỗi.'
              : 'Đang ghi nguồn local. Hãy dừng trước khi rời bài. Giới hạn tự dừng: 30 phút.',
        ),
      if (widget.controller.pendingRecordings.length > 1)
        DropdownButton<String>(
          value: '${_recording?['id']}',
          isExpanded: true,
          items: widget.controller.pendingRecordings
              .map(
                (r) => DropdownMenuItem(
                  value: '${r['id']}',
                  child: Text('${r['kind']} · ${r['createdAt'] ?? r['id']}'),
                ),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (id) => setState(() {
                  _recording = widget.controller.pendingRecordings.firstWhere(
                    (r) => '${r['id']}' == id,
                  );
                }),
        ),
    ],
  );
}
