import 'package:teaching_companion/features/classroom_meet/presentation/meet_admission_button.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/exams/services/exam_api.dart';
import 'package:teaching_companion/features/exams/services/exam_file.dart';
import 'package:teaching_companion/features/exams/services/exam_files.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/exams/presentation/exam_widgets.dart';
import 'question_review_dialog.dart';
import 'exam_paper_editor.dart';
import 'package:teaching_companion/features/auth/presentation/screens/login_screen.dart';

part 'exam_workspace_classes_and_results.dart';
part 'exam_workspace_analytics_and_sources.dart';

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
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
      actions: [
        const MeetAdmissionButton(),
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
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  label: Text(names[index]),
                  selectedColor: AppColors.selected,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected == index
                        ? AppColors.primary
                        : AppColors.border,
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
                            fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
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
                style: const TextStyle(color: AppColors.textMuted),
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
}


