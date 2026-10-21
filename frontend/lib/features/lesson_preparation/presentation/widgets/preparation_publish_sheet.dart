import 'dart:async';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/platform/url_opener.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';
import '../../domain/models/preparation_document.dart';
import '../../services/preparation_controller.dart';
import 'preparation_editors.dart';

class PreparationPublishSheet extends StatefulWidget {
  const PreparationPublishSheet({
    super.key,
    required this.controller,
    required this.onPreview,
  });
  final PreparationController controller;
  final ValueChanged<PreparationMap> onPreview;
  @override
  State<PreparationPublishSheet> createState() => _PublishState();
}

class _PublishState extends State<PreparationPublishSheet> {
  final _selected = <String>{};
  List<PreparationMap> _courses = [];
  List<PreparationMap> _publications = [];
  String? _course, _error;
  String? _message;
  Timer? _progressTimer;
  bool _readingHistory = false;
  String _description = '';
  bool _confirmed = false, _busy = false, _loadingCourses = true;
  String _requestId = PreparationDocument.newId();
  bool _connecting = false;
  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadPublications();
    widget.controller.addListener(_updated);
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updated);
    _progressTimer?.cancel();
    super.dispose();
  }

  String _status(dynamic value) => switch ('$value') {
    'uploading' => 'Đang tải file lên Drive',
    'creating' => 'Đang tạo học liệu Classroom',
    'uncertain' => 'Cần đối soát — chưa đăng lại',
    'published' => 'Đã đăng',
    'failed' => 'Chưa hoàn tất — có thể tiếp tục',
    _ => '$value',
  };

  void _result(dynamic result) {
    if (result is! Map) {
      _message = 'Đã nhận phản hồi; xem lịch sử đăng.';
      return;
    }
    _message = _status(result['status']);
    if (result['error'] != null) _error = '${result['error']}';
  }

  bool _publicLink(dynamic raw) {
    final uri = Uri.tryParse('$raw');
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'classroom.google.com';
  }

  Future<void> _deleteUnused(PreparationMap asset) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bản xuất chưa dùng?'),
        content: Text(
          'Xóa ${asset['name']} khỏi ổ đĩa. Bản đang dùng trong bài, tác vụ hoặc lần đăng Classroom sẽ được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa bản xuất'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = widget.controller;
      await c.save();
      if (c.dirty || c.conflict) throw StateError('Cần lưu bài trước khi xóa.');
      await c.api.request(
        'assets/${Uri.encodeComponent('${asset['id']}')}',
        'DELETE',
      );
      final value = await c.api.get(c.path) as Map;
      final data = value['document'] is Map ? value['document'] as Map : value;
      c.document.data['artifacts'] = data['artifacts'];
      _selected.remove('${asset['id']}');
      c.emit();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> _checks(List<PreparationMap> artifacts) {
    final c = widget.controller;
    final selected = artifacts
        .where((a) => _selected.contains('${a['id']}'))
        .toList();
    return [
      if (_selected.isEmpty) 'Chọn học liệu cần đăng.',
      if (_selected.length > 20) 'Mỗi lần đăng tối đa 20 file.',
      if (selected.length != _selected.length)
        'Có file không còn tồn tại trong bài.',
      if (selected.any(
        (a) => a['external'] != true && a['revision'] != c.document.revision,
      ))
        'Có bản xuất cũ: tạo lại sau khi lưu bản hiện tại.',
      if (c.dirty || c.saving || c.conflict)
        'Lưu và giải quyết xung đột trước khi chọn bản xuất.',
      if (_course == null) 'Chọn lớp Classroom.',
      if (!_confirmed) 'Xem trước và xác nhận nội dung phù hợp với học sinh.',
    ];
  }

  Future<void> _loadPublications() async {
    if (_readingHistory) return;
    _readingHistory = true;
    try {
      final c = widget.controller;
      final value = await c.api.get(c.path);
      if (value is Map && mounted) {
        final data = value['document'] is Map
            ? value['document'] as Map
            : value;
        setState(() => _publications = preparationRows(data['publications']));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Chưa đọc được lịch sử đăng: $e');
    } finally {
      _readingHistory = false;
    }
  }

  Future<void> _resume(PreparationMap publication) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = 'Đang tiếp tục / đối soát lần đăng gốc…';
    });
    _progressTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadPublications(),
    );
    try {
      final c = widget.controller;
      final result = await c.api.post('${c.path}/publish', {
        'revision': publication['revision'],
        'artifactIds': publication['artifactIds'],
        'courseId': publication['courseId'],
        'title': publication['title'],
        'description': publication['description'] ?? '',
        'requestId': publication['requestId'],
        'externalFilesConfirmed': true,
      });
      if (mounted) setState(() => _result(result));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _progressTimer?.cancel();
      await _loadPublications();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadCourses() async {
    try {
      final result = await widget.controller.api.get('courses');
      if (mounted) {
        setState(
          () => _courses = preparationRows(
            result is Map ? result['courses'] : result,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loadingCourses = false);
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
      _message = 'Đang chờ cấp quyền Google…';
    });
    final api = widget.controller.api;
    final google = GoogleWorkspaceApi(
      email: api.session.auth.teacherEmail ?? '',
      base: api.base,
    );
    try {
      final flow = await api.post('google/connect') as Map;
      await openExternalUrl('${flow['authorizationUrl']}');
      while (mounted &&
          _connecting &&
          DateTime.now().millisecondsSinceEpoch < (flow['expiresAt'] as num)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || !_connecting) break;
        final result = await google.call(
          'poll',
          post: true,
          body: {'state': flow['state'], 'pollToken': flow['pollToken']},
        );
        if (result['status'] == 'COMPLETE') {
          await _loadCourses();
          break;
        }
        if (result['status'] == 'FAILED') {
          throw StateError('${result['message']}');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      google.close();
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
      _message =
          'Đang tải file / đăng; tiến độ từng bước hiển thị trong lịch sử.';
    });
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadPublications(),
    );
    try {
      final c = widget.controller;
      await c.save();
      if (c.dirty || c.conflict) {
        throw StateError('Cần giải quyết lỗi lưu trước khi đăng.');
      }
      final result = await c.api.post('${c.path}/publish', {
        'revision': c.document.revision,
        'artifactIds': _selected.toList(),
        'courseId': _course,
        'title': c.document.title,
        'description': _description,
        'requestId': _requestId,
        'externalFilesConfirmed': _confirmed,
      });
      if (!mounted) return;
      setState(() => _result(result));
      await c.refreshJobs();
      if (result is Map && result['status'] == 'published') {
        _requestId = PreparationDocument.newId();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    _progressTimer?.cancel();
    await _loadPublications();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    const supported = {
      'application/pdf',
      'video/mp4',
      'audio/wav',
      'audio/mpeg',
      'image/png',
      'image/jpeg',
      'application/x-subrip',
      'text/vtt',
    };
    final artifacts =
        [
              ...c.document.rows('artifacts'),
              ...c.document
                  .rows('sources')
                  .where(
                    (s) =>
                        '${s['mimeType']}'.startsWith('application/pdf') ||
                        '${s['mimeType']}'.startsWith('video/') ||
                        '${s['mimeType']}'.startsWith('audio/') ||
                        '${s['mimeType']}'.startsWith('image/'),
                  )
                  .map((s) => {...s, 'external': true}),
            ]
            .where(
              (a) =>
                  supported.contains('${a['mimeType']}') &&
                  a['audience'] != 'teacher' &&
                  a['private'] != true &&
                  a['kind'] != 'question_private',
            )
            .toList();
    final checks = _checks(artifacts);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Xuất / Đăng học liệu',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Chọn bản học sinh đã xem trước. Bản xuất của app tách ghi chú riêng; file tải lên cần giáo viên tự kiểm tra nội dung đã nhúng.',
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final publication in _publications)
                    ListTile(
                      title: Text(
                        '${publication['title']} — ${_status(publication['status'])}',
                      ),
                      subtitle: Text(
                        'Lớp ${publication['courseId']} · bản ${publication['revision']}\nĐã tải ${publication['driveFiles'] is List ? (publication['driveFiles'] as List).length : 0}/${publication['artifactIds'] is List ? (publication['artifactIds'] as List).length : 0} file${publication['error'] == null ? '' : '\n${publication['error']}'}',
                      ),
                      trailing: publication['status'] == 'published'
                          ? (_publicLink(publication['url'])
                                ? IconButton(
                                    tooltip: 'Mở học liệu Classroom',
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () => openExternalUrl(
                                      '${publication['url']}',
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline))
                          : TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _resume(publication),
                              child: const Text('Tiếp tục / đối soát'),
                            ),
                    ),
                  if (artifacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Chưa có học liệu phù hợp. Thêm file PDF/audio/video hoặc tạo bản xuất; không bắt buộc dựng video.',
                      ),
                    ),
                  for (final a in artifacts)
                    CheckboxListTile(
                      value: _selected.contains('${a['id']}'),
                      onChanged:
                          _busy ||
                              (a['external'] != true &&
                                  a['revision'] != null &&
                                  a['revision'] != c.document.revision)
                          ? null
                          : (v) => setState(() {
                              if (v == true) {
                                _selected.add('${a['id']}');
                              } else {
                                _selected.remove('${a['id']}');
                              }
                              _confirmed = false;
                              _requestId = PreparationDocument.newId();
                            }),
                      title: Text('${a['name'] ?? a['kind'] ?? a['id']}'),
                      subtitle: Text(
                        a['external'] != true &&
                                a['revision'] != null &&
                                a['revision'] != c.document.revision
                            ? 'Bản cũ — cần tạo lại'
                            : 'Bản hiện tại',
                      ),
                      secondary: PopupMenuButton<String>(
                        tooltip: 'Tùy chọn học liệu',
                        enabled: !_busy,
                        onSelected: (action) => action == 'preview'
                            ? widget.onPreview(a)
                            : _deleteUnused(a),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'preview',
                            child: Text('Xem trước'),
                          ),
                          if (a['external'] != true)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa bản xuất chưa dùng'),
                            ),
                        ],
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ),
                  const Divider(),
                  Text(
                    'Kiểm tra trước đăng',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final check in checks)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• $check'),
                    ),
                  if (checks.isEmpty)
                    const Text(
                      'Đã kiểm tra bản xuất, lớp và xác nhận của giáo viên. Quyền mở file của học sinh vẫn cần kiểm thực sau đăng.',
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _connecting
                          ? () => setState(() => _connecting = false)
                          : _connect,
                      icon: const Icon(Icons.link),
                      label: Text(
                        _connecting
                            ? 'Đang chờ Google — Dừng chờ'
                            : 'Kết nối / cấp quyền Classroom',
                      ),
                    ),
                  ),
                  if (_loadingCourses)
                    const LinearProgressIndicator()
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _course,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Lớp Google Classroom',
                        border: OutlineInputBorder(),
                      ),
                      items: _courses
                          .map(
                            (r) => DropdownMenuItem(
                              value: '${r['id']}',
                              child: Text(
                                '${r['name'] ?? r['id']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                              _course = v;
                              _requestId = PreparationDocument.newId();
                            }),
                    ),
                  const SizedBox(height: 16),
                  PreparationField(
                    label: 'Mô tả học liệu',
                    value: _description,
                    lines: 2,
                    onChanged: (v) {
                      _description = v;
                      _requestId = PreparationDocument.newId();
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmed,
                    title: const Text(
                      'Tôi đã xem và xác nhận các file được chọn phù hợp để chia sẻ cho học sinh.',
                    ),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _confirmed = v ?? false),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SelectableText(_error!),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SelectableText(_message!),
                    ),
                  if (_busy) const LinearProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || checks.isNotEmpty ? null : _publish,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
              label: Text(
                _busy ? 'Đang đăng / đối soát…' : 'Đăng lên Classroom',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
