import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../constants/theme.dart';
import '../../services/exam_api.dart';
import '../../services/exam_file.dart';
import '../../services/exam_files.dart';
import '../../services/google_meet_auth_service.dart';
import '../../widgets/exams/exam_widgets.dart';
import 'question_review_dialog.dart';
import 'exam_paper_editor.dart';
import '../login_screen.dart';

/// Native Flutter module reached from the existing teacher dashboard/auth gate.
class ExamWorkspaceScreen extends StatefulWidget {
  const ExamWorkspaceScreen({super.key, this.api, this.initialPage = 0})
    : assert(initialPage >= 0 && initialPage < 9);
  final ExamApi? api;
  final int initialPage;
  @override
  State<ExamWorkspaceScreen> createState() => _ExamWorkspaceScreenState();
}

class _ExamWorkspaceScreenState extends State<ExamWorkspaceScreen> {
  late final ExamApi api = widget.api ?? ExamApi();
  late Future<ExamRow> future;
  int selected = 0;
  bool busy = false;
  bool admin = false;
  String bankQuery = '', analyticsQuery = '';
  static const names = [
    'Tổng quan',
    'Ngân hàng câu hỏi',
    'Tạo đề thi',
    'Thư viện đề',
    'Lớp & học sinh',
    'Kết quả kiểm tra',
    'Phân tích năng lực',
    'Nguồn PDF & duyệt',
    'Ma trận',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.menu_book_outlined,
    Icons.note_add_outlined,
    Icons.folder_outlined,
    Icons.groups_outlined,
    Icons.fact_check_outlined,
    Icons.insights_outlined,
    Icons.upload_file_outlined,
    Icons.tune,
  ];
  @override
  void initState() {
    super.initState();
    selected = widget.initialPage;
    future = load();
    GoogleMeetAuthService().addListener(authChanged);
  }

  void authChanged() {
    if (!GoogleMeetAuthService().isSignedIn && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    GoogleMeetAuthService().removeListener(authChanged);
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  Future<ExamRow> load() async {
    final me = Map<String, dynamic>.from(await api.get('auth/me') as Map);
    admin = me['role'] == 'ADMIN';
    if (!admin && selected >= 7) selected = 0;
    final paths = switch (selected) {
      0 => {'summary': 'dashboard', 'report': 'analytics'},
      1 => {'questions': 'questions?$bankQuery', 'sources': 'sources'},
      2 => {'matrices': 'matrices', 'sources': 'sources'},
      3 => {'papers': 'papers'},
      4 => {'classes': 'classes', 'students': 'students'},
      5 => {
        'sessions': 'sessions',
        'papers': 'papers',
        'classes': 'classes',
        'students': 'students',
      },
      6 => {
        'report': 'analytics?$analyticsQuery',
        'classes': 'classes',
        'students': 'students',
      },
      7 => {
        'sources': 'sources',
        'jobs': 'admin/jobs',
        'questions': 'admin/questions',
      },
      _ => {'matrices': 'matrices'},
    };
    final values = await Future.wait(paths.values.map(api.get));
    return {
      'me': me,
      for (var i = 0; i < values.length; i++)
        paths.keys.elementAt(i): values[i],
    };
  }

  void reload() {
    if (mounted) setState(() => future = load());
  }

  void reauthenticate() {
    final navigator = Navigator.of(context);
    final auth = GoogleMeetAuthService();
    auth.removeListener(authChanged);
    auth.signOut();
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void go(int page) {
    setState(() {
      selected = page;
      future = load();
    });
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) reload();
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Chưa hoàn tất'),
            content: SingleChildScrollView(child: ExamError(e)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget button(
    String text,
    Future<void> Function() action, {
    IconData? icon,
    bool primary = false,
  }) => primary
      ? FilledButton.icon(
          onPressed: busy ? null : () => perform(action),
          icon: Icon(icon ?? Icons.add, size: 17),
          label: Text(text),
        )
      : OutlinedButton.icon(
          onPressed: busy ? null : () => perform(action),
          icon: Icon(icon ?? Icons.arrow_forward, size: 17),
          label: Text(text),
        );
  Future<ExamRow?> form(
    String title,
    List<ExamInput> inputs, {
    String submit = 'Lưu',
  }) => examForm(context, title, inputs, submit: submit);
  List<(String, String)> choices(List<ExamRow> rows, String label) =>
      rows.map((r) => (r['id'].toString(), r[label].toString())).toList();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paper,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'Đề thi & năng lực',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.slate200),
      ),
      actions: [
        IconButton(
          onPressed: busy ? null : reload,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại',
        ),
      ],
    ),
    body: FutureBuilder<ExamRow>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final needsLogin =
              snapshot.error is ExamApiException &&
              (snapshot.error as ExamApiException).status == 401;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExamError(snapshot.error!),
                    const SizedBox(height: 16),
                    Text(
                      needsLogin
                          ? 'Đăng nhập lại để truy cập dữ liệu đề thi của bạn.'
                          : 'Chưa tải được dữ liệu. Bạn có thể thử lại hoặc trở về trang chủ.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: needsLogin ? reauthenticate : reload,
                      child: Text(needsLogin ? 'Đăng nhập lại' : 'Thử lại'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Trở về app'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return Column(
          children: [
            SizedBox(
              height: 60,
              child: ListView.separated(
                key: const PageStorageKey('exam-navigation'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: admin ? 9 : 7,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ChoiceChip(
                  selected: selected == index,
                  onSelected: busy ? null : (_) => go(index),
                  avatar: Icon(
                    icons[index],
                    size: 17,
                    color: selected == index
                        ? AppColors.sky600
                        : AppColors.slate500,
                  ),
                  label: Text(names[index]),
                  selectedColor: AppColors.sky100,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected == index
                        ? AppColors.sky600
                        : AppColors.slate200,
                  ),
                ),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          names[selected],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        switch (selected) {
                          0 => dashboard(data),
                          1 => bank(data),
                          2 => generator(data),
                          3 => library(data),
                          4 => classes(data),
                          5 => results(data),
                          6 => analytics(data),
                          7 => sources(data),
                          _ => matrices(data),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  Widget dashboard(ExamRow data) {
    final summary = data['summary'] as Map;
    final report = data['report'] as Map;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final entry in [
              ('classes', 'Lớp học'),
              ('students', 'Học sinh'),
              ('papers', 'Đề đã tạo'),
              ('results', 'Kết quả'),
            ])
              SizedBox(
                width: 220,
                child: ExamCard(
                  title: entry.$2,
                  child: Text(
                    '${summary[entry.$1]}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ExamCard(
          title: 'Ngân hàng câu hỏi',
          actions: [
            button('Tạo đề', () async {
              go(2);
            }, primary: true),
          ],
          child: Text(
            '${summary['approvedQuestions']} câu đã duyệt từ ${summary['sources']} PDF nguồn.',
          ),
        ),
        ExamCard(
          title: 'Ưu tiên ôn tập',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                report['limitation'].toString(),
                style: const TextStyle(color: AppColors.slate500),
              ),
              ...examRows(report['recommendations']).map(
                (r) => ListTile(
                  title: Text(r['skill'].toString()),
                  subtitle: Text(r['reason'].toString()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget bank(ExamRow data) {
    final qs = examRows(data['questions']);
    return ExamCard(
      title: 'Câu hỏi đã duyệt',
      actions: [
        button('Tìm kiếm / lọc', () async {
          final input = await form('Lọc ngân hàng', [
            const ExamInput('search', 'Tìm nội dung', required: false),
            const ExamInput(
              'examType',
              'Kỳ thi',
              required: false,
              options: [('', 'Tất cả'), ('VACT', 'V-ACT'), ('HSA', 'HSA')],
            ),
            const ExamInput('skill', 'Kỹ năng', required: false),
            const ExamInput('topic', 'Chuyên đề', required: false),
            const ExamInput(
              'difficulty',
              'Độ khó',
              required: false,
              options: [
                ('', 'Tất cả'),
                ('EASY', 'Dễ'),
                ('MEDIUM', 'Vừa'),
                ('HARD', 'Khó'),
              ],
            ),
          ]);
          if (input != null) {
            bankQuery = Uri(
              queryParameters: input.map((k, v) => MapEntry(k, v.toString())),
            ).query;
          }
        }, icon: Icons.search),
      ],
      child: qs.isEmpty
          ? const ExamEmpty(
              'Chưa có câu phù hợp. Admin cần duyệt nguồn trước khi tạo đề.',
            )
          : Column(
              children: [
                for (final q in qs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(q['stem'].toString()),
                    subtitle: Text(
                      '${q['examType']} · ${q['skill']} · ${q['difficulty']}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => perform(() => question(q)),
                  ),
              ],
            ),
    );
  }

  Future<void> question(ExamRow q) async {
    ExamRow? group;
    if (q['groupId'] != null) {
      group = Map<String, dynamic>.from(
        await api.get('groups/${q['groupId']}') as Map,
      );
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chi tiết câu hỏi'),
        content: SizedBox(
          width: 800,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (group != null) ...[
                  Text(group['content']?.toString() ?? ''),
                  for (final id in group['assets'] as List)
                    ExamAsset(api: api, id: id.toString()),
                ],
                for (final id in q['assets'] as List)
                  ExamAsset(api: api, id: id.toString()),
                Text(q['stem'].toString()),
                const SizedBox(height: 16),
                Text(
                  'Đáp án: ${q['answer']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(q['solution']?.toString() ?? ''),
                for (final id in q['solutionAssets'] as List? ?? [])
                  ExamAsset(api: api, id: id.toString()),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await pdf('sources/${q['sourceId']}/pdf', 'PDF nguồn');
              } catch (e) {
                if (mounted) await message(e);
              }
            },
            child: const Text('Xem PDF gốc'),
          ),
        ],
      ),
    );
  }

  Future<void> pdf(String path, String title) async {
    final bytes = await api.bytes(path);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 1000,
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              ListTile(
                title: Text(title),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(child: PdfViewer.data(bytes, sourceName: '$title.pdf')),
            ],
          ),
        ),
      ),
    );
  }

  Widget generator(ExamRow data) {
    final ms = examRows(
      data['matrices'],
    ).where((m) => m['status'] == 'ACTIVE').toList();
    return Column(
      children: [
        ExamCard(
          title: 'Ma trận có phiên bản',
          child: Column(
            children: [
              for (final m in ms)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m['name'].toString()),
                  subtitle: Text(
                    '${m['totalQuestions']} câu · ${m['durationMinutes']} phút',
                  ),
                  trailing: button('Tạo đề', () async {
                    final input = await form('Tạo đề: ${m['name']}', [
                      const ExamInput('title', 'Tên đề thi'),
                      const ExamInput(
                        'variants',
                        'Số mã đề',
                        value: 1,
                        kind: 'int',
                      ),
                      const ExamInput(
                        'difficulty',
                        'Độ khó',
                        required: false,
                        options: [
                          ('', 'Theo ngân hàng'),
                          ('EASY', 'Dễ'),
                          ('MEDIUM', 'Vừa'),
                          ('HARD', 'Khó'),
                        ],
                      ),
                      const ExamInput(
                        'skill',
                        'Lọc kỹ năng (tùy chọn)',
                        required: false,
                      ),
                    ]);
                    if (input == null) return;
                    input['matrixId'] = m['id'];
                    if (!mounted) return;
                    final sourceIds = await examSelection(
                      context,
                      'Chọn nguồn PDF (bỏ trống để dùng tất cả)',
                      examRows(data['sources'])
                          .where(
                            (s) =>
                                s['active'] == true &&
                                s['examType'] == m['examType'] &&
                                s['examVersion'] == m['examVersion'],
                          )
                          .map(
                            (s) => (
                              s['id'].toString(),
                              s['relativePath'].toString(),
                            ),
                          )
                          .toList(),
                      selectAll: true,
                    );
                    if (sourceIds == null) return;
                    input['sourceIds'] = sourceIds;
                    final created = examRows(
                      await api.post('papers/generate', input),
                    );
                    if (mounted) await paper(created.first);
                  }, primary: true),
                ),
            ],
          ),
        ),
        ExamCard(
          title: 'Nguồn có thể chọn',
          child: Column(
            children: [
              for (final source in examRows(
                data['sources'],
              ).where((s) => s['active'] == true))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(source['relativePath'].toString()),
                  subtitle: SelectableText(
                    '${source['examType']} ${source['examVersion']} · phiên bản ${source['revision']}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget library(ExamRow data) {
    final ps = examRows(data['papers']);
    return ExamCard(
      title: 'Đề thi của giáo viên',
      actions: [
        button('Xuất nhiều mã đề', () async {
          final published = ps
              .where((p) => p['status'] == 'PUBLISHED')
              .toList();
          if (published.isEmpty) throw StateError('Chưa có đề đã xuất bản.');
          final input = await form('Xuất ZIP', [
            const ExamInput(
              'format',
              'Định dạng',
              options: [('pdf', 'PDF'), ('docx', 'DOCX')],
            ),
            const ExamInput(
              'kind',
              'Nội dung',
              options: [
                ('paper', 'Đề không kèm đáp án'),
                ('answers', 'Đáp án'),
                ('solutions', 'Lời giải'),
                ('matrix', 'Ma trận'),
              ],
            ),
          ]);
          if (input == null) return;
          if (!mounted) return;
          final paperIds = await examSelection(
            context,
            'Chọn mã đề',
            published
                .map(
                  (p) => (
                    p['id'].toString(),
                    '${p['title']} · mã ${p['variant']}',
                  ),
                )
                .toList(),
            selectAll: true,
          );
          if (paperIds == null || paperIds.isEmpty) return;
          input['paperIds'] = paperIds;
          await saveExamFile(
            await api.postBytes('papers/export', input),
            'cac-ma-de.zip',
          );
        }, icon: Icons.download),
      ],
      child: ps.isEmpty
          ? const ExamEmpty('Chưa có đề thi. Tạo đề theo ma trận để bắt đầu.')
          : Column(
              children: [
                for (final p in ps)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p['title'].toString()),
                    subtitle: Text(
                      '${(p['matrix'] as Map)['examType']} · Mã ${p['variant']} · ${p['status']}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => perform(() => paper(p)),
                  ),
              ],
            ),
    );
  }

  Future<void> paper(ExamRow original) async {
    final p = Map<String, dynamic>.from(
      await api.get('papers/${original['id']}') as Map,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 950,
          height: MediaQuery.sizeOf(context).height * .9,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  p['title'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${p['status']} · Exam ID: ${p['id']}'),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p['status'] == 'DRAFT') ...[
                    OutlinedButton(
                      onPressed: () async {
                        final result = await showDialog<ExamRow>(
                          context: context,
                          builder: (_) => ExamPaperEditor(api: api, paper: p),
                        );
                        if (result != null && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          await paper(result);
                        }
                      },
                      child: const Text('Chỉnh sửa / đổi thứ tự'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await api.post('papers/${p['id']}/publish');
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          await paper(p);
                        } catch (e) {
                          if (mounted) await message(e);
                        }
                      },
                      child: const Text('Kiểm tra & xuất bản'),
                    ),
                  ],
                  if (p['status'] == 'PUBLISHED')
                    for (final format in ['pdf', 'docx'])
                      OutlinedButton(
                        onPressed: () async {
                          final input = await form(
                            'Xuất ${format.toUpperCase()}',
                            [
                              const ExamInput(
                                'kind',
                                'Nội dung',
                                options: [
                                  ('paper', 'Đề không kèm đáp án'),
                                  ('answers', 'Đáp án riêng'),
                                  ('solutions', 'Lời giải riêng'),
                                  ('matrix', 'Ma trận'),
                                ],
                              ),
                            ],
                          );
                          if (input != null) {
                            try {
                              await saveExamFile(
                                await api.bytes(
                                  'papers/${p['id']}/export?format=$format&kind=${input['kind']}',
                                ),
                                'de-${p['variant']}-${input['kind']}.$format',
                              );
                            } catch (e) {
                              if (mounted) await message(e);
                            }
                          }
                        },
                        child: Text('Tải ${format.toUpperCase()}'),
                      ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(p['instructions']?.toString() ?? ''),
                    for (final (index, q) in examRows(
                      p['questions'],
                    ).indexed) ...[
                      if (q['groupId'] != null &&
                          (index == 0 ||
                              examRows(p['questions'])[index - 1]['groupId'] !=
                                  q['groupId'])) ...[
                        for (final group in examRows(
                          p['groups'],
                        ).where((g) => g['id'] == q['groupId'])) ...[
                          Text(group['content']?.toString() ?? ''),
                          for (final id in group['assets'] as List)
                            ExamAsset(api: api, id: id.toString()),
                        ],
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Câu ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      for (final id in q['assets'] as List)
                        ExamAsset(api: api, id: id.toString()),
                      ExpansionTile(
                        title: const Text('Đáp án & lời giải'),
                        children: [
                          Text('${q['answer']} · ${q['solution'] ?? ''}'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> message(Object error) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      content: SingleChildScrollView(child: ExamError(error)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
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
                    style: const TextStyle(color: AppColors.rose600),
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
                                color: AppColors.sky600,
                                backgroundColor: AppColors.sky100,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item['correctAnswers']}/${item['questionsAttempted']} câu đúng · ${item['evidenceLevel']} · ${item['trend']}',
                                style: const TextStyle(
                                  color: AppColors.slate500,
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
                                fontWeight: FontWeight.w800,
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
