import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/screens/studio_screen.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import '../../domain/models/preparation_document.dart';
import '../../services/preparation_api.dart';
import '../../services/preparation_download.dart';
import '../widgets/preparation_transcript_editor.dart';
import '../widgets/preparation_capabilities_status.dart';
import '../widgets/preparation_authoring_consent.dart';
import '../../services/preparation_controller.dart';
import '../widgets/preparation_editors.dart';
import '../widgets/preparation_transcription_dialog.dart';
import '../widgets/preparation_lesson_checks.dart';
import '../widgets/preparation_recording_control.dart';
import '../widgets/preparation_jobs_panel.dart';
import '../widgets/preparation_media_preview.dart';
import '../widgets/preparation_publish_sheet.dart';
import '../widgets/preparation_tools_sheet.dart';
import '../widgets/preparation_caption_editor.dart';
import '../widgets/preparation_component_installer.dart';
import '../widgets/preparation_question_picker.dart';
import '../widgets/preparation_variant_sheet.dart';
import '../widgets/preparation_export_settings_sheet.dart';
import '../widgets/preparation_question_images.dart';
import '../widgets/preparation_source_evidence.dart';
import '../widgets/preparation_frame_dialog.dart';

part 'preparation_workspace_settings.dart';
part 'preparation_workspace_sources.dart';
part 'preparation_workspace_actions.dart';
part 'preparation_workspace_results.dart';
part 'preparation_workspace_desk.dart';
part 'preparation_workspace_cues.dart';

class PreparationWorkspaceScreen extends StatefulWidget {
  const PreparationWorkspaceScreen({
    super.key,
    required this.planningId,
    required this.title,
    required this.subject,
    required this.onOpenBoard,
    required this.onTeach,
    this.chooseSourceOnOpen = false,
    this.api,
    this.onOpenVariant,
    this.loadBoardContent,
    this.loadPlanningLibrary,
  });
  final String planningId, title, subject;
  final Future<void> Function() onOpenBoard, onTeach;
  final bool chooseSourceOnOpen;
  final PreparationApi? api;
  final Future<void> Function(String)? onOpenVariant;
  final Future<Map<String, dynamic>?> Function()? loadBoardContent;
  final Future<List<PreparationMap>> Function()? loadPlanningLibrary;
  @override
  State<PreparationWorkspaceScreen> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<PreparationWorkspaceScreen> {
  late final PreparationController c;
  int _view = 0, _selection = 0, _sourceMode = 0;
  bool _busy = false;
  String get _input => '${c.document.data['sourceScript'] ?? ''}';
  String get _transcript => '${c.document.data['transcriptText'] ?? ''}';
  @override
  void initState() {
    super.initState();
    c = PreparationController(
      planId: widget.planningId,
      api: widget.api ?? PreparationApi(),
      title: widget.title,
      subject: widget.subject,
    );
    c.addListener(_update);
    c.load().then((_) {
      if (mounted && widget.chooseSourceOnOpen && c.error == null) {
        // The empty desk offers three clear starting actions.
      }
    });
  }

  void _refreshWorkspace(VoidCallback action) {
    if (mounted) setState(action);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_update);
    c.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _saveBeforeLeave() async {
    if (c.activeRecording != null) {
      try {
        await c.api.post('recordings/${c.activeRecording!['id']}/stop');
        c.activeRecording = null;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Chưa dừng được bản ghi: $e')));
        }
        return false;
      }
    }
    await c.save();
    if (!mounted) return false;
    if (!c.dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bài vẫn chưa lưu'),
            content: Text(c.error ?? 'Hãy thử lưu lại trước khi rời bài.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Tiếp tục sửa'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Rời và bỏ phần chưa lưu'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _addSection([String body = '']) {
    c.change((d) {
      final rows = d.rows('sections');
      rows.add({
        'id': PreparationDocument.newId(),
        'title': 'Phần ${rows.length + 1}',
        'body': body,
        'objective': '',
        'teacherNotes': '',
        'minutes': 0,
      });
      d.setRows('sections', rows);
      _selection = rows.length - 1;
    });
    setState(() => _view = 0);
  }

  void _addScene([String text = '']) {
    c.change((d) {
      final rows = d.rows('scenes');
      rows.add({
        'id': PreparationDocument.newId(),
        'title': 'Cảnh ${rows.length + 1}',
        'text': text,
        'narration': text,
        'language': 'en',
        'template': 'slide',
      });
      d.setRows('scenes', rows);
      _selection = rows.length - 1;
    });
    setState(() => _view = 2);
  }

  Future<void> _chooseSource() async {
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Bạn muốn thêm nội dung từ đâu?'),
        children: [
          for (final item in const [
            (0, Icons.article_outlined, 'Văn bản có sẵn'),
            (1, Icons.upload_file_outlined, 'Tài liệu, hình ảnh hoặc bản ghi'),
            (2, Icons.mic_none, 'Ghi âm / quay màn hình'),
            (3, Icons.auto_awesome_outlined, 'Nhờ AI gợi ý nội dung'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, item.$1),
              child: ListTile(leading: Icon(item.$2), title: Text(item.$3)),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _sourceMode = choice;
      _view = 3;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'mp4',
        'mov',
        'webm',
        'wav',
        'mp3',
        'm4a',
        'txt',
        'png',
        'jpg',
        'jpeg',
      ],
    );
    if (result.isEmpty) return;
    await _perform(() async {
      await c.save();
      final source = await c.api.upload(widget.planningId, result.single);
      // Refresh server-managed arrays without discarding unsaved editor fields.
      final fresh = await c.api.get(c.path) as Map;
      final doc = fresh['document'] is Map ? fresh['document'] as Map : fresh;
      c.document.data['sources'] =
          doc['sources'] ?? [...c.document.rows('sources'), source];
      if (mounted) {
        setState(() {
          _view = 3;
          _sourceMode = 1;
        });
      }
    });
  }

  Future<void> _preview(
    PreparationMap asset, {
    double initialPosition = 0,
  }) async {
    await _perform(() async {
      if ((asset['size'] as num? ?? 0) > 20 * 1024 * 1024) {
        final download = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('File lớn hơn giới hạn xem trước 20 MB'),
            content: const Text(
              'Lưu file theo luồng trên Windows để xem bằng trình phát của máy, tránh tải toàn video vào bộ nhớ app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Đóng'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lưu file'),
              ),
            ],
          ),
        );
        if (download == true) await downloadPreparationAsset(c.api, asset);
        return;
      }
      final bytes = await c.api.bytes('${asset['id']}');
      if (!mounted) return;
      final mime =
          '${asset['mimeType'] ?? asset['mime'] ?? 'application/octet-stream'}';
      String? subtitleText;
      if (mime.startsWith('video/')) {
        for (final job in c.jobs) {
          final result = job['result'];
          if (result is! Map) continue;
          final artifacts = preparationRows(result['artifacts']);
          if (!artifacts.any((a) => a['id'] == asset['id'])) continue;
          final subtitle = artifacts
              .where((a) => '${a['name']}'.toLowerCase().endsWith('.srt'))
              .firstOrNull;
          if (subtitle != null &&
              (subtitle['size'] as num? ?? 1000001) <= 1000000) {
            final data = await c.api.bytes('${subtitle['id']}');
            if (data.length <= 1000000) subtitleText = utf8.decode(data);
          }
          break;
        }
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: SizedBox(
            width: 1000,
            height: 650,
            child: Column(
              children: [
                ListTile(
                  title: Text('${asset['name'] ?? 'Xem trước'}'),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: mime.startsWith('text/')
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(utf8.decode(bytes)),
                        )
                      : PreparationMediaPreview(
                          bytes: bytes,
                          mime: mime,
                          initialPosition: initialPosition,
                          subtitleText: subtitleText,
                        ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final path = await FilePicker.saveFile(
                      dialogTitle: 'Lưu học liệu',
                      fileName: '${asset['name'] ?? 'hoc-lieu'}',
                      bytes: bytes,
                    );
                    if (path != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã lưu học liệu.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Lưu về máy'),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _run(String kind, {PreparationMap options = const {}}) =>
      _perform(() async {
        await c.run(kind, options: options);
        if (mounted) setState(() => _view = 4);
      });
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !c.dirty && !c.saving && c.activeRecording == null,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && await _saveBeforeLeave() && mounted) {
        setState(() {
          c.dirty = false;
        });
        if (context.mounted) Navigator.pop(context);
      }
    },
    child: Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Soạn bài'),
        actions: [
          IconButton(
            tooltip: 'Xem trước giáo viên và học sinh',
            onPressed: _previewLesson,
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: 'Dạy từ bài này',
            onPressed: () => _workspaceAction('teach'),
            icon: const Icon(Icons.present_to_all_outlined),
          ),
          Tooltip(
            message:
                c.error ??
                (c.dirty ? 'Có thay đổi chưa lưu' : 'Đã lưu trên máy chủ'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  c.statusLabel,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Lưu bài',
            onPressed: c.loading ? null : () => _perform(c.save),
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Kiểm tra thành phần',
            onPressed: _settings,
            icon: const Icon(Icons.tune),
          ),
          PopupMenuButton<String>(
            tooltip: 'Xuất và sử dụng',
            onSelected: _workspaceAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Tạo PDF học sinh')),
              PopupMenuItem(
                value: 'teacher_pdf',
                child: Text('Tạo PDF giáo viên (riêng tư)'),
              ),
              PopupMenuItem(
                value: 'export_template',
                child: Text('Mẫu trường/khoa & preview PDF'),
              ),
              PopupMenuItem(
                value: 'questions',
                child: Text('Chèn câu hỏi đã duyệt'),
              ),
              PopupMenuItem(
                value: 'variant',
                child: Text('Biến thể bài theo lớp'),
              ),
              PopupMenuItem(
                value: 'render',
                child: Text('Dựng video animation'),
              ),
              PopupMenuItem(
                value: 'publish',
                child: Text('Xuất / Đăng Classroom'),
              ),
              PopupMenuItem(value: 'teach', child: Text('Dạy từ bài này')),
              PopupMenuItem(
                value: 'tools',
                child: Text('Lịch sử & công cụ bài'),
              ),
            ],
          ),
        ],
      ),
      body: c.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (c.document.data['variant'] is Map) _variantBanner(),
                if (c.loaded && !c.dirty && c.hasLocalDraft)
                  MaterialBanner(
                    content: const Text(
                      'Có bản nháp trên máy từ lần soạn trước. Bạn muốn khôi phục để kiểm tra hay bỏ bản nháp?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: c.recoverLocalDraft,
                        child: const Text('Khôi phục bản nháp'),
                      ),
                      TextButton(
                        onPressed: c.discardLocalDraft,
                        child: const Text('Bỏ bản nháp'),
                      ),
                    ],
                  ),
                if (c.recoveryError != null)
                  MaterialBanner(
                    content: const Text(
                      'Chưa ghi được bản nháp trên máy. Hãy lưu lên máy chủ trước khi thoát.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: c.save,
                        child: const Text('Thử lưu'),
                      ),
                    ],
                  ),
                if (c.error != null)
                  MaterialBanner(
                    content: Text(c.error!),
                    actions: [
                      if (c.conflict)
                        TextButton(
                          onPressed: _compareVersions,
                          child: const Text('So sánh hai bản'),
                        ),
                      if (c.conflict)
                        TextButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text: const JsonEncoder.withIndent(
                                '  ',
                              ).convert(c.document.data),
                            ),
                          ),
                          child: const Text('Sao chép bản đang sửa'),
                        ),
                      TextButton(
                        onPressed: () async {
                          if (!c.dirty || await _confirmReload()) {
                            if (c.dirty) {
                              await c.reloadDiscardingChanges();
                            } else {
                              await c.load();
                            }
                          }
                        },
                        child: const Text('Tải lại'),
                      ),
                    ],
                  ),
                _deskToolbar(),
                Expanded(child: !c.loaded ? _loadFailure() : _body()),
              ],
            ),
    ),
  );
  Future<bool> _confirmReload() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tải bản đã lưu?'),
          content: const Text(
            'Thao tác này thay thế phần chưa lưu. Nếu có xung đột, hãy sao chép bản đang sửa trước.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Giữ bản đang sửa'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tải lại'),
            ),
          ],
        ),
      ) ??
      false;
  Widget _body() {
    if (_view == 4) {
      return PreparationJobsPanel(
        controller: c,
        onCreatePdf: () => _workspaceAction('pdf'),
        onApply: (j) => _perform(() => _apply(j)),
        onPreview: _preview,
        onAction: (id, action) => _perform(() => c.jobAction(id, action)),
      );
    }
    if (_view == 3) return _sources();
    if (_view == 0) return _lessonDesk();
    final key = 'scenes';
    final rows = c.document.rows(key);
    if (_selection >= rows.length) {
      _selection = rows.isEmpty ? 0 : rows.length - 1;
    }
    final nav = ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => _view == 2 ? _addScene() : _addSection(),
            icon: const Icon(Icons.add),
            label: Text(_view == 2 ? 'Thêm cảnh' : 'Thêm phần'),
          ),
        ),
        for (var i = 0; i < rows.length; i++)
          ListTile(
            selected: i == _selection,
            title: Text('${rows[i]['title'] ?? 'Chưa đặt tên'}', maxLines: 2),
            leading: Text('${i + 1}'),
            onTap: () => setState(() => _selection = i),
          ),
        if (_view == 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tổng: ${rows.fold<int>(0, (n, r) => n + ((r['minutes'] as num?)?.toInt() ?? 0))} phút',
            ),
          ),
      ],
    );
    final editor = rows.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _view == 2
                      ? 'Tạo cảnh chữ, sơ đồ hoặc hình có giọng đọc.'
                      : 'Bắt đầu bằng nội dung tự soạn hoặc nguồn có sẵn.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _chooseSource,
                  child: const Text('Chọn nguồn / tạo bài'),
                ),
                if (_view == 2)
                  TextButton(
                    onPressed: () => _addScene(),
                    child: const Text('Thêm cảnh trống'),
                  ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    if (_view == 0)
                      PreparationLessonChecks(
                        document: c.document,
                        onTargetChanged: (v) =>
                            c.change((d) => d.data['targetMinutes'] = v),
                      ),
                    if (_view == 0)
                      PreparationSectionEditor(
                        key: ValueKey(rows[_selection]['id']),
                        section: rows[_selection],
                        onChange: (field, value) => _editRow(key, field, value),
                        onDelete: () => _deleteRow(key),
                      )
                    else ...[
                      SwitchListTile(
                        title: const Text('Khóa nội dung cảnh đã duyệt'),
                        subtitle: const Text(
                          'Mở khóa và lưu trước khi sửa, dịch hoặc xóa. Vẫn có thể dựng và sửa phụ đề.',
                        ),
                        value: rows[_selection]['locked'] == true,
                        onChanged: c.saving
                            ? null
                            : (value) => _perform(() async {
                                _editRow(key, 'locked', value);
                                await c.save();
                              }),
                      ),
                      IgnorePointer(
                        ignoring: rows[_selection]['locked'] == true,
                        child: Opacity(
                          opacity: rows[_selection]['locked'] == true ? .55 : 1,
                          child: PreparationSceneEditor(
                            key: ValueKey(rows[_selection]['id']),
                            scene: rows[_selection],
                            voice: '${c.document.data['voice'] ?? 'af_heart'}',
                            onVoiceChanged: (v) => c.change((d) {
                              d.data['voice'] = v;
                              final scenes = d.rows('scenes');
                              for (final scene in scenes) {
                                scene['captionsReviewed'] = false;
                                scene.remove('audioDuration');
                              }
                              d.setRows('scenes', scenes);
                            }),
                            onChange: (field, value) =>
                                _editRow(key, field, value),
                            onDelete: () => _deleteRow(key),
                            onAction: (kind) => _run(
                              kind,
                              options: {
                                'text': kind == 'speech'
                                    ? rows[_selection]['narration']
                                    : rows[_selection]['text'],
                                'sceneId': rows[_selection]['id'],
                                'language': kind == 'translate' ? 'vi' : 'en',
                                'voice': c.document.data['voice'] ?? 'af_heart',
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                    PreparationSourceEvidence(
                      onProbe: (source) async => Map<String, dynamic>.from(
                        await c.api.post(
                              '${c.path}/sources/${source['id']}/probe',
                            )
                            as Map,
                      ),
                      item: rows[_selection],
                      sources: c.document.rows('sources'),
                      onChanged: (refs) => _editRow(key, 'sourceRefs', refs),
                      onPreview: (source, second) =>
                          _preview(source, initialPosition: second),
                    ),
                    if (_view == 0)
                      PreparationQuestionImages(section: rows[_selection]),
                    if (_view == 2)
                      PreparationCaptionEditor(
                        key: ValueKey(
                          'captions-${rows[_selection]['id']}-${jsonEncode(rows[_selection]['captions'])}',
                        ),
                        scene: rows[_selection],
                        onCommit: (fields) => c.change((d) {
                          final scenes = d.rows('scenes');
                          scenes[_selection].addAll(fields);
                          d.setRows('scenes', scenes);
                        }),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Đưa lên',
                          onPressed: _selection > 0
                              ? () => _moveRow(key, -1)
                              : null,
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Đưa xuống',
                          onPressed: _selection < rows.length - 1
                              ? () => _moveRow(key, 1)
                              : null,
                          icon: const Icon(Icons.arrow_downward),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
    return LayoutBuilder(
      builder: (_, size) => size.maxWidth < 760
          ? Column(
              children: [
                SizedBox(height: 150, child: nav),
                const Divider(height: 1),
                Expanded(child: editor),
              ],
            )
          : Row(
              children: [
                SizedBox(width: 240, child: nav),
                const VerticalDivider(width: 1),
                Expanded(child: editor),
              ],
            ),
    );
  }

  void _editRow(String key, String field, dynamic value) => c.change((d) {
    final rows = d.rows(key);
    if (key == 'scenes' &&
        rows[_selection]['locked'] == true &&
        field != 'locked') {
      return;
    }
    rows[_selection][field] = value;
    if (key == 'scenes' && (field == 'narration' || field == 'language')) {
      rows[_selection]['captionsReviewed'] = false;
      rows[_selection].remove('audioDuration');
    }
    d.setRows(key, rows);
  });
  Future<void> _deleteRow(String key) async {
    final before = c.document.copy();
    final original = before.rows(key);
    if (_selection >= original.length) return;
    final index = _selection;
    final removed = original[index];
    if (key == 'scenes' && removed['locked'] == true) return;
    final linkedCues = before
        .rows('teacherCues')
        .where((cue) => key == 'sections' && cue['activityId'] == removed['id'])
        .toList();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa ${removed['title'] ?? 'phần này'}?'),
        content: Text(
          linkedCues.isEmpty
              ? 'Nội dung và liên kết tài liệu của phần này sẽ được bỏ khỏi dàn ý. Tài liệu gốc vẫn được giữ.'
              : 'Có ${linkedCues.length} lời nhắc theo trang gắn với phần này. Bạn muốn giữ chúng làm lời nhắc chung của trang, hay xóa cùng phần?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Giữ lại'),
          ),
          if (linkedCues.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Giữ lời nhắc theo trang'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Text(
              linkedCues.isEmpty ? 'Xóa phần' : 'Xóa phần và lời nhắc',
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final undoCues = [
      ...linkedCues,
      if (choice == 'keep')
        ...before
            .rows('teacherCues')
            .where(
              (cue) =>
                  cue['activityId'] == null &&
                  linkedCues.any(
                    (linked) =>
                        _sameCueLocator(linked['locator'], cue['locator']),
                  ),
            ),
    ];
    c.change((d) {
      final rows = d.rows(key);
      rows.removeWhere((row) => row['id'] == removed['id']);
      d.setRows(key, rows);
      final cues = d.rows('teacherCues');
      if (choice == 'keep') {
        for (final cue
            in cues
                .where((cue) => cue['activityId'] == removed['id'])
                .toList()) {
          final common = cues
              .where(
                (other) =>
                    other['activityId'] == null &&
                    _sameCueLocator(other['locator'], cue['locator']),
              )
              .firstOrNull;
          if (common == null) {
            cue.remove('activityId');
          } else {
            common['text'] = '${common['text'] ?? ''}\n${cue['text'] ?? ''}';
            cues.removeWhere((other) => other['id'] == cue['id']);
          }
        }
      } else {
        cues.removeWhere(
          (cue) => key == 'sections' && cue['activityId'] == removed['id'],
        );
      }
      d.setRows('teacherCues', cues);
      _selection = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã xóa khỏi dàn ý.'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            c.change((d) {
              final rows = d.rows(key);
              if (!rows.any((row) => row['id'] == removed['id'])) {
                rows.insert(index.clamp(0, rows.length), removed);
              }
              d.setRows(key, rows);
              final ids = undoCues.map((cue) => cue['id']).toSet();
              final cues = d.rows('teacherCues')
                ..removeWhere((cue) => ids.contains(cue['id']));
              cues.addAll(undoCues);
              d.setRows('teacherCues', cues);
            });
          },
        ),
      ),
    );
  }

  void _moveRow(String key, int delta) => c.change((d) {
    final rows = d.rows(key);
    final item = rows.removeAt(_selection);
    _selection += delta;
    rows.insert(_selection, item);
    d.setRows(key, rows);
  });
}
