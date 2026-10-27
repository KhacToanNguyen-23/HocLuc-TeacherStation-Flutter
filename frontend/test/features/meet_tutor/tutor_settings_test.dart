import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/meet_events.dart';
import 'package:teaching_companion/features/meet_tutor/domain/models/tutor_models.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_controller.dart';
import 'package:teaching_companion/features/meet_tutor/presentation/widgets/tutor_settings.dart';
import 'tutor_controller_test.dart' show FakeGateway;

void main() {
  late TutorController controller;
  late FakeGateway gateway;
  setUp(() {
    gateway = FakeGateway();
    controller = TutorController(
      gateway: gateway,
      context: (_) async =>
          const TutorContext(revision: 0, currentPage: 1, sources: []),
      contextRevision: () => 0,
      send: (_) async => false,
      sendInterval: Duration.zero,
    );
    controller.configure(
      const TutorConfig(baseUrl: '', model: '', useEnvironment: true),
    );
    controller.syncMeeting('room', true, []);
  });
  tearDown(() => controller.dispose());
  Future<void> mount(
    WidgetTester tester, {
    double width = 320,
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child: TutorSettings(controller: controller),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  testWidgets(
    'teacher controls expose no API configuration or provider information',
    (tester) async {
      await mount(tester);
      expect(find.text('Trợ giảng AI'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      for (final term in [
        'API',
        'Base URL',
        'Model',
        '.env',
        'Kiểm tra kết nối',
        'Áp dụng',
        'Nạp từ',
      ]) {
        expect(find.textContaining(term), findsNothing);
      }
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(controller.enabled, isTrue);
      controller.setEnabled(false);
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    },
  );
  testWidgets('recovery keeps intent on without claiming chat is ready', (
    tester,
  ) async {
    controller.setEnabled(true);
    controller.syncMeeting('room', true, [], observationReady: false);
    await mount(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Đang kết nối lại chat Meet…'), findsOneWidget);
    expect(find.text('Chờ kết nối chat'), findsOneWidget);
    expect(find.text('Sẵn sàng'), findsNothing);
    expect(find.textContaining('chưa nhận được câu hỏi mới'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(controller.enabled, isFalse);
    expect(controller.recovering, isFalse);
  });
  testWidgets('narrow status panel remains accessible and fits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, width: 240, scale: 1.5);
    expect(
      find.bySemanticsLabel('Tự động trả lời câu hỏi Meet'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets(
    'failure feedback and dismissible delivery log remain available',
    (tester) async {
      gateway.fail = true;
      controller.setEnabled(true);
      controller.syncMeeting('room', true, [
        const MeetChatMessage(
          id: '1',
          sender: 'An',
          text: 'Question',
          time: '10:00',
        ),
      ]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await mount(tester);
      expect(find.text('Nhật ký sự cố (1)'), findsOneWidget);
      await tester.ensureVisible(find.text('Bỏ qua'));
      await tester.tap(find.text('Bỏ qua'));
      await tester.pump();
      expect(controller.reviews, isEmpty);
      expect(find.textContaining('API'), findsNothing);
    },
  );
}
