part of 'exam_workspace_screen.dart';

extension _ExamWorkspaceClassesAndResultsExt on _ExamWorkspaceScreenState {
  Widget classes(ExamRow data) {
    final cs = examRows(data['classes']), ss = examRows(data['students']);
    return Column(
      children: [
        ExamCard(
          title: 'Lớp học',
          actions: [
            button('Thêm lớp', () async {
              final input = await form('Thêm lớp', [
                const ExamInput('name', 'Tên lớp'),
              ]);
              if (input != null) await api.post('classes', input);
            }, primary: true),
          ],
          child: cs.isEmpty
              ? const ExamEmpty('Chưa có lớp học.')
              : Column(
                  children: [
                    for (final c in cs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c['name'].toString()),
                        trailing: button('Danh sách', () async {
                          final roster = examRows(
                            await api.get('classes/${c['id']}/students'),
                          );
                          if (mounted) {
                            await showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(c['name'].toString()),
                                content: SizedBox(
                                  width: 600,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        for (final s in roster)
                                          ListTile(
                                            title: Text(
                                              s['fullName'].toString(),
                                            ),
                                            subtitle: Text(
                                              s['code'].toString(),
                                            ),
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
                                ],
                              ),
                            );
                          }
                        }, icon: Icons.groups),
                      ),
                  ],
                ),
        ),
        ExamCard(
          title: 'Hồ sơ học sinh',
          actions: [
            button('Thêm học sinh', () async {
              final input = await form('Thêm học sinh', [
                const ExamInput('code', 'Mã học sinh'),
                const ExamInput('fullName', 'Họ tên'),
                ExamInput(
                  'classId',
                  'Lớp',
                  required: false,
                  options: [('', 'Chưa xếp lớp'), ...choices(cs, 'name')],
                ),
                const ExamInput('notes', 'Ghi chú', required: false),
              ]);
              if (input != null) await api.post('students', input);
            }, primary: true),
            button('Import CSV / Excel', () async {
              if (cs.isEmpty) throw StateError('Tạo lớp trước khi import.');
              final input = await form('Chọn lớp nhận danh sách', [
                ExamInput('classId', 'Lớp', options: choices(cs, 'name')),
              ]);
              if (input != null) {
                await importFile(
                  'students/import/preview',
                  fields: {'classId': input['classId'].toString()},
                );
              }
            }, icon: Icons.upload_file),
          ],
          child: ss.isEmpty
              ? const ExamEmpty(
                  'Học sinh là hồ sơ dữ liệu, không có tài khoản đăng nhập.',
                )
              : Column(
                  children: [
                    for (final s in ss)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s['fullName'].toString()),
                        subtitle: Text('${s['code']} · ${s['notes']}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) => perform(() async {
                            if (action == 'edit') {
                              final input = await form('Chỉnh sửa hồ sơ', [
                                ExamInput(
                                  'fullName',
                                  'Họ tên',
                                  value: s['fullName'],
                                ),
                                ExamInput(
                                  'notes',
                                  'Ghi chú',
                                  value: s['notes'],
                                  required: false,
                                ),
                              ]);
                              if (input != null) {
                                await api.put('students/${s['id']}', input);
                              }
                            } else {
                              if (cs.length < 2) {
                                throw StateError('Cần ít nhất hai lớp.');
                              }
                              final input = await form('Chuyển lớp', [
                                ExamInput(
                                  'fromClass',
                                  'Lớp hiện tại',
                                  options: choices(cs, 'name'),
                                ),
                                ExamInput(
                                  'toClassId',
                                  'Lớp mới',
                                  options: choices(cs, 'name'),
                                ),
                              ]);
                              if (input != null) {
                                await api.post(
                                  'classes/${input['fromClass']}/transfer',
                                  {
                                    'toClassId': input['toClassId'],
                                    'studentId': s['id'],
                                  },
                                );
                              }
                            }
                          }),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Chỉnh sửa'),
                            ),
                            PopupMenuItem(
                              value: 'transfer',
                              child: Text('Chuyển lớp'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget results(ExamRow data) {
    final sessions = examRows(data['sessions']),
        cs = examRows(data['classes']),
        ps = examRows(
          data['papers'],
        ).where((p) => p['status'] == 'PUBLISHED').toList();
    return ExamCard(
      title: 'Lần kiểm tra bên ngoài app',
      actions: [
        button('Tạo lần kiểm tra', () async {
          if (cs.isEmpty || ps.isEmpty) {
            throw StateError(
              'Tạo lớp và xuất bản đề trước khi ghi nhận kết quả.',
            );
          }
          final input = await form('Lần kiểm tra mới', [
            const ExamInput('title', 'Tên lần kiểm tra'),
            ExamInput('classId', 'Lớp', options: choices(cs, 'name')),
            ExamInput(
              'paperId',
              'Mã đề',
              options: ps
                  .map(
                    (p) => (
                      p['id'].toString(),
                      '${p['title']} · mã ${p['variant']}',
                    ),
                  )
                  .toList(),
            ),
            ExamInput(
              'assessedAt',
              'Ngày kiểm tra (ISO)',
              value: DateTime.now().toUtc().toIso8601String(),
            ),
          ]);
          if (input != null) await api.post('sessions', input);
        }, primary: true),
      ],
      child: sessions.isEmpty
          ? const ExamEmpty(
              'Giáo viên tổ chức kiểm tra bên ngoài rồi nhập hoặc import kết quả.',
            )
          : Column(
              children: [
                for (final session in sessions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(session['title'].toString()),
                    subtitle: Text('Exam ID: ${session['paperId']}'),
                    trailing: button(
                      'Kết quả',
                      () => sessionResults(session),
                      icon: Icons.fact_check,
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> sessionResults(ExamRow session) async {
    final roster = examRows(
          await api.get('classes/${session['classId']}/students'),
        ),
        recorded = examRows(await api.get('sessions/${session['id']}/results'));
    final p = Map<String, dynamic>.from(
      await api.get('papers/${session['paperId']}') as Map,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(session['title'].toString()),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final result in recorded)
                  ListTile(
                    title: Text(
                      roster
                              .where((s) => s['id'] == result['studentId'])
                              .firstOrNull?['fullName']
                              ?.toString() ??
                          result['studentId'].toString(),
                    ),
                    subtitle: Text(
                      '${result['score']} điểm luyện tập · ${result['level']}',
                    ),
                  ),
                if (recorded.isEmpty) const ExamEmpty('Chưa có kết quả.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await importFile('sessions/${session['id']}/import/preview');
            },
            child: const Text('Import CSV / XLSX'),
          ),
          TextButton(
            onPressed: () async {
              final remaining = roster
                  .where((s) => !recorded.any((r) => r['studentId'] == s['id']))
                  .toList();
              if (remaining.isEmpty) {
                await message(StateError('Các học sinh đều đã có kết quả.'));
                return;
              }
              final mode = await form('Nhập kết quả', [
                ExamInput(
                  'studentId',
                  'Học sinh',
                  options: choices(remaining, 'fullName'),
                ),
                const ExamInput(
                  'level',
                  'Độ chi tiết',
                  options: [
                    ('DETAILED', 'Đáp án từng câu'),
                    ('AGGREGATE', 'Điểm tổng / số câu đúng'),
                  ],
                ),
              ]);
              if (mode == null) return;
              final values = await form(
                'Kết quả kiểm tra',
                mode['level'] == 'DETAILED'
                    ? [
                        for (
                          var i = 1;
                          i <= (p['questions'] as List).length;
                          i++
                        )
                          ExamInput(
                            '$i',
                            'Câu $i (trống = không trả lời)',
                            required: false,
                          ),
                      ]
                    : [
                        const ExamInput(
                          'score',
                          'Điểm luyện tập',
                          required: false,
                          kind: 'number',
                        ),
                        const ExamInput(
                          'correctCount',
                          'Số câu đúng',
                          required: false,
                          kind: 'int',
                        ),
                      ],
              );
              if (values == null) return;
              try {
                await api.post('sessions/${session['id']}/results', {
                  'studentId': mode['studentId'],
                  if (mode['level'] == 'DETAILED')
                    'answers': values
                  else
                    ...values,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await sessionResults(session);
              } catch (e) {
                if (mounted) await message(e);
              }
            },
            child: const Text('Nhập thủ công'),
          ),
          TextButton(
            onPressed: () async {
              final cols = [
                for (var i = 1; i <= (p['questions'] as List).length; i++)
                  'question_$i',
              ];
              final csv =
                  '\uFEFFstudent_code,exam_id,${cols.join(',')}\r\n${roster.map((s) => '"${s['code']}",${p['id']},${cols.map((_) => '').join(',')}').join('\r\n')}';
              await saveExamFile(
                Uint8List.fromList(utf8.encode(csv)),
                'ket-qua-${p['id']}.csv',
              );
            },
            child: const Text('CSV mẫu'),
          ),
        ],
      ),
    );
  }

  Future<void> importFile(
    String path, {
    Map<String, String> fields = const {},
  }) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final job = Map<String, dynamic>.from(
      await api.upload(path, bytes, file.name, fields: fields) as Map,
    );
    if (!mounted) return;
    final rows = examRows(job['rows']), errors = job['errors'] as List;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Preview: ${rows.length} dòng, ${errors.length} lỗi'),
        content: SizedBox(
          width: 750,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kiểm tra toàn bộ file. Hiển thị tối đa 20 dòng; preview có hiệu lực 30 phút.',
                ),
                for (final error in errors)
                  Text(
                    error.toString(),
                    style: const TextStyle(color: AppColors.error),
                  ),
                for (final row in rows.take(20))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SelectableText(
                      row.entries
                          .take(8)
                          .map((e) => '${e.key}: ${e.value}')
                          .join(' · '),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: errors.isEmpty
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Ghi nhận dữ liệu'),
          ),
        ],
      ),
    );
    if (confirmed == true) await api.post('imports/${job['id']}/commit');
  }
}

