import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import '../../services/preparation_api.dart';

class PreparationVariantSheet extends StatefulWidget {
  const PreparationVariantSheet({
    super.key,
    required this.api,
    required this.planningId,
    required this.document,
    required this.onCreated,
  });
  final PreparationApi api;
  final String planningId;
  final PreparationDocument document;
  final ValueChanged<String> onCreated;
  @override
  State<PreparationVariantSheet> createState() => _PreparationVariantState();
}

class _PreparationVariantState extends State<PreparationVariantSheet> {
  final _title = TextEditingController(), _notes = TextEditingController();
  List<PreparationMap> _classes = [], _variants = [];
  PreparationMap? _selected;
  String? _error, _googleError;
  bool _loading = true, _busy = false;
  String get _path =>
      'plannings/${Uri.encodeComponent(widget.planningId)}/variants';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final local = await widget.api.get('variant-classes') as Map;
      final variants = preparationRows(await widget.api.get(_path));
      final classes = preparationRows(
        local['classes'],
      ).map((row) => {...row, 'kind': 'local'}).toList();
      if (mounted) {
        setState(() {
          _classes = classes;
          _variants = variants;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadGoogle() async {
    setState(() {
      _busy = true;
      _googleError = null;
    });
    try {
      final response = await widget.api.get('courses') as Map;
      final courses = preparationRows(
        response['courses'],
      ).map((row) => {...row, 'kind': 'google'}).toList();
      if (mounted) {
        setState(() {
          _classes = [
            ..._classes.where((row) => row['kind'] != 'google'),
            ...courses,
          ];
          if (courses.isEmpty) {
            _googleError =
                'Tài khoản chưa có lớp Google Classroom đang hoạt động.';
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _googleError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final selected = _selected;
    if (selected == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await widget.api.post(_path, {
                'expectedRevision': widget.document.revision,
                'classKind': selected['kind'],
                'classId': selected['id'],
                'title': _title.text.trim(),
                'adaptationNotes': _notes.text.trim(),
              })
              as Map;
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated(result['planningId'].toString());
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choose(PreparationMap row) {
    setState(() => _selected = row);
    _title.text = '${widget.document.title} — ${row['name']}';
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 640,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Biến thể theo lớp',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      tooltip: 'Đóng',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tạo bài độc lập từ “${widget.document.title}”, phiên bản ${widget.document.revision}. Nội dung và học liệu được sao chép; lịch sử xử lý và lần đăng thuộc riêng từng bài.',
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _selected == null
                      ? null
                      : '${_selected!['kind']}:${_selected!['id']}',
                  decoration: const InputDecoration(labelText: 'Lớp áp dụng'),
                  isExpanded: true,
                  items: _classes
                      .map(
                        (row) => DropdownMenuItem(
                          value: '${row['kind']}:${row['id']}',
                          child: Text(
                            '${row['name']} · ${row['kind'] == 'google' ? 'Google Classroom' : 'Lớp trong app'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => _choose(
                          _classes.firstWhere(
                            (row) => '${row['kind']}:${row['id']}' == value,
                          ),
                        ),
                ),
                if (_classes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Chưa có lớp trong app. Tạo lớp ở mục quản lý lớp hoặc tải lớp Google Classroom.',
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _loadGoogle,
                    icon: const Icon(Icons.cloud_outlined),
                    label: const Text('Tải lớp Google Classroom'),
                  ),
                ),
                if (_googleError != null)
                  Text(
                    _googleError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Tên biến thể'),
                ),
                TextField(
                  controller: _notes,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 10000,
                  decoration: const InputDecoration(
                    labelText: 'Điều chỉnh riêng cho lớp',
                    hintText:
                        'Trình độ, mục tiêu, ví dụ hoặc thời lượng cần điều chỉnh. Chỉ giáo viên thấy.',
                  ),
                ),
                if (_selected != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Bản mới: ${_selected!['name']} · giữ nguyên bài gốc · chỉnh sửa độc lập.',
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _busy || _selected == null ? null : _create,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.call_split),
                    label: const Text('Tạo và mở biến thể'),
                  ),
                ),
                if (_variants.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Text(
                    'Biến thể đã tạo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  ..._variants.map((row) {
                    final metadata = Map<String, dynamic>.from(
                      row['variant'] as Map,
                    );
                    final target = Map<String, dynamic>.from(
                      metadata['targetClass'] as Map,
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(row['title'].toString()),
                      subtitle: Text(
                        '${target['name']} · từ phiên bản ${metadata['parentRevision']}',
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      enabled: !_busy,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onCreated(row['planningId'].toString());
                      },
                    );
                  }),
                ],
              ],
            ),
    ),
  );
}
