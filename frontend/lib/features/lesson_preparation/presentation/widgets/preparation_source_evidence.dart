import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';

/// Teacher-only authoring metadata. Media is opened by the authenticated workspace preview.
class PreparationSourceEvidence extends StatelessWidget {
  const PreparationSourceEvidence({
    super.key,
    required this.item,
    required this.sources,
    required this.onChanged,
    required this.onPreview,
    this.onProbe,
  });
  final PreparationMap item;
  final List<PreparationMap> sources;
  final ValueChanged<List<PreparationMap>> onChanged;
  final void Function(PreparationMap source, double second) onPreview;
  final Future<PreparationMap> Function(PreparationMap source)? onProbe;

  Future<void> _attach(BuildContext context) async {
    PreparationMap? selected = sources.firstOrNull;
    final start = TextEditingController(text: '0');
    final end = TextEditingController(text: '10');
    String? error;
    bool probing = false;
    final reference = await showDialog<PreparationMap>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final timed =
              '${selected?['mimeType']}'.startsWith('video/') ||
              '${selected?['mimeType']}'.startsWith('audio/');
          return AlertDialog(
            title: const Text('Liên kết đoạn nguồn'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selected?['id'] as String?,
                      isExpanded: true,
                      items: sources
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: '${s['id']}',
                              child: Text(
                                '${s['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: probing
                          ? null
                          : (id) => update(() {
                              selected = sources
                                  .where((s) => s['id'] == id)
                                  .firstOrNull;
                              error = null;
                            }),
                    ),
                    if (timed) ...[
                      TextField(
                        controller: start,
                        enabled: !probing,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Từ giây'),
                      ),
                      TextField(
                        controller: end,
                        enabled: !probing,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Đến giây',
                        ),
                      ),
                    ],
                    const Text(
                      'Tham chiếu do giáo viên kiểm chứng; gắn nguồn không tự xác nhận nội dung AI đúng.',
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
              FilledButton(
                onPressed: selected == null || probing
                    ? null
                    : () async {
                        if (probing) return;
                        final chosen = Map<String, dynamic>.from(selected!);
                        final a = double.tryParse(start.text),
                            b = double.tryParse(end.text);
                        if (timed &&
                            (a == null ||
                                b == null ||
                                !a.isFinite ||
                                !b.isFinite ||
                                a < 0 ||
                                b <= a ||
                                b > 7200)) {
                          update(
                            () => error = 'Chọn đoạn hợp lệ trong 0–7200 giây.',
                          );
                          return;
                        }
                        if (timed) {
                          update(() => probing = true);
                          try {
                            final verified = await onProbe?.call(chosen);
                            final duration = verified?['durationSeconds'];
                            if (duration is! num || b! > duration) {
                              if (ctx.mounted) {
                                update(() {
                                  probing = false;
                                  error =
                                      'Đoạn vượt thời lượng nguồn hoặc chưa kiểm được thời lượng.';
                                });
                              }
                              return;
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              update(() {
                                probing = false;
                                error = e.toString();
                              });
                            }
                            return;
                          }
                        }
                        if (!ctx.mounted ||
                            ModalRoute.of(ctx)?.isCurrent != true) {
                          return;
                        }
                        probing = true;
                        Navigator.pop(ctx, <String, dynamic>{
                          'sourceAssetId': chosen['id'],
                          'sourceRevision': chosen['revision'] ?? 0,
                          if (timed) 'start': a,
                          if (timed) 'end': b,
                        });
                      },
                child: const Text('Gắn nguồn'),
              ),
            ],
          );
        },
      ),
    );
    // Route dismissal animation can still reference the fields for one frame.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    start.dispose();
    end.dispose();
    if (reference != null) {
      onChanged([...preparationRows(item['sourceRefs']), reference]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refs = preparationRows(item['sourceRefs']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item['aiAdded'] == true
                  ? 'AI đề xuất — cần giáo viên kiểm chứng'
                  : 'Bằng chứng nguồn',
            ),
            if (refs.isEmpty) const Text('Chưa có nguồn tham chiếu.'),
            for (final (index, ref) in refs.indexed)
              Builder(
                builder: (context) {
                  final source = sources
                      .where((s) => s['id'] == ref['sourceAssetId'])
                      .firstOrNull;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${source?['name'] ?? 'Nguồn không còn khả dụng'}',
                    ),
                    subtitle: Text(
                      'Phiên bản ${ref['sourceRevision']}${ref['start'] == null ? '' : ' · ${ref['start']}–${ref['end']} giây'}',
                    ),
                    onTap: source == null
                        ? null
                        : () => onPreview(
                            source,
                            (ref['start'] as num?)?.toDouble() ?? 0,
                          ),
                    trailing: IconButton(
                      tooltip: 'Gỡ tham chiếu',
                      icon: const Icon(Icons.link_off),
                      onPressed: () => onChanged([...refs]..removeAt(index)),
                    ),
                  );
                },
              ),
            TextButton.icon(
              onPressed: sources.isEmpty || refs.length >= 30
                  ? null
                  : () => _attach(context),
              icon: const Icon(Icons.add_link),
              label: const Text('Gắn nguồn đã kiểm chứng'),
            ),
          ],
        ),
      ),
    );
  }
}
