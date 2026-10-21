part of 'preparation_workspace_screen.dart';

extension _WorkspaceResults on _WorkspaceState {
  Future<void> _apply(PreparationMap job) async {
    final result = job['result'] is Map
        ? Map<String, dynamic>.from(job['result'] as Map)
        : <String, dynamic>{};
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duyệt kết quả trước khi áp dụng'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: SelectableText(
              '${job['sceneId'] != null && job['kind'] == 'translate' ? 'Áp dụng sẽ thay script lời đọc của cảnh đã chọn.' : 'Kết quả được thêm vào bài, không thay thế phần đã sửa.'}\n${job['revision'] != c.document.revision ? 'Lưu ý: bài hiện tại đã khác bản đầu vào tác vụ.\n' : ''}\n${_resultDescription(result)}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thêm kết quả vào bài'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final sections = preparationRows(result['sections']);
    final scenes = preparationRows(result['scenes']);
    final transcript = result['transcript'];
    if (transcript is List) {
      c.change((d) {
        d.data['transcriptSegments'] = transcript;
        d.data['transcriptSourceId'] = job['sourceId'];
      });
    }
    if (job['kind'] == 'translate' &&
        job['sceneId'] != null &&
        result['text'] != null) {
      if (c.dirty || job['revision'] != c.document.revision) {
        throw StateError('Bài đã đổi; dịch lại cảnh để tránh ghi đè bản sửa.');
      }
      final selected = c.document
          .rows('scenes')
          .where((r) => r['id'] == job['sceneId'])
          .firstOrNull;
      if (selected == null || selected['locked'] == true) {
        throw StateError(
          'Cảnh không còn hoặc đã khóa; không áp dụng kết quả cũ.',
        );
      }
      c.change((d) {
        final rows = d.rows('scenes');
        final target = rows.indexWhere((r) => r['id'] == job['sceneId']);
        if (target >= 0) {
          rows[target]['narration'] = result['text'];
          rows[target]['language'] = 'en';
          rows[target]['captionsReviewed'] = false;
          rows[target].remove('audioDuration');
          d.setRows('scenes', rows);
        }
      });
    } else if (job['kind'] == 'render' && scenes.isNotEmpty) {
      if (c.dirty || job['revision'] != c.document.revision) {
        throw StateError(
          'Bài đã đổi; dựng lại cảnh trước khi áp dụng mốc phụ đề.',
        );
      }
      c.change((d) {
        final rows = d.rows('scenes');
        for (final rendered in scenes) {
          final index = rows.indexWhere((r) => r['id'] == rendered['id']);
          if (index < 0 ||
              rows[index]['narration'] != rendered['captionsNarration']) {
            continue;
          }
          for (final field in [
            'captions',
            'captionsNarration',
            'audioDuration',
          ]) {
            rows[index][field] = rendered[field];
          }
        }
        d.setRows('scenes', rows);
      });
    } else if (sections.isNotEmpty || scenes.isNotEmpty) {
      c.change((d) {
        d.setRows('sections', [
          ...d.rows('sections'),
          ...sections.map((s) => {...s, 'id': PreparationDocument.newId()}),
        ]);
        d.setRows('scenes', [
          ...d.rows('scenes'),
          ...scenes.map((s) => {...s, 'id': PreparationDocument.newId()}),
        ]);
      });
    } else if (result['text'] != null || transcript != null) {
      final text =
          result['text']?.toString() ??
          (transcript is String
              ? transcript
              : preparationRows(
                  transcript,
                ).map((segment) => '${segment['text'] ?? ''}').join('\n'));
      _view = 3;
      _update();
      c.change((d) => d.data['transcriptText'] = text);
    }
    final fresh = await c.api.get(c.path) as Map;
    final doc = fresh['document'] is Map ? fresh['document'] as Map : fresh;
    c.document.data['artifacts'] =
        doc['artifacts'] ?? c.document.rows('artifacts');
    if (mounted) _update();
  }
}

String _resultDescription(PreparationMap result) {
  final sections = preparationRows(result['sections']);
  final scenes = preparationRows(result['scenes']);
  final transcript = preparationRows(result['transcript']);
  return [
    if (result['text'] != null) '${result['text']}',
    for (final section in sections)
      '${section['title'] ?? 'Phần nội dung'}\n${section['body'] ?? ''}',
    for (final scene in scenes)
      '${scene['title'] ?? 'Cảnh video'}\n${scene['text'] ?? ''}\nLời đọc: ${scene['narration'] ?? ''}',
    for (final row in transcript) '${row['text'] ?? ''}',
    for (final asset in preparationRows(result['artifacts']))
      'Tài liệu: ${asset['name'] ?? 'Kết quả đã tạo'}',
  ].join('\n\n');
}
