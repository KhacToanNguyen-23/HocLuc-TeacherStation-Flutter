import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/exams/services/exam_api.dart';
import 'package:teaching_companion/features/exams/presentation/exam_widgets.dart';

class QuestionReviewDialog extends StatefulWidget {
  const QuestionReviewDialog({
    super.key,
    required this.api,
    required this.source,
    required this.question,
  });
  final ExamApi api;
  final ExamRow source, question;
  @override
  State<QuestionReviewDialog> createState() => _QuestionReviewDialogState();
}

class _QuestionReviewDialogState extends State<QuestionReviewDialog> {
  late ExamRow question = Map<String, dynamic>.from(widget.question);
  late final Map<String, TextEditingController> fields = {
    for (final key in [
      'stem',
      'section',
      'subsection',
      'topic',
      'skill',
      'cognitiveLevel',
      'answer',
      'solution',
      'acceptedAnswers',
    ])
      key: TextEditingController(
        text: key == 'acceptedAnswers'
            ? ((widget.question[key] as List?) ?? []).join(';')
            : widget.question[key]?.toString() ?? '',
      ),
    for (final key in ['A', 'B', 'C', 'D'])
      key: TextEditingController(
        text:
            examRows(
              widget.question['choices'] ?? [],
            ).where((c) => c['key'] == key).firstOrNull?['text']?.toString() ??
            '',
      ),
  };
  late List<String> images = List<String>.from(
        question['assets'] as List? ?? [],
      ),
      solutions = List<String>.from(question['solutionAssets'] as List? ?? []);
  late String type = question['type']?.toString() ?? 'MCQ',
      difficulty = question['difficulty']?.toString() ?? 'MEDIUM';
  late int page = (question['sourcePage'] as num?)?.toInt() ?? 1;
  late Future<void> loading = load();
  List<ExamRow> pages = [], groups = [];
  List<(String, String)> sections = [];
  Uint8List? pageBytes;
  Rect? crop;
  Offset? start;
  double displayedWidth = 1;
  late String? groupId = questionGroup(widget.question);
  bool solutionCrop = false,
      visualVerified = false,
      answerFree = false,
      busy = false;
  Object? error;
  static String? questionGroup(ExamRow q) => q['groupId']?.toString();
  bool get approved => question['status'] == 'APPROVED';
  Future<void> load() async {
    pages = examRows(
      await widget.api.get('sources/${widget.source['id']}/assets'),
    ).where((a) => a['path'].toString().contains('/page-')).toList();
    groups = examRows(
      await widget.api.get('groups?sourceId=${widget.source['id']}'),
    );
    final matrices = examRows(await widget.api.get('matrices'));
    final map = <String, String>{};
    for (final m in matrices.where(
      (m) =>
          m['examType'] == widget.source['examType'] &&
          m['examVersion'] == widget.source['examVersion'],
    )) {
      for (final q in examRows(m['quotas'])) {
        map[q['section'].toString()] = q['label'].toString();
      }
    }
    sections = map.entries.map((e) => (e.key, e.value)).toList();
    if (pages.isNotEmpty) {
      pageBytes = await widget.api.bytes(
        'assets/${pages.firstWhere((p) => p['page'] == page, orElse: () => pages.first)['id']}',
      );
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save({bool approve = false}) async {
    if (approved) {
      throw StateError('Câu đã duyệt là bất biến. Tạo bản mới để hiệu chỉnh.');
    }
    if (approve && (!visualVerified || !answerFree)) {
      throw StateError('Xác nhận đã soát nội dung và ảnh không chứa đáp án.');
    }
    final body = <String, dynamic>{
      for (final e in fields.entries)
        if (!['A', 'B', 'C', 'D'].contains(e.key)) e.key: e.value.text.trim(),
      'sourceId': widget.source['id'],
      'sourcePage': page,
      'type': type,
      'difficulty': difficulty,
      'groupId': groupId,
      'assets': images,
      'solutionAssets': solutions,
      'choices': type == 'MCQ'
          ? [
              for (final key in ['A', 'B', 'C', 'D'])
                {'key': key, 'text': fields[key]!.text.trim()},
            ]
          : [],
    };
    body['acceptedAnswers'] = fields['acceptedAnswers']!.text
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final result = question['id'] == null
        ? await widget.api.post('admin/questions', body)
        : await widget.api.put('admin/questions/${question['id']}', body);
    question = Map<String, dynamic>.from(result as Map);
    if (approve) {
      question = Map<String, dynamic>.from(
        await widget.api.post('admin/questions/${question['id']}/approve', {
              'visualVerified': visualVerified,
              'answerFree': answerFree,
            })
            as Map,
      );
    }
  }

  Future<void> cut() async {
    if (crop == null || crop!.width < 5 || crop!.height < 5) {
      throw StateError('Kéo chọn vùng cắt trên trang PDF.');
    }
    final asset = pages.firstWhere((p) => p['page'] == page);
    final scale = (asset['width'] as num) / displayedWidth;
    final response = await widget.api.post('admin/assets/crop', {
      'sourceId': widget.source['id'],
      'page': page,
      'x': (crop!.left * scale).round(),
      'y': (crop!.top * scale).round(),
      'width': (crop!.width * scale).round(),
      'height': (crop!.height * scale).round(),
    });
    (solutionCrop ? solutions : images).add(response['id'].toString());
    crop = null;
  }

  Widget textField(String key, String label, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: fields[key],
      enabled: !approved,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Widget imagePane() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<int>(
        initialValue: page,
        decoration: const InputDecoration(labelText: 'Trang PDF'),
        items: pages
            .map(
              (p) => DropdownMenuItem(
                value: (p['page'] as num).toInt(),
                child: Text('Trang ${p['page']}'),
              ),
            )
            .toList(),
        onChanged: busy
            ? null
            : (value) {
                if (value != null) {
                  run(() async {
                    page = value;
                    crop = null;
                    pageBytes = await widget.api.bytes(
                      'assets/${pages.firstWhere((a) => a['page'] == page)['id']}',
                    );
                  });
                }
              },
      ),
      const SizedBox(height: 12),
      if (pageBytes != null)
        LayoutBuilder(
          builder: (context, constraints) {
            displayedWidth = constraints.maxWidth;
            final a = pages.firstWhere((a) => a['page'] == page),
                height =
                    displayedWidth * (a['height'] as num) / (a['width'] as num);
            Offset clamp(Offset p) =>
                Offset(p.dx.clamp(0, displayedWidth), p.dy.clamp(0, height));
            return GestureDetector(
              onPanStart: approved
                  ? null
                  : (d) => setState(() {
                      start = clamp(d.localPosition);
                      crop = null;
                    }),
              onPanUpdate: approved
                  ? null
                  : (d) => setState(
                      () => crop = Rect.fromPoints(
                        start!,
                        clamp(d.localPosition),
                      ),
                    ),
              child: Stack(
                children: [
                  Image.memory(
                    pageBytes!,
                    width: displayedWidth,
                    height: height,
                    fit: BoxFit.fill,
                  ),
                  if (crop != null)
                    Positioned.fromRect(
                      rect: crop!,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.selected.withValues(alpha: .4),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      const SizedBox(height: 12),
      const Text(
        'Kéo vùng cắt để giữ công thức, hình và bảng. Ảnh câu hỏi không chứa đáp án/lời giải.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: solutionCrop,
        onChanged: approved ? null : (v) => setState(() => solutionCrop = v),
        title: const Text('Ảnh lời giải (xuất riêng)'),
      ),
      FilledButton.icon(
        onPressed: approved || busy ? null : () => run(cut),
        icon: const Icon(Icons.crop, size: 18),
        label: const Text('Cắt & thêm ảnh'),
      ),
      const SizedBox(height: 12),
      for (final (index, id) in images.indexed)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Ảnh câu hỏi ${index + 1}'),
          trailing: IconButton(
            onPressed: approved
                ? null
                : () => setState(() => images.remove(id)),
            icon: const Icon(Icons.close),
          ),
        ),
      for (final (index, id) in solutions.indexed)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Ảnh lời giải ${index + 1}'),
          trailing: IconButton(
            onPressed: approved
                ? null
                : () => setState(() => solutions.remove(id)),
            icon: const Icon(Icons.close),
          ),
        ),
      OutlinedButton.icon(
        onPressed: approved || busy
            ? null
            : () => run(() async {
                final input = await examForm(context, 'Tạo ngữ cảnh chung', [
                  ExamInput('section', 'Phần thi', options: sections),
                  const ExamInput(
                    'content',
                    'Nội dung ngữ cảnh',
                    required: false,
                    lines: 3,
                  ),
                ]);
                if (input == null) return;
                input['sourceId'] = widget.source['id'];
                input['assets'] = List<String>.from(images);
                final group = Map<String, dynamic>.from(
                  await widget.api.post('admin/groups', input) as Map,
                );
                groups.add(group);
                groupId = group['id'].toString();
                fields['section']!.text = group['section'].toString();
                images = [];
              }),
        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
        label: const Text('Dùng ảnh cắt làm ngữ cảnh chung'),
      ),
    ],
  );
  Widget formPane() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (approved)
        const Text(
          'Câu đã duyệt là bất biến. Tạo bản mới để hiệu chỉnh.',
          style: TextStyle(color: AppColors.primary),
        ),
      textField('stem', 'Nội dung câu', lines: 4),
      if (sections.isNotEmpty)
        DropdownButtonFormField<String>(
          initialValue: sections.any((s) => s.$1 == fields['section']!.text)
              ? fields['section']!.text
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Phần thi'),
          items: sections
              .map(
                (s) => DropdownMenuItem(
                  value: s.$1,
                  child: Text(s.$2, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: approved ? null : (v) => fields['section']!.text = v ?? '',
        )
      else
        textField('section', 'Phần thi'),
      const SizedBox(height: 12),
      textField('subsection', 'Phần con'),
      textField('topic', 'Chuyên đề'),
      textField('skill', 'Kỹ năng'),
      textField('cognitiveLevel', 'Mức nhận thức'),
      DropdownButtonFormField<String>(
        initialValue: type,
        decoration: const InputDecoration(labelText: 'Loại câu'),
        items: const [
          DropdownMenuItem(value: 'MCQ', child: Text('Trắc nghiệm A–D')),
          DropdownMenuItem(value: 'SHORT', child: Text('Điền đáp án')),
        ],
        onChanged: approved ? null : (v) => setState(() => type = v!),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: difficulty,
        decoration: const InputDecoration(labelText: 'Độ khó'),
        items: const [
          DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
          DropdownMenuItem(value: 'MEDIUM', child: Text('Vừa')),
          DropdownMenuItem(value: 'HARD', child: Text('Khó')),
        ],
        onChanged: approved ? null : (v) => setState(() => difficulty = v!),
      ),
      const SizedBox(height: 12),
      if (type == 'MCQ')
        for (final key in ['A', 'B', 'C', 'D'])
          textField(key, 'Phương án $key'),
      textField('answer', 'Đáp án đúng'),
      if (type == 'SHORT')
        textField('acceptedAnswers', 'Đáp án tương đương, ngăn bởi ;'),
      textField('solution', 'Lời giải', lines: 4),
      DropdownButtonFormField<String>(
        key: ValueKey(groupId),
        initialValue: groupId ?? '',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Ngữ cảnh dùng chung'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Không dùng chung')),
          ...groups.map(
            (g) => DropdownMenuItem(
              value: g['id'].toString(),
              child: Text(
                g['content']?.toString().isNotEmpty == true
                    ? g['content'].toString()
                    : 'Ngữ cảnh bằng ảnh (${groups.indexOf(g) + 1})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: approved
            ? null
            : (v) => setState(() => groupId = v == '' ? null : v),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: visualVerified,
        onChanged: approved ? null : (v) => setState(() => visualVerified = v!),
        title: const Text('Đã soát hình, công thức và đầy đủ ngữ cảnh'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: answerFree,
        onChanged: approved ? null : (v) => setState(() => answerFree = v!),
        title: const Text('Ảnh câu không chứa đáp án/lời giải'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 1150,
      height: MediaQuery.sizeOf(context).height * .92,
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Duyệt câu · ${widget.source['relativePath']}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            trailing: IconButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) ExamError(error!),
          Expanded(
            child: FutureBuilder<void>(
              future: loading,
              builder: (context, snapshot) {
                if (snapshot.hasError) return ExamError(snapshot.error!);
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (pages.isEmpty) {
                  return const ExamEmpty('Xử lý PDF trước để tạo ảnh trang.');
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 740
                        ? Column(
                            children: [
                              imagePane(),
                              const SizedBox(height: 24),
                              formPane(),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: imagePane()),
                              const SizedBox(width: 24),
                              Expanded(child: formPane()),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => question = {
                            'sourceId': widget.source['id'],
                            'status': 'NEEDS_REVIEW',
                          },
                        ),
                  child: const Text('Tạo bản mới'),
                ),
                OutlinedButton(
                  onPressed: busy || approved ? null : () => run(() => save()),
                  child: const Text('Lưu câu chờ duyệt'),
                ),
                FilledButton(
                  onPressed: busy || approved
                      ? null
                      : () => run(() => save(approve: true)),
                  child: const Text('Lưu & duyệt'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

