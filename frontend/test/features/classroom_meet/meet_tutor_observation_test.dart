import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_controller.dart';
import 'package:teaching_companion/features/meet_tutor/domain/models/tutor_models.dart';
import '../meet_tutor/tutor_controller_test.dart'
    show FakeGateway, source, config;
import 'meet_tutor_delivery_test.dart' show room, command, reply;

void connect(MeetAutomationService service) {
  service.setMeetingUrl(room);
  service.handleWebMessageForTesting({
    'type': 'MEET_BRIDGE_READY',
    'documentId': 'doc',
    'url': room,
  });
  service.handleWebMessageForTesting({
    'type': 'MEET_JOINED',
    'documentId': 'doc',
    'url': room,
    'payload': {'url': room},
  });
}

void chat(MeetAutomationService service, String id, {String? observationId}) =>
    service.handleWebMessageForTesting({
      'type': 'CHAT_MESSAGE',
      'documentId': 'doc',
      'url': room,
      'payload': {
        'id': id,
        'sender': 'An',
        'text': 'What is a triangle?',
        'time': '10:00',
        'sourceDocumentId': 'doc',
        'observationId': observationId,
        'isTutorEligible': true,
        'isSelf': false,
      },
    });

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one enable waits for chat and answers new messages without any mounted Meet panel',
    () async {
      var prepares = 0, sends = 0;
      String? observationId;
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          if (script.contains('.endTutorObservation(') ||
              script.contains('.cancelTutor(')) {
            return 'false';
          }
          final c = command(script);
          if (script.contains('.beginTutorObservation(')) {
            prepares++;
            observationId = c['observationId'] as String;
            return reply(c, prepares < 3 ? 'PENDING' : 'READY');
          }
          sends++;
          return reply(c, 'CONFIRMED');
        },
      );
      connect(service);
      final gateway = FakeGateway();
      final tutor = TutorController(
        gateway: gateway,
        context: (_) async =>
            const TutorContext(revision: 0, currentPage: 1, sources: [source]),
        contextRevision: () => 0,
        send: service.sendTutorMessage,
        prepareObservation: service.beginTutorObservation,
        stopObservation: service.stopTutorObservation,
        cancelSend: service.cancelTutorSend,
        preparationError: () => service.tutorObservationError,
        sendInterval: Duration.zero,
      );
      void sync() => tutor.syncMeeting(
        service.meetingUrl,
        service.isHostJoined,
        service.messages,
      );
      service.addListener(sync);
      sync();
      tutor.configure(config);
      tutor.setEnabled(true);
      expect(tutor.starting, isTrue);
      chat(service, 'history');
      await until(() => tutor.enabled);
      expect(prepares, 3);
      expect(gateway.calls, 0);
      chat(service, 'new', observationId: observationId);
      await until(() => sends == 1);
      expect(gateway.calls, 1);
      tutor.setEnabled(false);
      expect(service.isTutorObservationReady, isFalse);
      chat(service, 'paused');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sends, 1);
      service.removeListener(sync);
      tutor.dispose();
      service.dispose();
    },
  );

  test(
    'stop cancels hung preparation and a late old readiness cannot replace a new lease',
    () async {
      final first = Completer<String>();
      Map<String, dynamic>? old;
      var prepares = 0;
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          if (script.contains('.endTutorObservation(')) return 'false';
          final c = command(script);
          if (++prepares == 1) {
            old = c;
            return first.future;
          }
          return reply(c, 'READY');
        },
      );
      connect(service);
      final stale = service.beginTutorObservation();
      service.stopTutorObservation();
      expect(await service.beginTutorObservation(), isTrue);
      expect(await stale.timeout(const Duration(milliseconds: 500)), isFalse);
      first.complete(reply(old!, 'READY'));
      await Future<void>.delayed(Duration.zero);
      expect(service.isTutorObservationReady, isTrue);
      service.stopTutorObservation();
      service.handleWebMessageForTesting({
        'type': 'TUTOR_OBSERVATION_STATE',
        'documentId': 'doc',
        'url': room,
        'payload': {'observationId': old!['observationId'], 'ready': true},
      });
      chat(service, 'after-stop');
      expect(service.isTutorObservationReady, isFalse);
      expect(service.messages.last.isTutorEligible, isFalse);
      service.dispose();
    },
  );

  test(
    'sending waits for automatic chat recovery using the same observation lease',
    () async {
      var prepares = 0, sends = 0;
      Map<String, dynamic>? observation;
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          if (script.contains('.endTutorObservation(')) return 'false';
          final c = command(script);
          if (script.contains('.beginTutorObservation(')) {
            prepares++;
            observation ??= c;
            expect(c['observationId'], observation!['observationId']);
            return reply(c, prepares == 2 ? 'PENDING' : 'READY');
          }
          sends++;
          return reply(c, 'CONFIRMED');
        },
      );
      connect(service);
      expect(await service.beginTutorObservation(), isTrue);
      service.handleWebMessageForTesting({
        'type': 'TUTOR_OBSERVATION_STATE',
        'documentId': 'doc',
        'url': room,
        'payload': {
          'observationId': observation!['observationId'],
          'ready': false,
        },
      });
      expect(service.isTutorObservationReady, isFalse);
      expect(await service.sendTutorMessage('Recovered reply'), isTrue);
      expect(sends, 1);
      expect(service.isTutorObservationReady, isTrue);
      service.dispose();
    },
  );

  test('a cancelled send does not wait for hung chat recovery', () async {
    final recovery = Completer<String>();
    final recovering = Completer<void>();
    var prepares = 0;
    Map<String, dynamic>? last;
    final service = MeetAutomationService.forTesting(
      executeScript: (script) async {
        if (script.contains('.endTutorObservation(') ||
            script.contains('.cancelTutor(')) {
          return 'false';
        }
        final c = command(script);
        last = c;
        if (++prepares == 1) return reply(c, 'READY');
        if (!recovering.isCompleted) recovering.complete();
        return recovery.future;
      },
    );
    connect(service);
    expect(await service.beginTutorObservation(), isTrue);
    service.handleWebMessageForTesting({
      'type': 'TUTOR_OBSERVATION_STATE',
      'documentId': 'doc',
      'url': room,
      'payload': {'observationId': last!['observationId'], 'ready': false},
    });
    final pending = service.sendTutorMessage('obsolete');
    await recovering.future;
    service.cancelTutorSend();
    expect(await pending.timeout(const Duration(milliseconds: 500)), isFalse);
    service.dispose();
    recovery.complete(reply(last!, 'READY'));
  });
  test(
    'missing Meet produces a useful failure without asking the teacher to open chat',
    () async {
      final service = MeetAutomationService.forTesting();
      expect(await service.beginTutorObservation(), isFalse);
      expect(service.tutorObservationError, contains('Vào phòng Meet'));
      expect(service.tutorObservationError, isNot(contains('mở chat')));
      service.dispose();
    },
  );
}
