import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/preparation_document.dart';
import '../../services/preparation_controller.dart';

/// Editable field mapping. PDF preview uses precisely the server export pipeline.
class PreparationExportSettingsSheet extends StatefulWidget {
  const PreparationExportSettingsSheet({
    super.key,
    required this.controller,
    required this.onPreview,
  });
  final PreparationController controller;
  final Future<void> Function(PreparationMap artifact) onPreview;
  @override
  State<PreparationExportSettingsSheet> createState() => _ExportState();
}

class _ExportState extends State<PreparationExportSettingsSheet> {
  late PreparationMap _template;
  bool _teacher = false, _busy = false;
  String? _error;
  List<PreparationMap> _library = [];
  String? _selectedTemplate;
  int _templateEpoch = 0;
  String? get _libraryKey {
    final owner = widget.controller.api.session.auth.teacherId;
    return owner == null ? null : 'preparation.exportTemplates.$owner';
  }

  Future<void> _loadLibrary() async {
    try {
      final key = _libraryKey;
      if (key == null) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final list = preparationRows(jsonDecode(prefs.getString(key) ?? '[]'));
      if (mounted) {
        setState(() => _library = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Không đọc được thư viện mẫu: $e');
      }
    }
  }

  Future<void> _storeLibrary({bool remove = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = _libraryKey;
      if (key == null) {
        throw StateError('Đăng nhập để lưu mẫu cá nhân.');
      }
      final name = '${_template['name'] ?? ''}'.trim();
      if (!remove && name.isEmpty) {
        throw StateError('Nhập tên mẫu trước khi lưu vào thư viện.');
      }
      final list = _library.where((e) => e['id'] != _selectedTemplate).toList();
      if (!remove) {
        final id = _selectedTemplate ?? PreparationDocument.newId();
        list.add({
          'id': id,
          'name': name,
          'template': jsonDecode(jsonEncode(_template)),
        });
        _selectedTemplate = id;
      } else {
        _selectedTemplate = null;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, jsonEncode(list))) {
        throw StateError('Không lưu được thư viện mẫu.');
      }
      if (mounted) {
        setState(() => _library = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  static const sources = <String, String>{
    'title': 'Tên bài',
    'subject': 'Môn học',
    'className': 'Lớp (biến thể)',
    'section.title': 'Tên các mục',
    'section.body': 'Nội dung học sinh',
    'section.objective': 'Mục tiêu',
    'section.minutes': 'Thời lượng',
    'teacherNotes': 'Ghi chú / đáp án riêng (chỉ GV)',
    'custom': 'Giá trị tự nhập',
  };
  @override
  void initState() {
    super.initState();
    final raw = widget.controller.document.data['exportTemplate'];
    _template = raw is Map
        ? Map<String, dynamic>.from(raw)
        : {
            'school': '',
            'faculty': '',
            'name': '',
            'fields': <PreparationMap>[],
          };
    _loadLibrary();
    _template['fields'] = preparationRows(
      _template['fields'],
    ).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<PreparationMap> get _fields =>
      _template['fields'] as List<PreparationMap>;
  Future<void> _save({bool preview = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = widget.controller;
      if (jsonEncode(c.document.data['exportTemplate']) !=
          jsonEncode(_template)) {
        c.change(
          (doc) =>
              doc.data['exportTemplate'] = jsonDecode(jsonEncode(_template)),
        );
      }
      await c.save();
      if (c.dirty || c.conflict) {
        throw StateError(c.error ?? 'Chưa lưu được mẫu xuất.');
      }
      if (preview) {
        final job = Map<String, dynamic>.from(
          await c.api.post('${c.path}/jobs', {
                'kind': 'export_pdf',
                'revision': c.document.revision,
                'audience': _teacher ? 'teacher' : 'student',
              })
              as Map,
        );
        PreparationMap? artifact;
        for (var i = 0; i < 90; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) {
            return;
          }
          final status = Map<String, dynamic>.from(
            await c.api.get('jobs/${job['id']}') as Map,
          );
          if (status['status'] == 'failed' || status['status'] == 'cancelled') {
            throw StateError('${status['error'] ?? 'Đã hủy xuất PDF.'}');
          }
          if (status['status'] == 'succeeded') {
            final result = status['result'];
            final list = preparationRows(
              result is Map ? result['artifacts'] : null,
            );
            if (list.isEmpty) {
              throw StateError('PDF chưa sẵn sàng.');
            }
            artifact = list.first;
            break;
          }
        }
        await c.refreshJobs();
        if (artifact == null) {
          throw StateError('PDF đang xử lý. Xem tiến trình trong Tác vụ.');
        }
        if (mounted) {
          await widget.onPreview(artifact);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _text(
    String label,
    String value,
    ValueChanged<String> changed, {
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value,
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
      onChanged: changed,
    ),
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 720,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Mẫu xuất trường / khoa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Đóng',
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            key: ValueKey(_templateEpoch),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Thứ tự trường ánh xạ quyết định nội dung PDF; để trống danh sách để dùng bố cục mặc định. Preview là PDF thật. Bản học sinh bỏ các trường riêng; bản giáo viên luôn có ghi chú / đáp án.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTemplate,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mẫu cá nhân đã lưu',
                    border: OutlineInputBorder(),
                  ),
                  items: _library
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e['id'] as String,
                          child: Text('${e['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (id) {
                          final entry = _library.firstWhere(
                            (e) => e['id'] == id,
                          );
                          final raw =
                              jsonDecode(jsonEncode(entry['template'])) as Map;
                          setState(() {
                            _selectedTemplate = id;
                            _template = Map<String, dynamic>.from(raw);
                            _template['fields'] = preparationRows(
                              _template['fields'],
                            ).map((e) => Map<String, dynamic>.from(e)).toList();
                            _templateEpoch++;
                          });
                        },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : () => _storeLibrary(),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(
                        _selectedTemplate == null
                            ? 'Lưu mẫu cá nhân'
                            : 'Cập nhật mẫu cá nhân',
                      ),
                    ),
                    if (_selectedTemplate != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _storeLibrary(remove: true),
                        child: const Text('Xóa mẫu đã lưu'),
                      ),
                    if (_selectedTemplate != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _selectedTemplate = null),
                        child: const Text('Lưu thành mẫu mới'),
                      ),
                  ],
                ),
                for (final pair in {
                  'school': 'Trường',
                  'faculty': 'Khoa / bộ môn',
                  'name': 'Tên mẫu',
                }.entries)
                  _text(
                    pair.value,
                    '${_template[pair.key] ?? ''}',
                    (v) => _template[pair.key] = v,
                  ),
                for (var i = 0; i < _fields.length; i++)
                  Padding(
                    key: ValueKey(_fields[i]['id']),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _text(
                                'Nhãn trường',
                                '${_fields[i]['label'] ?? ''}',
                                (v) => _fields[i]['label'] = v,
                              ),
                            ),
                            IconButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _fields.removeAt(i)),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Xóa trường',
                            ),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          initialValue:
                              sources.containsKey(_fields[i]['source'])
                              ? _fields[i]['source'] as String
                              : 'custom',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ánh xạ nội dung',
                            border: OutlineInputBorder(),
                          ),
                          items: sources.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _fields[i]['source'] = v),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Chỉ bản giáo viên'),
                          value:
                              _fields[i]['source'] == 'teacherNotes' ||
                              _fields[i]['teacherOnly'] == true,
                          onChanged:
                              _busy || _fields[i]['source'] == 'teacherNotes'
                              ? null
                              : (v) => setState(
                                  () => _fields[i]['teacherOnly'] = v == true,
                                ),
                        ),
                        if (_fields[i]['source'] == 'custom')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _text(
                              'Giá trị',
                              '${_fields[i]['value'] ?? ''}',
                              (v) => _fields[i]['value'] = v,
                              helper:
                                  'Chỉ nhập nội dung công khai nếu xuất bản học sinh.',
                            ),
                          ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy || _fields.length >= 40
                        ? null
                        : () => setState(
                            () => _fields.add({
                              'id': PreparationDocument.newId(),
                              'label': '',
                              'source': 'custom',
                              'value': '',
                            }),
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm trường ánh xạ'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bản riêng giáo viên'),
                  subtitle: const Text(
                    'Có ghi chú, hướng dẫn và đáp án. Chỉ xem / tải; không đăng Classroom.',
                  ),
                  value: _teacher,
                  onChanged: _busy ? null : (v) => setState(() => _teacher = v),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _save(),
                child: const Text('Lưu mẫu'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _save(preview: true),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _teacher ? 'Xem PDF giáo viên' : 'Xem PDF học sinh',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
