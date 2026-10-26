import 'dart:async';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/meet_tutor/presentation/widgets/tutor_header_toggle.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_controller.dart';
import 'tutor_controller_test.dart' show FakeGateway, config;

void main() {
  late TutorController controller;
  late Completer<bool> ready;
  late int configureCalls;
  setUp(() {
    ready = Completer<bool>.sync();
    configureCalls = 0;
    controller = TutorController(
      gateway: FakeGateway(),
      context: (_) async => throw UnimplementedError(),
      contextRevision: () => 0,
      send: (_) async => true,
      prepareObservation: () => ready.future,
    );
    controller.syncMeeting('room', true, []);
  });
  tearDown(() => controller.dispose());
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TutorHeaderToggle(
          controller: controller,
          onConfigure: () => configureCalls++,
        ),
      ),
    ),
  );
  testWidgets('live header keeps AI control visible at supported widths', (
    tester,
  ) async {
    final studio = StudioState();
    for (final width in [760.0, 800.0, 1024.0, 1440.0]) {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StudioTopBar(
                  studio: studio,
                  tutor: controller,
                  width: width,
                  onToggleInspector: () {},
                  onRename: () {},
                  onSave: () {},
                  onRetryConnect: () {},
                  onToggleStudents: () {},
                  onTogglePlugins: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('tutor-header-toggle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    studio.dispose();
  });
  testWidgets('icon only opens configuration when missing', (tester) async {
    await mount(tester);
    expect(find.byType(Text), findsNothing);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.toggle_off_outlined), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(configureCalls, 1);
    expect(controller.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('enable handshake and disable stay synchronized', (tester) async {
    controller.configure(config);
    await mount(tester);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(controller.starting, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready.complete(true);
    await tester.pump();
    expect(controller.enabled, isTrue);
    expect(find.byIcon(Icons.toggle_on_rounded), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(controller.enabled, isFalse);
    expect(find.byIcon(Icons.toggle_off_outlined), findsOneWidget);
    await tester.runAsync(() async {
      controller.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(find.byIcon(Icons.toggle_on_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unapplied configuration cannot be enabled from header', (
    tester,
  ) async {
    controller.configure(config);
    controller.markConfigurationPending();
    await mount(tester);
    await tester.tap(find.byType(IconButton));
    expect(configureCalls, 1);
    expect(controller.starting, isFalse);
    expect(controller.enabled, isFalse);
  });
  testWidgets('second click cancels pending enable without late activation', (
    tester,
  ) async {
    controller.configure(config);
    await mount(tester);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    ready.complete(true);
    await tester.pump();
    expect(controller.starting, isFalse);
    expect(controller.enabled, isFalse);
    expect(find.byIcon(Icons.toggle_off_outlined), findsOneWidget);
  });
}
