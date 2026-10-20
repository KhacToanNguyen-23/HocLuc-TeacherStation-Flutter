import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/select_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';

void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final samplePlan = PlanningMeta(
    id: 'plan_test_01',
    title: 'Toán 12 - Tích phân từng phần',
    subject: 'Toán',
    pageCount: 3,
    createdAt: now,
    updatedAt: now,
  );

  final courses = <Map<String, dynamic>>[
    {
      'id': 'class-large',
      'title': 'Lớp 11A1',
      'students': [
        {'email': 'one@example.com'},
        {'email': 'two@example.com'},
      ],
      'meetingUrl': 'https://meet.google.com/abc-defg-hij',
    },
    {
      'id': 'class-small',
      'title': 'Lớp 12A1',
      'students': [
        {'email': 'three@example.com'},
      ],
      'meetingUrl': 'https://meet.google.com/abc-defg-hij',
    },
    {'id': 'class-empty', 'title': 'Lớp trống', 'students': <Object>[]},
  ];

  GoogleWorkspaceApi createApi() => GoogleWorkspaceApi(
    email: 'teacher@example.com',
    client: MockClient((request) async {
      final Object response;
      if (request.url.path == '/api/bootstrap') {
        response = {'token': 'local'};
      } else if (request.url.path.endsWith('/status')) {
        response = {'configured': true, 'connected': true};
      } else if (request.url.path.endsWith('/courses')) {
        response = {'courses': courses};
      } else {
        return http.Response('{}', 404);
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode(response)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );

  Future<void> openDialog(
    WidgetTester tester, {
    required GoogleWorkspaceApi api,
    Future<void> Function(TeachingTarget)? onLaunch,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SelectClassroomDialog.show(
                context,
                plan: samplePlan,
                googleApi: api,
                onLaunch: onLaunch,
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  group('SelectClassroomDialog', () {
    testWidgets('renders plan details, search, and Google Classroom courses', (
      tester,
    ) async {
      final api = createApi();
      await openDialog(tester, api: api);

      expect(find.text('Chọn lớp để bắt đầu dạy'), findsOneWidget);
      expect(find.text('Toán 12 - Tích phân từng phần'), findsOneWidget);
      expect(find.text('Toán'), findsOneWidget);
      expect(find.text('LỚP TỪ GOOGLE CLASSROOM'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Lớp 11A1'), findsOneWidget);
      expect(find.text('Lớp 12A1'), findsOneWidget);
      expect(find.text('Lớp trống'), findsOneWidget);
      expect(find.text('LỚP HỌC TIÊU CHUẨN'), findsNothing);
      expect(find.text('Nhập tên lớp khác'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    });

    testWidgets('sorts by student count and disables empty classes', (
      tester,
    ) async {
      final api = createApi();
      await openDialog(tester, api: api);

      final large = tester.getTopLeft(find.text('Lớp 11A1'));
      final small = tester.getTopLeft(find.text('Lớp 12A1'));
      expect(large.dy, lessThan(small.dy));
      expect(find.text('2 học sinh'), findsOneWidget);
      expect(find.text('1 học sinh'), findsOneWidget);
      expect(find.text('0 học sinh · Không thể chọn'), findsOneWidget);

      await tester.tap(find.text('Lớp trống'));
      await tester.pump();
      expect(find.text('Xác nhận & Bắt đầu dạy'), findsOneWidget);
      expect(
        tester.widget<InkWell>(
          find.ancestor(
            of: find.text('Lớp trống'),
            matching: find.byType(InkWell),
          ).first,
        ).onTap,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    });

    testWidgets('searches and selects a matching course', (
      tester,
    ) async {
      final api = createApi();
      TeachingTarget? launchedTarget;
      await openDialog(
        tester,
        api: api,
        onLaunch: (target) async => launchedTarget = target,
      );

      await tester.enterText(find.byType(TextField), '12a1');
      await tester.pumpAndSettle();
      expect(find.text('Lớp 12A1'), findsOneWidget);
      expect(find.text('Lớp 11A1'), findsNothing);
      await tester.tap(find.text('Lớp 12A1'));
      await tester.pump();

      await tester.tap(find.text('Xác nhận & Bắt đầu dạy'));
      await tester.pumpAndSettle();

      expect(launchedTarget, isNotNull);
      expect(launchedTarget!.planningId, 'plan_test_01');
      expect(launchedTarget!.courseId, 'class-small');
      expect(launchedTarget!.title, contains('Lớp 12A1'));
      expect(launchedTarget!.title, contains('Toán 12 - Tích phân từng phần'));
      expect(
        launchedTarget!.meetingUrl,
        'https://meet.google.com/abc-defg-hij',
      );
      expect(find.text('Chọn lớp để bắt đầu dạy'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    });

    testWidgets('restores selection after clearing a search filter', (
      tester,
    ) async {
      final api = createApi();
      TeachingTarget? launchedTarget;
      await openDialog(
        tester,
        api: api,
        onLaunch: (target) async => launchedTarget = target,
      );

      await tester.enterText(find.byType(TextField), 'does-not-match');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy lớp phù hợp.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận & Bắt đầu dạy'));
      await tester.pumpAndSettle();

      expect(launchedTarget?.courseId, 'class-large');
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    });

    testWidgets('dismisses dialog when clicking Hủy', (tester) async {
      final api = createApi();
      var called = false;
      await openDialog(
        tester,
        api: api,
        onLaunch: (_) async => called = true,
      );

      expect(find.text('Chọn lớp để bắt đầu dạy'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('Chọn lớp để bắt đầu dạy'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    });
  });
}
