import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/meet_tutor/services/studio_tutor_session.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import '../classroom_meet/meet_tutor_delivery_test.dart'
    show seed, command, reply;
import 'tutor_controller_test.dart' show config;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'planning session cannot interrupt teaching; transfer pauses previous owner',
    () async {
      var cancellations = 0;
      final meet = MeetAutomationService.forTesting(
        executeScript: (script) async {
          if (script.contains('.cancelTutor(')) {
            cancellations++;
            return 'false';
          }
          return reply(command(script), 'READY');
        },
      );
      await seed(meet);
      final studio = StudioState();
      final first = StudioTutorSession(studio, meet: meet);
      first.controller.configure(config);
      first.controller.setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(first.controller.enabled, isTrue);
      final baseline = cancellations;
      final planning = StudioTutorSession(studio, meet: meet, active: false);
      planning.dispose();
      expect(cancellations, baseline);
      expect(first.controller.enabled, isTrue);
      final next = StudioTutorSession(studio, meet: meet);
      expect(first.controller.enabled, isFalse);
      first.dispose();
      next.dispose();
      meet.dispose();
      studio.dispose();
    },
  );
}
