part of 'exam_workspace_screen.dart';

extension _ExamWorkspaceAnalyticsAndSourcesExt on _ExamWorkspaceScreenState {
  Widget analytics(ExamRow data) {
    final report = data['report'] as Map;
    return Column(
      children: [
        ExamCard(
          title: 'Phạm vi phân tích',
          actions: [
            button('Lọc lớp / học sinh', () async {
              final input = await form('Phạm vi', [
                ExamInput(
                  'classId',
                  'Lớp',
                  required: false,
                  options: [
                    ('', 'Tất cả'),
                    ...choices(examRows(data['classes']), 'name'),
                  ],
                ),
                ExamInput(
                  'studentId',
                  'Học sinh',
                  required: false,
                  options: [
                    ('', 'Tất cả'),
                    ...choices(examRows(data['students']), 'fullName'),
                  ],
                ),
                const ExamInput(
                  'examType',
                  'Kỳ thi',
                  required: false,
                  options: [('', 'Tất cả'), ('VACT', 'V-ACT'), ('HSA', 'HSA')],
                ),
              ]);
              if (input != null) {
                analyticsQuery = Uri(
                  queryParameters: input.map(
                    (k, v) => MapEntry(k, v.toString()),
                  ),
                ).query;
              }
            }, icon: Icons.filter_alt_outlined),
            button(
              'Xuất CSV',
              () async => saveExamFile(
                await api.bytes('analytics/export?$analyticsQuery'),
                'bao-cao-luyen-tap.csv',
              ),
              icon: Icons.download,
            ),
          ],
          child: Text(report['limitation'].toString()),
        ),
        ExamCard(
          title: 'Lịch sử điểm luyện tập',
          child: Column(
            children: [
              for (final row in examRows(report['scores']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${row['studentName']} · ${row['title']}'),
                  subtitle: Text(
                    '${row['examType']} · ${row['assessedAt']} · ${row['level']}',
                  ),
                  trailing: Text('${row['score']}/${row['maxScore']}'),
                ),
            ],
          ),
        ),
        for (final key in [
          ('skills', 'Kỹ năng'),
          ('topics', 'Chuyên đề'),
          ('sections', 'Phần thi'),
          ('difficulties', 'Độ khó'),
        ])
          ExamCard(
            title: key.$2,
            child: examRows(report[key.$1]).isEmpty
                ? const ExamEmpty('Chưa có đáp án chi tiết để phân tích.')
                : Column(
                    children: [
                      for (final item in examRows(report[key.$1]))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['key']} · ${(item['accuracyRate'] as num).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value:
                                    (item['accuracyRate'] as num).toDouble() /
                                    100,
                                color: AppColors.primary,
                                backgroundColor: AppColors.selected,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item['correctAnswers']}/${item['questionsAttempted']} câu đúng · ${item['evidenceLevel']} · ${item['trend']}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ExamCard(
          title: 'Gợi ý ôn tập',
          child: Column(
            children: [
              for (final rec in examRows(report['recommendations']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(rec['skill'].toString()),
                  subtitle: Text(rec['reason'].toString()),
                  trailing: button('Tạo bộ ôn', () async {
                    final input = await form('Bộ ôn kỹ năng', [
                      ExamInput(
                        'title',
                        'Tên bộ câu hỏi',
                        value: 'Ôn ${rec['skill']}',
                      ),
                      const ExamInput(
                        'examVersion',
                        'Phiên bản năm',
                        value: '2026',
                      ),
                      const ExamInput(
                        'count',
                        'Số câu',
                        value: 20,
                        kind: 'int',
                      ),
                      const ExamInput(
                        'durationMinutes',
                        'Thời gian',
                        value: 30,
                        kind: 'int',
                      ),
                    ]);
                    if (input == null) return;
                    input['examType'] = rec['examType'];
                    input['skill'] = rec['skill'];
                    final created = examRows(
                      await api.post('papers/revision', input),
                    );
                    if (mounted) await paper(created.first);
                  }, primary: true),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget sources(ExamRow data) {
    final ss = examRows(data['sources']);
    return Column(
      children: [
        ExamCard(
          title: 'Nguồn PDF do admin quản lý',
          actions: [
            button(
              'Upload thư mục',
              () async {
                final files = await pickExamFolder();
                if (files.isEmpty) return;
                await uploadSources(files);
              },
              icon: Icons.create_new_folder_outlined,
              primary: true,
            ),
            button('Chọn nhiều PDF', () async {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf'],
              );
              final files = <ExamFile>[];
              for (final file in result) {
                files.add(
                  ExamFile(file.name, file.name, await file.readAsBytes()),
                );
              }
              if (files.isNotEmpty) await uploadSources(files);
            }, icon: Icons.upload_file),
          ],
          child: ss.isEmpty
              ? const ExamEmpty(
                  'Chọn cả thư mục để upload các PDF, kể cả thư mục con.',
                )
              : Column(
                  children: [
                    for (final s in ss)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['relativePath'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${s['examType']} ${s['examVersion']} · v${s['revision']} · ${s['status']} · ${s['pages']} trang',
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                button('Xử lý', () async {
                                  await api.post(
                                    'admin/sources/${s['id']}/process',
                                    {'force': s['status'] != 'UPLOADED'},
                                  );
                                }, icon: Icons.settings),
                                button(
                                  'Duyệt câu',
                                  () => reviewQuestion(s, data),
                                  icon: Icons.fact_check,
                                ),
                                button(
                                  s['active'] == true
                                      ? 'Vô hiệu hóa'
                                      : 'Kích hoạt',
                                  () async {
                                    await api.put(
                                      'admin/sources/${s['id']}/active',
                                      {'active': s['active'] != true},
                                    );
                                  },
                                  icon: Icons.power_settings_new,
                                ),
                                button(
                                  'PDF gốc',
                                  () => pdf(
                                    'sources/${s['id']}/pdf',
                                    'PDF nguồn',
                                  ),
                                  icon: Icons.picture_as_pdf,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        ExamCard(
          title: 'Lịch sử xử lý',
          child: Column(
            children: [
              for (final job in examRows(data['jobs']))
                ExpansionTile(
                  title: Text(job['status'].toString()),
                  subtitle: Text(job['sourceId'].toString()),
                  children: [
                    for (final issue in job['issues'] as List)
                      ListTile(title: Text(issue.toString())),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> uploadSources(List<ExamFile> files) async {
    final input = await form('Upload ${files.length} PDF', [
      const ExamInput(
        'examType',
        'Kỳ thi',
        options: [('VACT', 'V-ACT'), ('HSA', 'HSA')],
      ),
      const ExamInput('examVersion', 'Phiên bản năm', value: '2026'),
    ]);
    if (input == null) return;
    final outcomes = <String>[];
    for (final file in files) {
      try {
        final response = await api.upload(
          'admin/sources',
          file.bytes,
          file.name,
          fields: {
            'relativePath': file.relativePath,
            'examType': input['examType'].toString(),
            'examVersion': input['examVersion'].toString(),
          },
        );
        outcomes.add(
          '${file.relativePath}: ${response['duplicate'] == true ? 'Checksum trùng' : 'Đã tải'}',
        );
      } catch (e) {
        outcomes.add('${file.relativePath}: $e');
      }
    }
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Kết quả upload'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(child: Text(outcomes.join('\n'))),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> reviewQuestion(ExamRow source, ExamRow data) async {
    final qs = examRows(
      data['questions'],
    ).where((q) => q['sourceId'] == source['id']).toList();
    if (!mounted) return;
    final q = await showDialog<ExamRow>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chọn câu cần duyệt'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final q in qs)
                  ListTile(
                    title: Text(q['stem'].toString()),
                    subtitle: Text('${q['status']} · trang ${q['sourcePage']}'),
                    onTap: () => Navigator.pop(context, q),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, <String, dynamic>{
              'sourceId': source['id'],
              'sourcePage': 1,
              'stem': '',
              'choices': [],
              'assets': [],
              'solutionAssets': [],
              'type': 'MCQ',
              'difficulty': 'MEDIUM',
              'status': 'NEEDS_REVIEW',
            }),
            child: const Text('Tạo thủ công'),
          ),
        ],
      ),
    );
    if (q != null && mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) =>
            QuestionReviewDialog(api: api, source: source, question: q),
      );
    }
  }

  Widget matrices(ExamRow data) => ExamCard(
    title: 'Các phiên bản ma trận',
    actions: [
      button('Thêm phiên bản', () async {
        final input = await form('Ma trận JSON', [
          const ExamInput(
            'config',
            'Cấu hình JSON (ID phiên bản mới)',
            lines: 16,
          ),
        ]);
        if (input != null) {
          await api.post(
            'admin/matrices',
            jsonDecode(input['config'].toString()),
          );
        }
      }, primary: true),
    ],
    child: Column(
      children: [
        for (final matrix in examRows(data['matrices']))
          ExpansionTile(
            title: Text(matrix['name'].toString()),
            subtitle: Text(
              '${matrix['status']} · ${matrix['totalQuestions']} câu',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(matrix),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

