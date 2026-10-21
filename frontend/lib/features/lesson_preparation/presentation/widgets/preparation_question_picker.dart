import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import '../../services/preparation_controller.dart';

/// Search approved units, preview the whole shared context, and insert atomically.
class PreparationQuestionPicker extends StatefulWidget {
  const PreparationQuestionPicker({super.key, required this.controller});
  final PreparationController controller;
  @override
  State<PreparationQuestionPicker> createState() => _QuestionPickerState();
}

class _QuestionPickerState extends State<PreparationQuestionPicker> {
  final _search = TextEditingController();
  List<PreparationMap> _items = [];
  PreparationMap? _selected;
  bool _loading = true, _inserting = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await widget.controller.api.get(
                'questions?search=${Uri.encodeQueryComponent(_search.text.trim())}',
              )
              as Map;
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = (result['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _selected = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = '$e');
    }
    if (mounted && generation == _generation) setState(() => _loading = false);
  }

  Future<void> _insert() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _inserting = true;
      _error = null;
    });
    final c = widget.controller;
    try {
      await c.save();
      if (c.dirty || c.conflict) {
        throw StateError('Lưu hoặc xử lý xung đột bài trước khi chèn.');
      }
      await c.api.post('${c.path}/question-insert', {
        'questionId': selected['id'],
        'expectedRevision': c.document.revision,
      });
      await c.load();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _inserting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chèn câu hỏi từ kho đã duyệt'),
    content: SizedBox(
      width: 900,
      height: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nhóm dùng chung ngữ cảnh được chèn nguyên nhóm. Đáp án và lời giải nằm trong ghi chú riêng của giáo viên.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            enabled: !_inserting,
            decoration: InputDecoration(
              labelText: 'Tìm nội dung, chủ đề hoặc kỹ năng',
              suffixIcon: IconButton(
                onPressed: _inserting ? null : _load,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(
                    child: Text(
                      'Không có câu hỏi phù hợp. Chỉ nhóm đã duyệt đầy đủ từ nguồn đang hoạt động mới xuất hiện.',
                    ),
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 260,
                        child: ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              selected: _selected?['id'] == item['id'],
                              title: Text(
                                '${item['title']}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${item['questionCount']} câu • ${item['groupId'] == '' ? 'Câu độc lập' : 'Nguyên nhóm'}',
                              ),
                              onTap: _inserting
                                  ? null
                                  : () => setState(() => _selected = item),
                            );
                          },
                        ),
                      ),
                      const VerticalDivider(),
                      Expanded(
                        child: _selected == null
                            ? const Center(
                                child: Text(
                                  'Chọn câu hỏi để xem toàn bộ ngữ cảnh và đáp án.',
                                ),
                              )
                            : SingleChildScrollView(
                                child: SelectionArea(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ('${_selected!['groupContent']}'
                                          .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: Text(
                                            '${_selected!['groupContent']}',
                                          ),
                                        ),
                                      for (final asset
                                          in _selected!['groupAssets']
                                                  as List? ??
                                              [])
                                        _BankImage(
                                          controller: widget.controller,
                                          id: '$asset',
                                        ),
                                      for (final raw
                                          in _selected!['questions'] as List)
                                        _question(
                                          Map<String, dynamic>.from(raw as Map),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _inserting ? null : () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        onPressed: _selected == null || _inserting || _loading ? null : _insert,
        child: Text(
          _inserting
              ? 'Đang chèn…'
              : 'Chèn ${_selected?['questionCount'] ?? ''} câu',
        ),
      ),
    ],
  );
  Widget _question(PreparationMap q) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${q['stem']}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final choice in q['choices'] as List? ?? [])
          Text('${choice['key']}. ${choice['text']}'),
        const SizedBox(height: 8),
        Text(
          'Riêng giáo viên — Đáp án: ${q['answer'] ?? ''}\n${q['solution'] ?? ''}',
        ),
        for (final asset in q['assets'] as List? ?? [])
          _BankImage(controller: widget.controller, id: '$asset'),
      ],
    ),
  );
}

class _BankImage extends StatefulWidget {
  const _BankImage({required this.controller, required this.id});
  final PreparationController controller;
  final String id;
  @override
  State<_BankImage> createState() => _BankImageState();
}

class _BankImageState extends State<_BankImage> {
  late final _bytes = _load();
  Future<Uint8List> _load() async {
    final api = widget.controller.api;
    final headers = await api.headers();
    final response = await api.client
        .get(
          Uri.parse(
            '${api.base}/api/exams/assets/${Uri.encodeComponent(widget.id)}',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));
    return api.check(response).bodyBytes;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Text('Không tải được ảnh câu hỏi.');
      if (!snapshot.hasData) return const LinearProgressIndicator();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Image.memory(
          snapshot.data!,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stack) => const Text('Ảnh không đọc được.'),
        ),
      );
    },
  );
}
