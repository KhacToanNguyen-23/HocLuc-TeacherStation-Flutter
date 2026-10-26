import '../../classroom_meet/services/meet_automation_service.dart';
import '../../studio_board/domain/models/studio_state.dart';
import 'studio_tutor_context.dart';
import 'tutor_controller.dart';
import 'tutor_gateway.dart';

/// One tutor session belongs to the studio route, independently of panel mounts.
class StudioTutorSession {
  StudioTutorSession(
    StudioState studio, {
    MeetAutomationService? meet,
    bool active = true,
  }) : _meet = meet ?? MeetAutomationService(),
       _context = StudioTutorContext(studio) {
    if (active) {
      _owner?.controller.setEnabled(false);
      _owner = this;
    }
    controller = TutorController(
      gateway: CompanionTutorGateway(studio.service),
      context: _context.build,
      contextRevision: () => _context.revision,
      send: _meet.sendTutorMessage,
      detailedSend: (text, valid) =>
          _meet.sendTutorMessageDetailed(text, stillCurrent: valid),
      prepareObservation: () async =>
          identical(_owner, this) && await _meet.beginTutorObservation(),
      cancelSend: () {
        if (identical(_owner, this)) _meet.cancelTutorSend();
      },
    );
    _context.addListener(controller.contextChanged);
    _sync();
    _meet.addListener(_sync);
  }

  static StudioTutorSession? _owner;
  final MeetAutomationService _meet;
  final StudioTutorContext _context;
  late final TutorController controller;

  void _sync() {
    if (!identical(_owner, this)) return;
    controller.syncMeeting(
      _meet.meetingUrl,
      _meet.isHostJoined,
      _meet.messages,
    );
  }

  void dispose() {
    _meet.removeListener(_sync);
    _context.removeListener(controller.contextChanged);
    controller.dispose();
    if (identical(_owner, this)) _owner = null;
    _context.dispose();
  }
}
