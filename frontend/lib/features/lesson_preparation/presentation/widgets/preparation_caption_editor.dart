import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import 'preparation_editors.dart';

/// Scene-relative captions are committed together after validation, so partial
/// numeric edits never trigger an invalid autosave revision.
class PreparationCaptionEditor extends StatefulWidget {
  const PreparationCaptionEditor({
    super.key,
    required this.scene,
    required this.onCommit,
  });
  final PreparationMap scene;
  final ValueChanged<PreparationMap> onCommit;
  @override
  State<PreparationCaptionEditor> createState() => _CaptionState();
}

class _CaptionState extends State<PreparationCaptionEditor> {
  late List<PreparationMap> _rows;
  String? _error;
  bool _draft = false;
  late bool _visible;
  late String _mode;
  Timer? _timer;
  final _watch = Stopwatch();
  @override
  void initState() {
    super.initState();
    _visible = widget.scene['captionsVisible'] != false;
    _mode = widget.scene['captionMode'] == 'bilingual'
        ? 'bilingual'
        : 'english';
    _rows = preparationRows(
      widget.scene['captions'],
    ).map((r) => {...r}).toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _watch.stop();
    super.dispose();
  }

  double? get _duration => (widget.scene['audioDuration'] as num?)?.toDouble();
  void _commit() {
    final cues = <PreparationMap>[];
    var previous = 0.0;
    for (final row in _rows) {
      final start = double.tryParse('${row['start']}');
      final end = double.tryParse('${row['end']}');
      final text = '${row['text'] ?? ''}'.trim();
      if (start == null ||
          end == null ||
          !start.isFinite ||
          !end.isFinite ||
          start < previous ||
          end <= start ||
          end > (_duration ?? 900) ||
          text.isEmpty ||
          text.length > 1000) {
        setState(
          () => _error =
              'Mỗi cue cần nội dung, 0 ≤ bắt đầu < kết thúc, không chồng nhau và nằm trong thời lượng cảnh.',
        );
        return;
      }
      final secondary = '${row['secondaryText'] ?? ''}'.trim();
      if (_mode == 'bilingual' &&
          (secondary.isEmpty || secondary.length > 1000)) {
        setState(
          () => _error =
              'Điền bản dịch thứ hai cho từng cue trước khi duyệt song ngữ.',
        );
        return;
      }
      cues.add({
        'id': row['id'],
        'start': start,
        'end': end,
        'text': text,
        if (secondary.isNotEmpty) 'secondaryText': secondary,
      });
      previous = end;
    }
    if (cues.isEmpty) {
      setState(() => _error = 'Thêm ít nhất một cue để duyệt phụ đề.');
      return;
    }
    widget.onCommit({
      'captions': cues,
      'captionMode': _mode,
      'captionsVisible': _visible,
      'captionsReviewed': true,
      'captionsNarration': widget.scene['narration'] ?? '',
    });
    setState(() {
      _error = null;
      _draft = false;
    });
  }

  void _rehearse() {
    if (_watch.isRunning) {
      _watch.stop();
      _timer?.cancel();
    } else {
      _watch.reset();
      _watch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Phụ đề và diễn tập cảnh'),
    subtitle: Text(
      _draft
          ? 'Đang sửa chưa lưu — nhấn Lưu và duyệt trước khi dựng video'
          : widget.scene['captionsReviewed'] == true
          ? 'Đã duyệt — lưu cùng revision bài'
          : 'Cue tự sinh là ước lượng; chỉnh và duyệt trước khi dựng lại',
    ),
    childrenPadding: const EdgeInsets.symmetric(vertical: 12),
    children: [
      SwitchListTile(
        title: const Text('Xuất phụ đề cho cảnh này'),
        subtitle: const Text(
          'Phụ đề là file SRT đi kèm video; bật/tắt khi xem bằng trình phát hỗ trợ.',
        ),
        value: _visible,
        onChanged: (v) => setState(() {
          _visible = v;
          _draft = true;
        }),
      ),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'english', label: Text('Tiếng Anh')),
          ButtonSegment(value: 'bilingual', label: Text('Song ngữ')),
        ],
        selected: {_mode},
        onSelectionChanged: (v) => setState(() {
          _mode = v.single;
          _draft = true;
        }),
      ),
      if (_mode == 'bilingual')
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Nhập và duyệt bản dịch thứ hai. Chế độ này không tự dịch lời đọc tiếng Anh.',
          ),
        ),
      Text(
        _duration == null
            ? 'Chưa biết thời lượng audio. Dựng thử rồi áp dụng kết quả để lấy mốc thật; renderer vẫn kiểm lại giới hạn.'
            : 'Audio đã tạo: ${_duration!.toStringAsFixed(2)} giây. Mốc cue tính từ đầu cảnh.',
      ),
      for (var i = 0; i < _rows.length; i++)
        Padding(
          key: ValueKey(_rows[i]['id']),
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PreparationField(
                      label: 'Bắt đầu (giây)',
                      value: '${_rows[i]['start']}',
                      onChanged: (v) => setState(() {
                        _rows[i]['start'] = v;
                        _draft = true;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PreparationField(
                      label: 'Kết thúc (giây)',
                      value: '${_rows[i]['end']}',
                      onChanged: (v) => setState(() {
                        _rows[i]['end'] = v;
                        _draft = true;
                      }),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa cue',
                    onPressed: () => setState(() {
                      _rows.removeAt(i);
                      _draft = true;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              PreparationField(
                label: 'Nội dung phụ đề',
                value: '${_rows[i]['text'] ?? ''}',
                lines: 2,
                onChanged: (v) => setState(() {
                  _rows[i]['text'] = v;
                  _draft = true;
                }),
              ),
              if (_mode == 'bilingual')
                PreparationField(
                  label: 'Bản dịch thứ hai · cue ${i + 1}',
                  value: '${_rows[i]['secondaryText'] ?? ''}',
                  lines: 2,
                  onChanged: (v) => setState(() {
                    _rows[i]['secondaryText'] = v;
                    _draft = true;
                  }),
                ),
              _CaptionPreview(
                text:
                    '${_rows[i]['text'] ?? ''}${_mode == 'bilingual' ? '\n${_rows[i]['secondaryText'] ?? ''}' : ''}',
                visible: _visible,
              ),
            ],
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: _rows.length >= 200
                ? null
                : () => setState(() {
                    final start = _rows.isEmpty
                        ? 0.0
                        : double.tryParse('${_rows.last['end']}') ?? 0;
                    _rows.add({
                      'id': PreparationDocument.newId(),
                      'start': start,
                      'end': _duration ?? start + 2,
                      'text': _rows.isEmpty
                          ? widget.scene['narration'] ?? ''
                          : '',
                    });
                    _draft = true;
                  }),
            icon: const Icon(Icons.add),
            label: const Text('Thêm cue'),
          ),
          OutlinedButton(
            onPressed: _commit,
            child: const Text('Lưu và duyệt phụ đề'),
          ),
          TextButton.icon(
            onPressed: _rehearse,
            icon: Icon(_watch.isRunning ? Icons.stop : Icons.timer_outlined),
            label: Text(
              _watch.isRunning
                  ? 'Dừng · ${(_watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} giây'
                  : 'Diễn tập lời đọc',
            ),
          ),
        ],
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_watch.elapsedMilliseconds > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SelectableText(
            'Đã đọc ${(_watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} giây${_duration == null ? '' : ' / audio ${_duration!.toStringAsFixed(1)} giây'}\n${widget.scene['narration'] ?? ''}',
          ),
        ),
      if (_watch.elapsedMilliseconds > 0 &&
          '${widget.scene['teacherNotes'] ?? ''}'.isNotEmpty)
        SelectableText('Nhắc riêng giáo viên: ${widget.scene['teacherNotes']}'),
    ],
  );
}

/// Phone-width sample with explicit high-contrast colors. Real player subtitle
/// typography remains under the student's player settings.
class _CaptionPreview extends StatelessWidget {
  const _CaptionPreview({required this.text, required this.visible});
  final String text;
  final bool visible;
  @override
  Widget build(BuildContext context) {
    if (!visible) return const Text('Cue này không được đưa vào file SRT.');
    const style = TextStyle(fontSize: 16, height: 1.4, color: Colors.white);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 360.0).toDouble();
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: (width - 32).clamp(1.0, 328.0));
        final overflow = painter.computeLineMetrics().length > 4;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xem thử chiều rộng điện thoại'),
            Container(
              width: width,
              padding: const EdgeInsets.all(16),
              color: const Color(0xff111827),
              child: Text(text, style: style),
            ),
            if (overflow)
              const Text(
                'Cue dài hơn 4 dòng ở cỡ chữ điện thoại. Tách thành nhiều cue hoặc rút gọn để dễ đọc.',
              ),
            const Text(
              'Xem thử: chữ trắng trên nền tối; trình phát có thể dùng cỡ chữ và màu riêng.',
            ),
          ],
        );
      },
    );
  }
}
