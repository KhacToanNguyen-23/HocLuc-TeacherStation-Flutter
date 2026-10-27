import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_inspector_panel.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_meet_cockpit_tab.dart';
import 'package:teaching_companion/features/meet_tutor/services/studio_tutor_session.dart';
import 'package:teaching_companion/features/meet_tutor/presentation/widgets/tutor_settings.dart';

void main() {
  testWidgets('requested settings and sharing tabs retain the studio tutor', (
    tester,
  ) async {
    final studio = StudioState();
    final session = StudioTutorSession(studio, active: false);
    final notes = TextEditingController();
    final question = TextEditingController();
    final endpoint = TextEditingController();
    Future<void> showPanel(int tab, int request) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 600,
              child: StudioInspectorPanel(
                studio: studio,
                tutor: session.controller,
                initialTab: tab,
                tabRequest: request,
                notesController: notes,
                questionController: question,
                endpointController: endpoint,
                onPreview: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showPanel(2, 0);
    final cockpit = tester.state(
      find.byType(StudioMeetCockpitTab, skipOffstage: false),
    );
    expect(find.text('Trợ giảng AI'), findsOneWidget);
    expect(
      tester.widget<TutorSettings>(find.byType(TutorSettings)).controller,
      same(session.controller),
    );
    await showPanel(1, 1);
    expect(
      tester.state(find.byType(StudioMeetCockpitTab, skipOffstage: false)),
      same(cockpit),
    );
    expect(
      tester
          .widget<StudioMeetCockpitTab>(
            find.byType(StudioMeetCockpitTab, skipOffstage: false),
          )
          .sharingPanel,
      isTrue,
    );
    await showPanel(2, 2);
    expect(find.text('Trợ giảng AI'), findsOneWidget);
    expect(
      tester.widget<TutorSettings>(find.byType(TutorSettings)).controller,
      same(session.controller),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    void listener() {}
    session.controller.addListener(listener);
    session.controller.removeListener(listener);
    session.dispose();
    studio.dispose();
    notes.dispose();
    question.dispose();
    endpoint.dispose();
  });

  testWidgets('StudioInspectorPanel renders live cockpit tabs and chat', (
    tester,
  ) async {
    final studio = StudioState();
    final notesController = TextEditingController();
    final questionController = TextEditingController();
    final endpointController = TextEditingController();

    final meetService = MeetAutomationService();
    meetService.setMeetingUrl('https://meet.google.com/abc-defg-hij');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 600,
            child: StudioInspectorPanel(
              studio: studio,
              notesController: notesController,
              questionController: questionController,
              endpointController: endpointController,
              onPreview: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Meet'), findsOneWidget);
    expect(find.text('Chia sẻ'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Chuẩn bị Google Meet'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('Tắt tiếng cả lớp'), findsOneWidget);

    // Test send message via input
    await tester.enterText(find.byType(TextField).first, 'Chào các em!');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Chào các em!'), findsOneWidget);
    expect(find.text('Tôi (Giáo viên)'), findsOneWidget);

    final cockpitState = tester.state(
      find.byType(StudioMeetCockpitTab, skipOffstage: false),
    );
    await tester.enterText(find.byType(TextField).first, 'Bản nháp chưa gửi');
    await tester.tap(find.text('Chia sẻ'));
    await tester.pumpAndSettle();
    expect(
      tester.state(find.byType(StudioMeetCockpitTab, skipOffstage: false)),
      same(cockpitState),
    );
    expect(
      tester
          .widget<StudioMeetCockpitTab>(
            find.byType(StudioMeetCockpitTab, skipOffstage: false),
          )
          .sharingPanel,
      isTrue,
    );

    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();

    expect(find.text('Trợ giảng AI'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('API'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('ĐẦU RA CHO MEETING'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ĐẦU RA CHO MEETING'), findsOneWidget);

    await tester.tap(find.text('Meet'));
    await tester.pumpAndSettle();
    expect(
      tester.state(find.byType(StudioMeetCockpitTab, skipOffstage: false)),
      same(cockpitState),
    );
    expect(
      tester
          .widget<StudioMeetCockpitTab>(
            find.byType(StudioMeetCockpitTab, skipOffstage: false),
          )
          .sharingPanel,
      isFalse,
    );
    expect(find.text('Bản nháp chưa gửi'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    meetService.clearMeetingEvents();
    studio.dispose();

    notesController.dispose();
    questionController.dispose();
    endpointController.dispose();
  });
}
