import 'package:flutter/material.dart';

bool validPreparationRange(double? start, double? end) =>
    start != null &&
    end != null &&
    start.isFinite &&
    end.isFinite &&
    start >= 0 &&
    end > start;

class PreparationTranscriptionDialog extends StatefulWidget {
  const PreparationTranscriptionDialog({
    super.key,
    required this.sourceName,
    required this.onPreview,
  });
  final String sourceName;
  final Future<void> Function(double) onPreview;
  @override
  State<PreparationTranscriptionDialog> createState() => _TranscriptionState();
}

class _TranscriptionState extends State<PreparationTranscriptionDialog> {
  bool _whole = true;
  double? _start = 0, _end;
  @override
  Widget build(BuildContext context) {
    final valid = _whole || validPreparationRange(_start, _end);
    return AlertDialog(
      title: const Text('Chọn đoạn cần chép lời'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.sourceName),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _whole,
                title: const Text('Toàn bộ nguồn'),
                onChanged: (v) => setState(() => _whole = v ?? true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '0',
                      enabled: !_whole,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Bắt đầu (giây)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          setState(() => _start = double.tryParse(v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      enabled: !_whole,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Kết thúc (giây)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          setState(() => _end = double.tryParse(v)),
                    ),
                  ),
                ],
              ),
              if (!valid)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Nhập số giây hữu hạn: bắt đầu ≥ 0 và kết thúc lớn hơn bắt đầu.',
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed:
                      _whole ||
                          (_start != null && _start!.isFinite && _start! >= 0)
                      ? () => widget.onPreview(_whole ? 0 : _start!)
                      : null,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Xem / nghe từ mốc bắt đầu'),
                ),
              ),
              const Text(
                'Mốc transcript giữ thời gian của nguồn gốc. File không bị cắt hoặc thay thế; bạn vẫn sửa bài khi tác vụ chạy.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: !valid
              ? null
              : () => Navigator.pop(context, <String, dynamic>{
                  if (!_whole) 'start': _start,
                  if (!_whole) 'end': _end,
                }),
          child: const Text('Chép lời'),
        ),
      ],
    );
  }
}
