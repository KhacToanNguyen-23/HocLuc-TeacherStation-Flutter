import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import 'preparation_editors.dart';

class PreparationTranscriptEditor extends StatelessWidget {
  const PreparationTranscriptEditor({
    super.key,
    required this.segments,
    required this.onChanged,
    required this.onSeek,
  });
  final List<PreparationMap> segments;
  final ValueChanged<List<PreparationMap>> onChanged;
  final ValueChanged<double> onSeek;
  void _change(int index, String field, dynamic value) {
    final updated = segments.map((r) => Map<String, dynamic>.from(r)).toList();
    updated[index][field] = value;
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Transcript theo mốc nguồn',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < segments.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PreparationField(
                      label: 'Bắt đầu (giây)',
                      value: '${segments[i]['start'] ?? 0}',
                      onChanged: (v) {
                        final n = double.tryParse(v);
                        if (n != null && n >= 0 && n.isFinite) {
                          _change(i, 'start', n);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PreparationField(
                      label: 'Kết thúc (giây)',
                      value: '${segments[i]['end'] ?? 0}',
                      onChanged: (v) {
                        final n = double.tryParse(v);
                        if (n != null &&
                            n.isFinite &&
                            n >=
                                ((segments[i]['start'] as num?)?.toDouble() ??
                                    0)) {
                          _change(i, 'end', n);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xem nguồn tại mốc này',
                    onPressed: () =>
                        onSeek((segments[i]['start'] as num?)?.toDouble() ?? 0),
                    icon: const Icon(Icons.play_circle_outline),
                  ),
                ],
              ),
              PreparationField(
                label: 'Nội dung đoạn ${i + 1}',
                value: '${segments[i]['text'] ?? ''}',
                lines: 2,
                onChanged: (v) => _change(i, 'text', v),
              ),
              const Divider(),
            ],
          ),
        ),
    ],
  );
}
