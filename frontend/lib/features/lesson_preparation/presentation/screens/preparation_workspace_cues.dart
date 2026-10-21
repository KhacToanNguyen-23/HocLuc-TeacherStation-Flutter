part of 'preparation_workspace_screen.dart';

extension _WorkspaceCues on _WorkspaceState {
  Widget _orphanCueList(
    List<PreparationMap> targets,
    PreparationMap? selectedTarget,
    StateSetter refresh,
  ) {
    final orphaned = c.document
        .rows('teacherCues')
        .where(
          (cue) => !targets.any(
            (target) => _sameCueLocator(target['locator'], cue['locator']),
          ),
        )
        .toList();
    if (orphaned.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Lời nhắc cần gắn lại trang',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const Text(
          'Trang cũ đã bị xóa hoặc nội dung PDF thay đổi. Các lời nhắc này được giữ riêng và sẽ không tự hiện nhầm trang.',
        ),
        for (final cue in orphaned)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${cue['text'] ?? ''}'),
            subtitle: Wrap(
              children: [
                if (selectedTarget != null)
                  TextButton(
                    onPressed: () => refresh(
                      () => c.change((d) {
                        final rows = d.rows('teacherCues');
                        final target = rows
                            .where((row) => row['id'] == cue['id'])
                            .firstOrNull;
                        if (target != null) {
                          final existing = rows
                              .where(
                                (row) =>
                                    row['id'] != cue['id'] &&
                                    row['activityId'] == cue['activityId'] &&
                                    _sameCueLocator(
                                      row['locator'],
                                      selectedTarget,
                                    ),
                              )
                              .firstOrNull;
                          if (existing != null) {
                            existing['text'] =
                                '${existing['text'] ?? ''}\n${cue['text'] ?? ''}';
                            rows.removeWhere((row) => row['id'] == cue['id']);
                          } else {
                            target['locator'] = Map<String, dynamic>.from(
                              selectedTarget,
                            );
                          }
                          d.setRows('teacherCues', rows);
                          if (cue['activityId'] != null) {
                            final sections = d.rows('sections');
                            for (final section in sections) {
                              if (section['id'] == cue['activityId']) {
                                final linked =
                                    preparationRows(
                                      section['presentationTargets'],
                                    )..removeWhere(
                                      (loc) =>
                                          _sameCueLocator(loc, cue['locator']),
                                    );
                                if (!linked.any(
                                  (loc) => _sameCueLocator(loc, selectedTarget),
                                )) {
                                  linked.add(
                                    Map<String, dynamic>.from(selectedTarget),
                                  );
                                }
                                section['presentationTargets'] = linked;
                                if (_sameCueLocator(
                                  section['presentationTarget'],
                                  cue['locator'],
                                )) {
                                  section['presentationTarget'] =
                                      selectedTarget;
                                }
                              }
                            }
                            d.setRows('sections', sections);
                          }
                        }
                      }),
                    ),
                    child: const Text('Gắn vào trang đang chọn'),
                  ),
                TextButton(
                  onPressed: () => refresh(
                    () => c.change(
                      (d) => d.setRows(
                        'teacherCues',
                        d.rows('teacherCues')
                          ..removeWhere((row) => row['id'] == cue['id']),
                      ),
                    ),
                  ),
                  child: const Text('Xóa lời nhắc này'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _editPageCues() async {
    final local = LocalService();
    Map<String, dynamic>? content;
    try {
      final raw = widget.loadBoardContent == null
          ? await local.getPlanningContent(widget.planningId)
          : await widget.loadBoardContent!();
      if (raw != null) content = Map<String, dynamic>.from(raw);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa đọc được các trang. Hãy lưu bảng và thử lại.'),
          ),
        );
      }
      return;
    } finally {
      local.client.close();
    }
    if (!mounted) return;
    final targets = <PreparationMap>[];
    final ids = content?['pageIds'] as List? ?? [];
    final titles = content?['pageTitles'] as List? ?? [];
    for (var i = 0; i < ids.length; i++) {
      targets.add({
        'label': 'Bảng ${i + 1}${i < titles.length ? ': ${titles[i]}' : ''}',
        'locator': {'kind': 'board', 'pageId': ids[i]},
      });
    }
    for (final doc in preparationRows(content?['importedPdfDocuments'])) {
      if ('${doc['contentFingerprint'] ?? ''}'.isEmpty) continue;
      for (
        var page = 1;
        page <= ((doc['totalPages'] as num?)?.toInt() ?? 0);
        page++
      ) {
        targets.add({
          'label': '${doc['name']} · trang $page',
          'locator': {
            'kind': 'pdf',
            'documentId': doc['id'],
            'contentFingerprint': doc['contentFingerprint'],
            'pageIndex': page,
          },
        });
      }
    }
    if (targets.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
            title: const Text('Chưa có trang để gắn lời nhắc'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mở Chuẩn bị bảng trình chiếu, tạo trang hoặc thêm PDF rồi lưu. Mỗi trang sẽ có lời nhắc riêng, tự hiện khi bạn dạy đến trang đó.',
                  ),
                  _orphanCueList(targets, null, refresh),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    var selected = 0;
    String? activityId;
    PreparationMap? existing(int index) => c.document
        .rows('teacherCues')
        .where(
          (cue) =>
              _sameCueLocator(cue['locator'], targets[index]['locator']) &&
              cue['activityId'] == activityId,
        )
        .firstOrNull;
    final text = TextEditingController(text: '${existing(0)?['text'] ?? ''}');
    void persistCue() {
      c.change((d) {
        final rows = d.rows('teacherCues');
        final old = rows
            .where(
              (cue) =>
                  _sameCueLocator(
                    cue['locator'],
                    targets[selected]['locator'],
                  ) &&
                  cue['activityId'] == activityId,
            )
            .firstOrNull;
        rows.removeWhere(
          (cue) =>
              _sameCueLocator(cue['locator'], targets[selected]['locator']) &&
              cue['activityId'] == activityId,
        );
        if (text.text.trim().isNotEmpty) {
          final cue = <String, dynamic>{
            'id': old?['id'] ?? PreparationDocument.newId(),
            'locator': targets[selected]['locator'],
            'text': text.text,
          };
          if (activityId != null) {
            cue['activityId'] = activityId;
          }
          rows.add(cue);
        }
        d.setRows('teacherCues', rows);
        if (activityId != null) {
          final sections = d.rows('sections');
          for (final section in sections) {
            if (section['id'] == activityId) {
              final linked = preparationRows(section['presentationTargets']);
              if (section['presentationTarget'] is Map &&
                  !linked.any(
                    (target) =>
                        _sameCueLocator(target, section['presentationTarget']),
                  )) {
                linked.add(
                  Map<String, dynamic>.from(
                    section['presentationTarget'] as Map,
                  ),
                );
              }
              if (!linked.any(
                (target) =>
                    _sameCueLocator(target, targets[selected]['locator']),
              )) {
                linked.add(
                  Map<String, dynamic>.from(
                    targets[selected]['locator'] as Map,
                  ),
                );
              }
              section['presentationTargets'] = linked;
              section['presentationTarget'] ??= targets[selected]['locator'];
            }
          }
          d.setRows('sections', sections);
        }
      });
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Lời nhắc riêng theo trang'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Chọn đúng trang đang chuẩn bị. Khi trình chiếu, panel giáo viên tự đổi theo trang; bạn có thể ghim trong Studio. Nội dung này không gửi cho học sinh.',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Trang trình chiếu',
                    ),
                    items: [
                      for (var i = 0; i < targets.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${targets[i]['label']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() {
                      selected = v!;
                      activityId = null;
                      text.text = '${existing(selected)?['text'] ?? ''}';
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: text,
                    onChanged: (_) => persistCue(),
                    minLines: 5,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: 'Lời nhắc, câu hỏi gợi mở, đáp án riêng',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selected),
                    initialValue: activityId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Gắn trang với phần bài (tùy chọn)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Ghi chú chung của trang'),
                      ),
                      for (final section in c.document.rows('sections'))
                        DropdownMenuItem(
                          value: '${section['id']}',
                          child: Text(
                            '${section['title']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => update(() {
                      activityId = value == '' ? null : value;
                      text.text = '${existing(selected)?['text'] ?? ''}';
                    }),
                  ),
                  _orphanCueList(
                    targets,
                    targets[selected]['locator'] as PreparationMap,
                    (change) => update(() {
                      change();
                      text.text = '${existing(selected)?['text'] ?? ''}';
                    }),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lời nhắc được giữ trong bản nháp khi nhập. Thay nội dung PDF sẽ cần gắn lời nhắc lại để tránh hiện nhầm trang.',
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
              onPressed: () {
                persistCue();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đã cập nhật lời nhắc của trang trong bản nháp.',
                    ),
                  ),
                );
              },
              child: const Text('Lưu lời nhắc trang'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
  }
}

bool _sameCueLocator(dynamic a, dynamic b) =>
    a is Map &&
    b is Map &&
    a.length == b.length &&
    a.entries.every((entry) => b[entry.key] == entry.value);
