import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/lesson_preparation/domain/models/preparation_document.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_controller.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_editors.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_jobs_panel.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_transcript_editor.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/screens/preparation_workspace_screen.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_tools_sheet.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_publish_sheet.dart';

class FakePreparationApi extends PreparationApi {
  final doc = <String, dynamic>{
    'revision': 2,
    'title': 'Bài mẫu',
    'sections': <dynamic>[],
    'scenes': <dynamic>[],
  };
  Map<String, dynamic> capabilities = {'local': true};
  bool conflict = false;
  Completer<dynamic>? pending;
  final posts = <String>[];
  final postBodies = <Object?>[];
  @override
  Future<dynamic> get(String path) async {
    if (path == 'capabilities') return capabilities;
    if (path.endsWith('/jobs')) return {'jobs': []};
    return Map<String, dynamic>.from(doc);
  }

  @override
  Future<dynamic> put(String path, Object body) async {
    if (conflict) throw PreparationFailure('conflict', 409);
    if (pending != null) return pending!.future;
    final payload = body as Map;
    expect(payload['expectedRevision'], doc['revision']);
    doc.addAll(Map<String, dynamic>.from(payload['document'] as Map));
    doc['revision'] = (doc['revision'] as int) + 1;
    return Map<String, dynamic>.from(doc);
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    posts.add(path);
    postBodies.add(body);
    return {};
  }

  @override
  void dispose() {}
}

class RefreshPreparationApi extends PreparationApi {
  RefreshPreparationApi(http.Client client)
    : super(client: client, base: 'http://localhost');
  int refreshed = 0;
  @override
  Future<Map<String, String>> headers() async => {
    'Authorization': 'Bearer $refreshed',
  };
  @override
  Future<void> refreshAuthentication() async {
    refreshed++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'workspace sends explicit prompt request only after API consent',
    (tester) async {
      final api = FakePreparationApi();
      api.doc['sourceScript'] = '  Selected lesson prompt  ';
      api.capabilities = {
        'authoring': {
          'ready': true,
          'baseUrl': 'https://provider.example/v1',
          'model': 'lesson-model',
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          home: PreparationWorkspaceScreen(
            planningId: 'p',
            title: 'A',
            subject: 'B',
            api: api,
            onOpenBoard: () async {},
            onTeach: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Thêm nội dung'));
      await tester.tap(find.text('Thêm nội dung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Văn bản có sẵn'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('AI đề xuất bài / storyboard'));
      await tester.tap(find.text('AI đề xuất bài / storyboard'));
      await tester.pumpAndSettle();
      expect(api.posts, isEmpty);
      expect(find.text('Selected lesson prompt'), findsOneWidget);
      await tester.tap(find.text('Gửi và tạo bản nháp'));
      await tester.pumpAndSettle();
      final request = api.postBodies.last as Map;
      expect(request['kind'], 'author');
      expect(request['text'], 'Selected lesson prompt');
      expect(request['inputMode'], 'prompt');
      expect(request['language'], 'en');
      expect(request['cloudConfirmed'], true);
      expect(
        request['expectedAuthoringBaseUrl'],
        'https://provider.example/v1',
      );
      expect(request['expectedAuthoringModel'], 'lesson-model');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'remote author retry requires new consent while script retry stays available',
    (tester) async {
      final c = PreparationController(
        planId: 'p',
        api: FakePreparationApi(),
        title: 'A',
        subject: 'B',
      );
      c.jobs = [
        {
          'id': 'remote',
          'kind': 'author',
          'status': 'failed',
          'inputMode': 'prompt',
        },
        {
          'id': 'local',
          'kind': 'author',
          'status': 'cancelled',
          'inputMode': 'script',
        },
      ];
      String? retried;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreparationJobsPanel(
              controller: c,
              onApply: (_) {},
              onPreview: (_) {},
              onAction: (id, action) => retried = id,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Đề xuất nội dung · Cần xử lý lỗi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('xác nhận gửi API lại'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      await tester.tap(find.text('Đề xuất nội dung · Đã hủy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử lại'));
      expect(retried, 'local');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'reopened publication sheet resumes journal with original request and revision',
    (tester) async {
      final api = FakePreparationApi();
      api.doc.addAll({
        'revision': 99,
        'publications': [
          {
            'requestId': 'original-request',
            'revision': 3,
            'courseId': 'course-old',
            'title': 'Pending material',
            'description': 'Original description',
            'artifactIds': ['artifact-old'],
            'status': 'uncertain',
          },
        ],
      });
      final c = PreparationController(
        planId: 'p',
        api: api,
        title: 'A',
        subject: 'B',
      );
      await c.load();
      Widget sheet(String key) => MaterialApp(
        home: Scaffold(
          body: PreparationPublishSheet(
            key: ValueKey(key),
            controller: c,
            onPreview: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(sheet('first'));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục / đối soát'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(sheet('reopened'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiếp tục / đối soát'));
      await tester.tap(find.text('Tiếp tục / đối soát'));
      await tester.pumpAndSettle();
      final request = api.postBodies.last as Map;
      expect(request['requestId'], 'original-request');
      expect(request['revision'], 3);
      expect(request['courseId'], 'course-old');
      expect(request['artifactIds'], ['artifact-old']);
      expect(c.document.revision, 99);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'reload after restore replaces displayed source script and transcript',
    (tester) async {
      final api = FakePreparationApi();
      api.doc.addAll({
        'sourceScript': 'Current script',
        'transcriptText': 'Current transcript',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PreparationWorkspaceScreen(
            planningId: 'p',
            title: 'A',
            subject: 'B',
            api: api,
            onOpenBoard: () async {},
            onTeach: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Thêm nội dung'));
      await tester.tap(find.text('Thêm nội dung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Văn bản có sẵn'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Lời chép từ bản ghi — kiểm tra và sửa trước khi dùng',
        ),
        'Edited transcript',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch sử & công cụ bài'));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<PreparationToolsSheet>(find.byType(PreparationToolsSheet))
          .controller;
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      api.doc.addAll({
        'revision': 10,
        'sourceScript': 'Restored script',
        'transcriptText': 'Restored transcript',
      });
      await controller.load();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(
                TextField,
                'Văn bản có sẵn hoặc ý tưởng bài giảng',
              ),
            )
            .controller!
            .text,
        'Restored script',
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(
                TextField,
                'Lời chép từ bản ghi — kiểm tra và sửa trước khi dùng',
              ),
            )
            .controller!
            .text,
        'Restored transcript',
      );
      await tester.ensureVisible(
        find.text('Chia văn bản thành các cảnh video'),
      );
      await tester.tap(find.text('Chia văn bản thành các cảnh video'));
      await tester.pumpAndSettle();
      expect((api.postBodies.last as Map)['text'], 'Restored script');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'reusing a reflection creates independently checkable revision tasks',
    (tester) async {
      final c = PreparationController(
        planId: 'p',
        api: FakePreparationApi(),
        title: 'A',
        subject: 'B',
      );
      await c.load();
      c.document.data['reflections'] = [
        {'id': 'reflection-1', 'title': 'Improve', 'body': 'Explain again'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreparationToolsSheet(controller: c)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nhận xét riêng để sửa bài'));
      await tester.tap(find.text('Nhận xét riêng để sửa bài'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đưa vào việc cần sửa'));
      await tester.tap(find.text('Đưa vào việc cần sửa'));
      await tester.pump();
      await tester.tap(find.text('Đưa vào việc cần sửa'));
      await tester.pump();
      final tasks = c.document.rows('revisionTasks');
      expect(tasks.length, 2);
      expect(tasks[0]['id'], isNot(tasks[1]['id']));
      final checkboxes = find.byType(CheckboxListTile);
      await tester.ensureVisible(checkboxes.last);
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.last);
      await tester.pump();
      expect(c.document.rows('revisionTasks')[0]['done'], isFalse);
      expect(c.document.rows('revisionTasks')[1]['done'], isTrue);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  test('refreshes rejected GET once but never blindly replays POST', () async {
    var count = 0;
    final api = RefreshPreparationApi(
      MockClient((req) async {
        count++;
        return http.Response(jsonEncode({'ok': true}), count == 1 ? 401 : 200);
      }),
    );
    await api.get('capabilities');
    expect(api.refreshed, 1);
    expect(count, 2);
    final unsafe = RefreshPreparationApi(
      MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
      unsafe.post('plannings/p/publish'),
      throwsA(isA<PreparationFailure>()),
    );
    expect(unsafe.refreshed, 0);
    api.dispose();
    unsafe.dispose();
  });
  testWidgets('English voice selector keeps selected voice for scene actions', (
    tester,
  ) async {
    String? voice;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreparationSceneEditor(
              scene: {'title': 'A'},
              onChange: (_, _) {},
              onAction: (_) {},
              onDelete: () {},
              onVoiceChanged: (v) => voice = v,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Heart · English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Michael · English').last);
    await tester.pumpAndSettle();
    expect(voice, 'am_michael');
  });
  testWidgets('transcript segment text and timestamp are separately editable', (
    tester,
  ) async {
    List<PreparationMap>? changed;
    double? seek;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreparationTranscriptEditor(
              segments: [
                {'start': 2.0, 'end': 5.0, 'text': 'Old'},
              ],
              onChanged: (v) => changed = v,
              onSeek: (v) => seek = v,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nội dung đoạn 1'),
      'Corrected',
    );
    expect(changed!.single['text'], 'Corrected');
    expect(changed!.single['start'], 2.0);
    await tester.tap(find.byTooltip('Xem nguồn tại mốc này'));
    expect(seek, 2.0);
  });
  testWidgets('script conversion submits explicit manual-script job', (
    tester,
  ) async {
    final api = FakePreparationApi();
    await tester.pumpWidget(
      MaterialApp(
        home: PreparationWorkspaceScreen(
          planningId: 'p',
          title: 'A',
          subject: 'B',
          api: api,
          onOpenBoard: () async {},
          onTeach: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thêm nội dung'));
    await tester.tap(find.text('Thêm nội dung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Văn bản có sẵn'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Văn bản có sẵn hoặc ý tưởng bài giảng'),
      'One.\n\nTwo.',
    );
    await tester.ensureVisible(find.text('Chia văn bản thành các cảnh video'));
    await tester.tap(find.text('Chia văn bản thành các cảnh video'));
    await tester.pumpAndSettle();
    expect((api.postBodies.last as Map)['inputMode'], 'script');
    expect((api.postBodies.last as Map)['kind'], 'author');
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'student projection omits notes, sources and private arbitrary fields',
    () {
      final doc = PreparationDocument({
        'title': 'A',
        'teacherNotes': 'SECRET',
        'sources': ['SECRET'],
        'sections': [
          {
            'id': '1',
            'title': 'Intro',
            'body': 'Visible',
            'teacherNotes': 'SECRET',
            'answerKey': 'SECRET',
          },
        ],
        'scenes': [
          {'id': '2', 'text': 'Visible', 'teacherNotes': 'SECRET'},
        ],
      });
      expect(doc.studentProjection().toString(), isNot(contains('SECRET')));
      expect(doc.studentProjection().toString(), contains('Visible'));
    },
  );
  test('save conflict preserves local content and stops overwriting', () async {
    final api = FakePreparationApi();
    final c = PreparationController(
      planId: 'p',
      api: api,
      title: 'A',
      subject: 'B',
    );
    await c.load();
    api.conflict = true;
    c.change((d) => d.data['title'] = 'Local edit');
    await c.save();
    expect(c.conflict, isTrue);
    expect(c.dirty, isTrue);
    expect(c.document.title, 'Local edit');
    await expectLater(c.run('render'), throwsA(isA<PreparationFailure>()));
    expect(api.posts, isEmpty);
    c.dispose();
  });
  test('edit during save stays dirty while revision advances', () async {
    final api = FakePreparationApi();
    final c = PreparationController(
      planId: 'p',
      api: api,
      title: 'A',
      subject: 'B',
    );
    await c.load();
    c.change((d) => d.data['title'] = 'First');
    api.pending = Completer<dynamic>();
    final save = c.save();
    c.change((d) => d.data['title'] = 'Second');
    api.pending!.complete({'revision': 3});
    await save;
    expect(c.dirty, isTrue);
    expect(c.document.revision, 3);
    expect(c.document.title, 'Second');
    c.dispose();
  });
  testWidgets(
    'section editor changes private notes without exposing them as body',
    (tester) async {
      final changes = <String, dynamic>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreparationSectionEditor(
                section: {'title': 'Intro', 'body': 'Visible'},
                onChange: (key, value) => changes[key] = value,
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      final notes = find.widgetWithText(TextField, 'Lời nhắc, đáp án riêng');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Private answer');
      expect(changes['teacherNotes'], 'Private answer');
      expect(changes.containsKey('body'), isFalse);
    },
  );
  testWidgets(
    'job panel offers review instead of automatically applying output',
    (tester) async {
      final c = PreparationController(
        planId: 'p',
        api: FakePreparationApi(),
        title: 'A',
        subject: 'B',
      );
      c.jobs = [
        {
          'id': 'j',
          'kind': 'author',
          'status': 'succeeded',
          'result': {'text': 'Draft'},
        },
      ];
      var applied = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreparationJobsPanel(
              controller: c,
              onApply: (_) => applied = true,
              onPreview: (_) {},
              onAction: (_, _) {},
            ),
          ),
        ),
      );
      expect(applied, isFalse);
      await tester.tap(find.text('Đề xuất nội dung · Hoàn tất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt / áp dụng'));
      expect(applied, isTrue);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
