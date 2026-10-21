import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/preparation_document.dart';
import '../../domain/models/preparation_scene_dependencies.dart';
import '../../services/preparation_controller.dart';

/// Optional tools stay inside a lesson, rather than adding another workspace.
class PreparationToolsSheet extends StatefulWidget {
  const PreparationToolsSheet({
    super.key,
    required this.controller,
    this.onOpenDraft,
  });
  final PreparationController controller;
  final Future<void> Function(String)? onOpenDraft;
  @override
  State<PreparationToolsSheet> createState() => _PreparationToolsState();
}

class _PreparationToolsState extends State<PreparationToolsSheet> {
  List<PreparationMap> _revisions = [], _blocks = [];
  bool _busy = false;
  String? _error;
  PreparationController get c => widget.controller;

  String get _libraryKey {
    final owner = c.api.session.auth.teacherId;
    if (owner == null) throw StateError('Chưa xác định tài khoản giáo viên.');
    return 'preparation.blocks.$owner';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final revisions = preparationRows(await c.api.get('${c.path}/revisions'));
      final prefs = await SharedPreferences.getInstance();
      final blocks = preparationRows(
        jsonDecode(prefs.getString(_libraryKey) ?? '[]'),
      );
      if (mounted) {
        setState(() {
          _revisions = revisions;
          _blocks = blocks;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _action(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<List<String>?> _input(
    String title,
    String first,
    String second,
  ) async {
    final a = TextEditingController(), b = TextEditingController();
    final value = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: a,
                decoration: InputDecoration(labelText: first),
                maxLength: 100,
              ),
              TextField(
                controller: b,
                decoration: InputDecoration(labelText: second),
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (a.text.trim().isNotEmpty && b.text.trim().isNotEmpty) {
                Navigator.pop(context, [a.text.trim(), b.text.trim()]);
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    // Dispose only after the dialog has finished its exit animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    a.dispose();
    b.dispose();
    return value;
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_libraryKey, jsonEncode(_blocks))) {
      throw StateError('Không lưu được thư viện tại máy.');
    }
  }

  Future<void> _draftFromReflection(PreparationMap reflection) async {
    await c.save();
    if (c.dirty || c.conflict) {
      throw StateError('Lưu bài trước khi tạo bản sửa.');
    }
    final copy = Map<String, dynamic>.from(
      await c.api.post('${c.path}/duplicate', {}) as Map,
    );
    final id = '${copy['planningId']}';
    copy['title'] = '${c.document.title} — bản sửa';
    copy['revisionTasks'] = [
      ...preparationRows(copy['revisionTasks']),
      {
        ...reflection,
        'id': PreparationDocument.newId(),
        'reflectionId': reflection['id'],
        'done': false,
      },
    ];
    copy.remove('planningId');
    await c.api.put('plannings/$id', {
      'expectedRevision': copy['revision'] ?? 0,
      'document': copy,
    });
    if (!mounted) return;
    Navigator.pop(context);
    await widget.onOpenDraft?.call(id);
  }

  Future<void> _insertLibraryBlock(PreparationMap block) async {
    if (block['sourcePlanningId'] != null && block['sourceSectionId'] != null) {
      await c.save();
      if (c.dirty || c.conflict) {
        throw StateError('Lưu bài trước khi chèn phần.');
      }
      await c.api.post('${c.path}/reuse-section', {
        'expectedRevision': c.document.revision,
        'sourcePlanningId': block['sourcePlanningId'],
        'sectionId': block['sourceSectionId'],
        'sourceRevision': block['sourceRevision'],
      });
      await c.load();
      return;
    }
    if (block['questionBank'] != null || block['sourceRefs'] != null) {
      throw StateError(
        'Phần cũ có tham chiếu tài sản. Mở bài nguồn và lưu lại vào thư viện trước khi chèn.',
      );
    }
    c.change(
      (d) => d.setRows('sections', [
        ...d.rows('sections'),
        {...block, 'id': PreparationDocument.newId()},
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: Column(
        children: [
          ListTile(
            title: const Text('Lịch sử và công cụ bài'),
            trailing: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView(
              children: [
                ExpansionTile(
                  title: const Text('Lịch sử phiên bản'),
                  children: [
                    if (_revisions.isEmpty)
                      const ListTile(title: Text('Chưa có bản lưu trước đó.')),
                    for (final r in _revisions)
                      ListTile(
                        title: Text(
                          'Phiên bản ${r['revision']} — ${r['title']}',
                        ),
                        subtitle: Text(
                          '${preparationRows(r['sections']).length} phần · ${preparationRows(r['scenes']).length} cảnh',
                        ),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _action(() async {
                                  await c.save();
                                  if (c.dirty || c.conflict) {
                                    throw StateError(
                                      'Lưu phần đang sửa trước khi khôi phục.',
                                    );
                                  }
                                  if (!context.mounted) return;
                                  final yes = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Khôi phục thành bản mới?',
                                      ),
                                      content: const Text(
                                        'Giữ lịch sử hiện tại; video và học liệu của bản cũ không tự trở thành kết quả của bản mới.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Hủy'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Khôi phục'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (yes != true) return;
                                  await c.api.post('${c.path}/restore', {
                                    'revision': r['revision'],
                                    'expectedRevision': c.document.revision,
                                  });
                                  await c.load();
                                  await _load();
                                }),
                          child: const Text('Khôi phục'),
                        ),
                      ),
                  ],
                ),
                ExpansionTile(
                  title: const Text('Thuật ngữ / cách đọc'),
                  children: [
                    const ListTile(
                      subtitle: Text(
                        'Các thay thế bạn duyệt được áp dụng cho lời đọc tiếng Anh. Kiểm tra và nghe thử trước khi xuất.',
                      ),
                    ),
                    for (final row in c.document.rows('glossary'))
                      ListTile(
                        title: Text('${row['term']} → ${row['replacement']}'),
                        trailing: IconButton(
                          tooltip: 'Xóa thuật ngữ',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _busy
                              ? null
                              : () {
                                  c.change((d) {
                                    preparationChangeGlossary(
                                      d,
                                      d
                                          .rows('glossary')
                                          .where(
                                            (r) => r['term'] != row['term'],
                                          )
                                          .toList(),
                                    );
                                  });
                                  setState(() {});
                                },
                        ),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm cách đọc'),
                      onPressed: _busy
                          ? null
                          : () => _action(() async {
                              final values = await _input(
                                'Thuật ngữ',
                                'Từ xuất hiện trong script',
                                'Thay bằng khi đọc',
                              );
                              if (values != null) {
                                c.change((d) {
                                  preparationChangeGlossary(d, [
                                    ...d.rows('glossary'),
                                    {
                                      'term': values[0],
                                      'replacement': values[1],
                                    },
                                  ]);
                                });
                              }
                            }),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text('Nhận xét riêng để sửa bài'),
                  children: [
                    for (final row in c.document.rows('reflections'))
                      ListTile(
                        title: Text('${row['title']}'),
                        subtitle: Text('${row['body']}'),
                        trailing: Wrap(
                          children: [
                            if (widget.onOpenDraft != null)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _action(
                                        () => _draftFromReflection(row),
                                      ),
                                child: const Text('Tạo bản sửa độc lập'),
                              ),
                            TextButton(
                              child: const Text('Đưa vào việc cần sửa'),
                              onPressed: () {
                                c.change(
                                  (d) => d.setRows('revisionTasks', [
                                    ...d.rows('revisionTasks'),
                                    {
                                      ...row,
                                      'id': PreparationDocument.newId(),
                                      'reflectionId': row['id'],
                                      'done': false,
                                    },
                                  ]),
                                );
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    for (final task in c.document.rows('revisionTasks'))
                      CheckboxListTile(
                        title: Text('${task['title']}'),
                        subtitle: Text('${task['body']}'),
                        value: task['done'] == true,
                        onChanged: (v) {
                          c.change((d) {
                            final rows = d.rows('revisionTasks');
                            final index = rows.indexWhere(
                              (r) => r['id'] == task['id'],
                            );
                            if (index >= 0) rows[index] = {...task, 'done': v};
                            d.setRows('revisionTasks', rows);
                          });
                          setState(() {});
                        },
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Ghi nhận xét sau buổi'),
                      onPressed: _busy
                          ? null
                          : () => _action(() async {
                              final value = await _input(
                                'Nhận xét của giáo viên',
                                'Phần cần giữ / đổi',
                                'Điều cần cải thiện lần tới',
                              );
                              if (value != null) {
                                c.change(
                                  (d) => d.setRows('reflections', [
                                    ...d.rows('reflections'),
                                    {
                                      'id': PreparationDocument.newId(),
                                      'title': value[0],
                                      'body': value[1],
                                      'revision': d.revision,
                                      'recordedAt': DateTime.now()
                                          .toIso8601String(),
                                    },
                                  ]),
                                );
                              }
                            }),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text('Thư viện phần bài tại máy'),
                  children: [
                    const ListTile(
                      subtitle: Text(
                        'Theo tài khoản giáo viên. Chèn bản sao, không tự cập nhật các bài khác. Ghi chú vẫn là nội dung riêng.',
                      ),
                    ),
                    for (final section in c.document.rows('sections'))
                      ListTile(
                        title: Text('${section['title']}'),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _action(() async {
                                  await c.save();
                                  if (c.dirty || c.conflict) {
                                    throw StateError(
                                      'Lưu bài trước khi lưu phần vào thư viện.',
                                    );
                                  }
                                  final block =
                                      jsonDecode(jsonEncode(section))
                                          as PreparationMap;
                                  _blocks.add({
                                    ...block,
                                    'id': PreparationDocument.newId(),
                                    'sourcePlanningId': c.planId,
                                    'sourceSectionId': section['id'],
                                    'sourceRevision': c.document.revision,
                                  });
                                  await _saveLibrary();
                                }),
                          child: const Text('Lưu phần'),
                        ),
                      ),
                    for (final block in _blocks)
                      ListTile(
                        title: Text('${block['title']}'),
                        subtitle: const Text('Bản sao trong thư viện cá nhân'),
                        trailing: Wrap(
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(
                                      () => _insertLibraryBlock(block),
                                    ),
                              child: const Text('Chèn'),
                            ),
                            IconButton(
                              tooltip: 'Xóa khỏi thư viện',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _busy
                                  ? null
                                  : () => _action(() async {
                                      _blocks.removeWhere(
                                        (b) => b['id'] == block['id'],
                                      );
                                      await _saveLibrary();
                                    }),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: _busy ? null : () => _action(c.save),
              child: const Text('Lưu bài'),
            ),
          ),
        ],
      ),
    ),
  );
}
