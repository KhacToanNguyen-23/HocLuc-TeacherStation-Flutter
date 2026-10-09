import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/main.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/local_service.dart';

void main() {
  test(
    'lesson pages, notes and settings survive a save/reload through API contract',
    () async {
      final storage = <String, dynamic>{};
      final client = MockClient((request) async {
        final path = request.url.path.split('/').last;
        if (path == 'bootstrap') {
          return http.Response('{"token":"local-test"}', 200);
        }
        expect(request.headers['X-Companion-Token'], 'local-test');
        if (request.method == 'PUT') {
          storage[path] = jsonDecode(request.body);
          return http.Response('{"saved":true}', 200);
        }
        return http.Response(
          jsonEncode(
            path == 'devices' ? {'microphones': []} : storage[path] ?? {},
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = LocalService(client: client);
      final state = StudioState(service: service);
      await state.initialize();
      state.change(() {
        state.page = 2;
        state.notes = 'Ghi chú riêng';
        state.endpoint = 'https://self-hosted.example';
      });
      state.startStroke(const Offset(.3, .2));
      state.extendStroke(const Offset(.4, .4));
      expect(await state.save(), true);
      expect(state.dirty, false);
      state.pages = [[], [], []];
      state.notes = '';
      state.endpoint = '';
      await state.initialize();
      expect(state.page, 2);
      expect(state.online, true);
      expect(state.strokes.single.points.last, const Offset(.4, .4));
      expect(state.notes, 'Ghi chú riêng');
      expect(state.endpoint, 'https://self-hosted.example');
      state.dispose();
    },
  );

  test('failed persistence retains unsaved state', () async {
    final state = StudioState(
      service: LocalService(
        client: MockClient((_) async => http.Response('offline', 503)),
      ),
    );
    state.change(() => state.notes = 'keep this');
    expect(await state.save(), false);
    expect(state.dirty, true);
    expect(state.notes, 'keep this');
    state.dispose();
  });

  test('edits made while saving remain marked unsaved', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final service = LocalService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('bootstrap')) {
          return http.Response('{"token":"test"}', 200);
        }
        if (request.url.path.endsWith('lesson')) {
          started.complete();
          await gate.future;
        }
        return http.Response('{}', 200);
      }),
    );
    await service.connect();
    final state = StudioState(service: service);
    state.change(() => state.notes = 'before');
    final saving = state.save();
    await started.future;
    state.change(() => state.notes = 'after');
    gate.complete();
    expect(await saving, true);
    expect(state.dirty, true);
    expect(state.notes, 'after');
    state.dispose();
  });

  for (final size in [
    const Size(1440, 900),
    const Size(1024, 768),
    const Size(760, 680),
  ]) {
    testWidgets('desktop shell fits ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = StudioState()..loading = false;
      await tester.pumpWidget(
        MaterialApp(home: StudioScreen(initialState: state)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Câu hỏi'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Xem khung trình bày'));
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('Q1 A / Q1 B'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
