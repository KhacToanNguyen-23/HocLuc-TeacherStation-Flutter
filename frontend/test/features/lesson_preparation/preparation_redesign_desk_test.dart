import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/screens/preparation_workspace_screen.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';

class _DeskApi extends PreparationApi {
  Map<String, dynamic> doc = {
    'title': 'Bài thực tế',
    'revision': 1,
    'sections': [
      {
        'id': 'one',
        'title': 'Khởi động',
        'body': 'Câu hỏi cho cả lớp',
        'teacherNotes': 'Đáp án riêng tuyệt mật',
        'minutes': 5,
      },
      {
        'id': 'two',
        'title': 'Thảo luận',
        'body': 'Làm việc nhóm',
        'teacherNotes': 'Đợi 20 giây',
      },
    ],
  };
  bool fail = false;
  String? duplicatedSource;
  @override
  Future<dynamic> post(String path, [Object? body]) async {
    duplicatedSource = path;
    return {'planningId': 'copied-lesson'};
  }

  @override
  Future<dynamic> get(String path) async {
    if (fail) throw PreparationFailure('Mất kết nối thử nghiệm', 503);
    if (path == 'capabilities') return {};
    if (path.endsWith('/jobs')) return {'jobs': []};
    return Map<String, dynamic>.from(doc);
  }

  @override
  Future<dynamic> put(String path, Object value) async {
    doc = Map<String, dynamic>.from((value as Map)['document'] as Map);
    doc['revision'] = (doc['revision'] as int? ?? 1) + 1;
    return doc;
  }

  @override
  void dispose() {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> open(
    WidgetTester tester,
    _DeskApi api, {
    ValueChanged<String>? onOpenCopy,
  }) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PreparationWorkspaceScreen(
          planningId: 'desk',
          title: 'A',
          subject: '',
          api: api,
          loadPlanningLibrary: () async => [
            {'id': 'desk', 'title': 'Bài đang mở'},
            {
              'id': 'source-lesson',
              'title': 'Bài cũ trong thư viện',
              'subject': 'Chung',
            },
          ],
          onOpenVariant: (id) async {
            onOpenCopy?.call(id);
          },
          loadBoardContent: () async => {
            'pageIds': ['board-one'],
            'pageTitles': ['Bảng đầu tiên'],
          },
          onOpenBoard: () async {},
          onTeach: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desk gives one title, contextual notes and optional lesson metadata',
    (tester) async {
      await open(tester, _DeskApi());
      expect(find.text('Dàn ý bài giảng'), findsOneWidget);
      expect(find.text('Tên bài giảng / thuyết trình'), findsOneWidget);
      expect(find.text('Hỗ trợ giáo viên'), findsOneWidget);
      expect(find.text('Mục tiêu (tùy chọn)'), findsNothing);
      expect(find.text('Đáp án riêng tuyệt mật'), findsOneWidget);
      await tester.tap(find.text('Thảo luận'));
      await tester.pumpAndSettle();
      expect(find.text('Đợi 20 giây'), findsOneWidget);
      expect(find.text('Đáp án riêng tuyệt mật'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'student preview excludes teacher notes while teacher preview includes them',
    (tester) async {
      await open(tester, _DeskApi());
      await tester.tap(find.byTooltip('Xem trước giáo viên và học sinh'));
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Câu hỏi cho cả lớp')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('Lời nhắc riêng:'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Giáo viên — riêng tư'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('Đáp án riêng tuyệt mật'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'empty lesson explains three real ways to start instead of five tabs',
    (tester) async {
      final api = _DeskApi()..doc['sections'] = [];
      await open(tester, api);
      expect(find.text('Tự soạn nội dung'), findsOneWidget);
      expect(find.text('Dùng tài liệu có sẵn'), findsOneWidget);
      expect(find.text('Dùng lại bài cũ'), findsOneWidget);
      expect(find.text('Tác vụ / Học liệu'), findsNothing);
      await tester.tap(find.text('Tự soạn nội dung'));
      await tester.pumpAndSettle();
      expect(find.text('Hỗ trợ giáo viên'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed initial load cannot edit a fabricated blank lesson', (
    tester,
  ) async {
    await open(tester, _DeskApi()..fail = true);
    expect(find.text('Chưa mở được bài đã lưu'), findsOneWidget);
    expect(find.text('Tự soạn nội dung'), findsNothing);
    expect(find.text('Đã lưu'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'page cue editor changes common note without overwriting activity scoped note',
    (tester) async {
      final api = _DeskApi();
      api.doc['teacherCues'] = [
        {
          'id': 'common',
          'locator': {'pageId': 'board-one', 'kind': 'board'},
          'text': 'Lời nhắc chung',
        },
        {
          'id': 'scoped',
          'locator': {'pageId': 'board-one', 'kind': 'board'},
          'activityId': 'one',
          'text': 'Lời nhắc khởi động',
        },
      ];
      await open(tester, api);
      await tester.ensureVisible(find.text('Lời nhắc theo trang'));
      await tester.tap(find.text('Lời nhắc theo trang'));
      await tester.pumpAndSettle();
      expect(find.text('Lời nhắc chung'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Lời nhắc, câu hỏi gợi mở, đáp án riêng',
        ),
        'Chung đã sửa',
      );
      await tester.tap(find.text('Lưu lời nhắc trang'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final cues = api.doc['teacherCues'] as List;
      expect(cues.length, 2);
      expect(
        cues.where((cue) => cue['activityId'] == 'one').single['text'],
        'Lời nhắc khởi động',
      );
      expect(
        cues.where((cue) => cue['activityId'] == null).single['text'],
        'Chung đã sửa',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'teacher desk has readable responsive layouts at desktop and narrow widths',
    (tester) async {
      await tester.runAsync(() async {
        final text = FontLoader('Manrope')
          ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
        await text.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      for (final size in [const Size(1280, 900), const Size(800, 700)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: PreparationWorkspaceScreen(
                planningId: 'screenshot',
                title: 'Bài mẫu',
                subject: '',
                api: _DeskApi(),
                onOpenBoard: () async {},
                onTeach: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('../tmp/redesign-ui-${size.width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'deleting an activity asks about linked cues and undo restores both',
    (tester) async {
      final api = _DeskApi();
      api.doc['teacherCues'] = [
        {
          'id': 'linked',
          'activityId': 'one',
          'locator': {'kind': 'board', 'pageId': 'board-one'},
          'text': 'Keep this note',
        },
      ];
      await open(tester, api);
      await tester.ensureVisible(find.text('Xóa phần này'));
      await tester.tap(find.text('Xóa phần này'));
      await tester.pumpAndSettle();
      expect(find.text('Giữ lời nhắc theo trang'), findsOneWidget);
      await tester.tap(find.text('Xóa phần và lời nhắc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn tác'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        (api.doc['sections'] as List)
            .where((row) => row['id'] == 'one')
            .single['body'],
        'Câu hỏi cho cả lớp',
      );
      expect((api.doc['teacherCues'] as List).single['text'], 'Keep this note');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'orphan page cue stays unavailable until teacher explicitly remaps it',
    (tester) async {
      final api = _DeskApi();
      api.doc['teacherCues'] = [
        {
          'id': 'orphan',
          'locator': {'kind': 'board', 'pageId': 'deleted-board'},
          'text': 'Ghi chú trang cũ',
        },
      ];
      await open(tester, api);
      await tester.ensureVisible(find.text('Lời nhắc theo trang'));
      await tester.tap(find.text('Lời nhắc theo trang'));
      await tester.pumpAndSettle();
      expect(find.text('Lời nhắc cần gắn lại trang'), findsOneWidget);
      await tester.ensureVisible(find.text('Gắn vào trang đang chọn'));
      await tester.tap(find.text('Gắn vào trang đang chọn'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final cue = (api.doc['teacherCues'] as List).single;
      expect(cue['locator']['pageId'], 'board-one');
      expect(cue['text'], 'Ghi chú trang cũ');
      expect(find.text('Lời nhắc cần gắn lại trang'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'reuse existing lesson chooses source and opens an independent server duplicate',
    (tester) async {
      final api = _DeskApi()..doc['sections'] = [];
      String? opened;
      await open(tester, api, onOpenCopy: (id) => opened = id);
      await tester.tap(find.text('Dùng lại bài cũ'));
      await tester.pumpAndSettle();
      expect(find.text('Bài đang mở'), findsNothing);
      await tester.tap(find.text('Bài cũ trong thư viện'));
      await tester.pumpAndSettle();
      expect(api.duplicatedSource, 'plannings/source-lesson/duplicate');
      expect(opened, 'copied-lesson');
      expect(api.doc['sections'], isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'keeping page cues merges common notes and undo recovers both scopes',
    (tester) async {
      final api = _DeskApi();
      api.doc['teacherCues'] = [
        {
          'id': 'common',
          'locator': {'kind': 'board', 'pageId': 'board-one'},
          'text': 'Ghi chú chung',
        },
        {
          'id': 'scoped',
          'locator': {'kind': 'board', 'pageId': 'board-one'},
          'activityId': 'one',
          'text': 'Ghi chú hoạt động',
        },
      ];
      await open(tester, api);
      await tester.ensureVisible(find.text('Xóa phần này'));
      await tester.tap(find.text('Xóa phần này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giữ lời nhắc theo trang'));
      await tester.pumpAndSettle();
      // Read current controller state through the rendered editor before autosave,
      // then undo while preserving the explicit merge operation.
      await tester.pump(const Duration(milliseconds: 900));
      final kept = api.doc['teacherCues'] as List;
      expect(kept.length, 1);
      expect(kept.single['text'], contains('Ghi chú chung'));
      expect(kept.single['text'], contains('Ghi chú hoạt động'));
      await tester.tap(find.text('Hoàn tác'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final restored = api.doc['teacherCues'] as List;
      expect(restored.length, 2);
      expect(
        restored.where((cue) => cue['activityId'] == null).single['text'],
        'Ghi chú chung',
      );
      expect(
        restored.where((cue) => cue['activityId'] == 'one').single['text'],
        'Ghi chú hoạt động',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
