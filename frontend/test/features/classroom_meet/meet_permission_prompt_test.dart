import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'package:teaching_companion/features/classroom_meet/presentation/meet_webview.dart';

void main() {
  testWidgets(
    'shared controller permissions survive closing the latest Meet surface',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: MeetPermissionPrompt.navigatorKey,
          home: const Scaffold(),
        ),
      );
      final session = MeetPermissionSession();
      session.attach(); // cockpit
      session.attach(); // small overlay replaces the plugin callback
      final installedCallback = session.request;
      session.detach(); // close overlay; cockpit remains
      final camera = installedCallback(
        'https://meet.google.com/abc-defg-hij',
        win.WebviewPermissionKind.camera,
        true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cho phép'));
      await tester.pumpAndSettle();
      expect(await camera, win.WebviewPermissionDecision.allow);
      final mic = installedCallback(
        'https://meet.google.com/abc-defg-hij',
        win.WebviewPermissionKind.microphone,
        true,
      );
      await tester.pumpAndSettle();
      session.detach(); // close last view while permission is pending
      await tester.pumpAndSettle();
      expect(await mic, win.WebviewPermissionDecision.deny);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'closing the Meet surface cancels its pending permission dialog',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: MeetPermissionPrompt.navigatorKey,
          home: const Scaffold(),
        ),
      );
      final cancelled = Completer<void>();
      final decision = MeetPermissionPrompt.request(
        'https://meet.google.com/abc-defg-hij',
        win.WebviewPermissionKind.microphone,
        isActive: () => !cancelled.isCompleted,
        cancelled: cancelled.future,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      cancelled.complete();
      await tester.pumpAndSettle();
      expect(await decision, win.WebviewPermissionDecision.deny);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'permission buttons remain clickable above the global Meet panel',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: MeetPermissionPrompt.navigatorKey,
          builder: (context, child) => Overlay.wrap(
            child: Stack(
              children: [
                child!,
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          home: const Scaffold(),
        ),
      );
      final decision = MeetPermissionPrompt.request(
        'https://meet.google.com/abc-defg-hij',
        win.WebviewPermissionKind.camera,
        isActive: () => true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cho phép'));
      await tester.pumpAndSettle();
      expect(await decision, win.WebviewPermissionDecision.allow);
    },
  );

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: MeetPermissionPrompt.navigatorKey,
      home: const Scaffold(body: Text('Meet panel')),
    ),
  );
  Future<win.WebviewPermissionDecision> request(
    win.WebviewPermissionKind kind, {
    String url = 'https://meet.google.com/abc-defg-hij',
    bool Function()? isActive,
  }) =>
      MeetPermissionPrompt.request(url, kind, isActive: isActive ?? () => true);

  testWidgets('real Flutter Allow and Deny buttons resolve native requests', (
    tester,
  ) async {
    await mount(tester);
    final camera = request(win.WebviewPermissionKind.camera);
    await tester.pumpAndSettle();
    expect(find.textContaining('truy cập camera?'), findsOneWidget);
    await tester.tap(find.text('Cho phép'));
    await tester.pumpAndSettle();
    expect(await camera, win.WebviewPermissionDecision.allow);

    final mic = request(win.WebviewPermissionKind.microphone);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Không cho phép'));
    await tester.pumpAndSettle();
    expect(await mic, win.WebviewPermissionDecision.deny);
  });

  testWidgets(
    'simultaneous camera and mic requests show one dialog at a time',
    (tester) async {
      await mount(tester);
      final camera = request(win.WebviewPermissionKind.camera);
      final mic = request(win.WebviewPermissionKind.microphone);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('truy cập camera?'), findsOneWidget);
      await tester.tap(find.text('Cho phép'));
      await tester.pumpAndSettle();
      expect(await camera, win.WebviewPermissionDecision.allow);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('truy cập microphone?'), findsOneWidget);
      await tester.tap(find.text('Không cho phép'));
      await tester.pumpAndSettle();
      expect(await mic, win.WebviewPermissionDecision.deny);
    },
  );

  testWidgets(
    'dismissal denies, and a disposed surface cannot grant permission',
    (tester) async {
      await mount(tester);
      final dismissed = request(win.WebviewPermissionKind.camera);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await dismissed, win.WebviewPermissionDecision.deny);

      var active = true;
      final stale = request(
        win.WebviewPermissionKind.camera,
        isActive: () => active,
      );
      await tester.pumpAndSettle();
      active = false;
      await tester.tap(find.text('Cho phép'));
      await tester.pumpAndSettle();
      expect(await stale, win.WebviewPermissionDecision.deny);
    },
  );

  test(
    'other origins, malformed URLs, unsupported permissions and inactive views deny',
    () async {
      for (final url in [
        'not a url',
        'http://meet.google.com',
        'https://meet.google.com.evil.test',
        'https://meet.google.com:444',
      ]) {
        expect(
          await request(win.WebviewPermissionKind.camera, url: url),
          win.WebviewPermissionDecision.deny,
        );
      }
      expect(
        await request(win.WebviewPermissionKind.geoLocation),
        win.WebviewPermissionDecision.deny,
      );
      expect(
        await request(win.WebviewPermissionKind.camera, isActive: () => false),
        win.WebviewPermissionDecision.deny,
      );
    },
  );
}

