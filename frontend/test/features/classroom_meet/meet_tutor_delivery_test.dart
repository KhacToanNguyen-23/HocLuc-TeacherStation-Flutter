import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';

const room = 'https://meet.google.com/abc-defg-hij';
Future<void> seed(MeetAutomationService service, {String doc = 'doc'}) async {
  service.setMeetingUrl(room);
  service.handleWebMessageForTesting({
    'type': 'MEET_BRIDGE_READY',
    'documentId': doc,
    'url': room,
  });
  service.handleWebMessageForTesting({
    'type': 'MEET_JOINED',
    'documentId': doc,
    'payload': {'url': room},
  });
  await service.beginTutorObservation();
}

Map<String, dynamic> command(String script) =>
    jsonDecode(
          script.substring(script.indexOf('({') + 1, script.indexOf(') :')),
        )
        as Map<String, dynamic>;
String reply(Map<String, dynamic> c, String status) => jsonEncode({
  'status': status,
  'requestId': c['requestId'],
  'documentId': c['documentId'],
  'url': c['url'],
});
MeetAutomationService testService({
  Future<String> Function(String)? executeScript,
  Duration tutorTimeout = const Duration(seconds: 10),
}) => MeetAutomationService.forTesting(
  tutorTimeout: tutorTimeout,
  executeScript: (script) async {
    if (script.contains('.beginTutorObservation(')) {
      final c = command(script);
      return reply(c, 'READY');
    }
    if (script.contains('.cancelTutor(')) return 'false';
    return await executeScript!(script);
  },
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'no joined current document means no command; manual signature preserved',
    () async {
      var calls = 0;
      final s = testService(
        executeScript: (_) async {
          calls++;
          return 'true';
        },
      );
      s.setMeetingUrl(room);
      expect(await s.sendTutorMessage('hello'), isFalse);
      expect(calls, 0);
      await seed(s);
      expect(await s.sendTutorMessage('  '), isFalse);
      expect(calls, 0);
      s.dispose();
      expect(await s.sendTutorMessage('hello'), isFalse);
    },
  );
  test(
    'serializes sends and succeeds only on correlated confirmation',
    () async {
      final calls = <Map<String, dynamic>>[];
      final s = testService(
        executeScript: (script) async {
          final c = command(script);
          calls.add(c);
          return reply(
            c,
            script.contains('.sendTutor(') ? 'PENDING' : 'CONFIRMED',
          );
        },
      );
      await seed(s);
      final first = s.sendTutorMessage('one');
      final second = s.sendTutorMessage('two');
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(calls.map((c) => c['text']), ['one', 'one', 'two', 'two']);
      expect(calls[0]['requestId'], isNot(calls[2]['requestId']));
      expect(s.messages, isEmpty); // no optimistic local tutor message
      s.dispose();
    },
  );
  test('booleans, exceptions and mismatched correlation fail closed', () async {
    for (final bad in ['bool', 'throw', 'requestId', 'documentId', 'url']) {
      final s = testService(
        executeScript: (script) async {
          if (bad == 'throw') throw StateError('transport');
          if (bad == 'bool') return 'true';
          final c = command(script);
          c[bad] = 'stale';
          return reply(c, 'CONFIRMED');
        },
      );
      await seed(s);
      expect(await s.sendTutorMessage('hello'), isFalse);
      s.dispose();
    }
  });
  test('pending and hung transport time out without success', () async {
    for (final hung in [false, true]) {
      final s = testService(
        tutorTimeout: const Duration(milliseconds: 30),
        executeScript: (script) => hung
            ? Completer<String>().future
            : Future.value(reply(command(script), 'PENDING')),
      );
      await seed(s);
      expect(await s.sendTutorMessage('hello'), isFalse);
      s.dispose();
    }
  });
  test(
    'room switch, reload, clear and dispose cancel active and queued sends',
    () async {
      for (final reset in ['room', 'reload', 'clear', 'dispose']) {
        final transport = Completer<String>();
        final calls = <Map<String, dynamic>>[];
        final s = testService(
          executeScript: (script) {
            calls.add(command(script));
            return transport.future;
          },
        );
        await seed(s);
        final first = s.sendTutorMessage('one');
        final queued = s.sendTutorMessage('two');
        await Future<void>.delayed(Duration.zero);
        switch (reset) {
          case 'room':
            s.setMeetingUrl('https://meet.google.com/xyz-abcd-efg');
          case 'reload':
            s.handleWebMessageForTesting({
              'type': 'MEET_BRIDGE_READY',
              'documentId': 'new',
              'url': room,
            });
          case 'clear':
            s.clearMeetingEvents();
          case 'dispose':
            s.dispose();
        }
        expect(await first.timeout(const Duration(seconds: 1)), isFalse);
        expect(await queued.timeout(const Duration(seconds: 1)), isFalse);
        transport.complete(reply(calls.single, 'CONFIRMED'));
        await Future<void>.delayed(Duration.zero);
        expect(calls.length, 1);
        if (reset != 'dispose') s.dispose();
      }
    },
  );
  test(
    'caller validity cancels queued dispatch and pending confirmation',
    () async {
      var valid = true;
      final transport = Completer<String>();
      final calls = <Map<String, dynamic>>[];
      final s = testService(
        executeScript: (script) {
          calls.add(command(script));
          return transport.future;
        },
      );
      await seed(s);
      final first = s.sendTutorMessage('one', stillCurrent: () => valid);
      final queued = s.sendTutorMessage('two', stillCurrent: () => valid);
      await Future<void>.delayed(Duration.zero);
      valid = false;
      transport.complete(reply(calls.single, 'CONFIRMED'));
      expect(await first, isFalse);
      expect(await queued, isFalse);
      expect(calls.length, 1);
      s.dispose();
    },
  );
  test('cancel preserves prepared observation for the next question', () async {
    final transport = Completer<String>();
    var calls = 0;
    final s = testService(
      executeScript: (script) {
        calls++;
        return calls == 1
            ? transport.future
            : Future.value(reply(command(script), 'CONFIRMED'));
      },
    );
    await seed(s);
    final first = s.sendTutorMessage('one');
    final queued = s.sendTutorMessage('two');
    await Future<void>.delayed(Duration.zero);
    s.cancelTutorSend();
    expect(await first, isFalse);
    expect(await queued, isFalse);
    transport.complete('null');
    expect(await s.sendTutorMessage('three'), isTrue);
    expect(calls, 2);
    s.dispose();
  });
  test('preparation requires authoritative current document READY', () async {
    for (final result in ['NOT_READY', 'READY']) {
      final s = MeetAutomationService.forTesting(
        executeScript: (script) async => reply(command(script), result),
      );
      await seed(s);
      expect(await s.beginTutorObservation(), result == 'READY');
      s.dispose();
    }
  });
  test(
    'chat eligibility requires prepared observation, current room and both document tokens',
    () async {
      final s = testService(executeScript: (_) async => 'null');
      await seed(s);
      var sequence = 0;
      void chat({
        String? doc = 'doc',
        String? source = 'doc',
        String url = room,
        bool eligible = true,
      }) {
        s.handleWebMessageForTesting({
          'type': 'CHAT_MESSAGE',
          'documentId': doc,
          'url': url,
          'payload': {
            'id': 'chat-${sequence++}',
            'sender': 'Student',
            'text': 'question',
            'isTutorEligible': eligible,
            'sourceDocumentId': source,
          },
        });
      }

      chat();
      expect(s.messages.last.isTutorEligible, isTrue);
      for (final invalid in ['doc', 'source', 'url', 'flag', 'missing']) {
        chat(
          doc: invalid == 'doc'
              ? 'old'
              : invalid == 'missing'
              ? null
              : 'doc',
          source: invalid == 'source' ? 'old' : 'doc',
          url: invalid == 'url' ? 'https://meet.google.com/xyz-abcd-efg' : room,
          eligible: invalid != 'flag',
        );
        expect(s.messages.last.isTutorEligible, isFalse);
      }
      s.cancelTutorSend();
      chat();
      expect(s.messages.last.isTutorEligible, isTrue);
      s.clearMeetingEvents();
      chat();
      expect(s.messages.last.isTutorEligible, isFalse);
      s.dispose();
    },
  );
  test(
    'baseline events emitted before preparation returns are ineligible',
    () async {
      late MeetAutomationService s;
      s = MeetAutomationService.forTesting(
        executeScript: (script) async {
          s.handleWebMessageForTesting({
            'type': 'CHAT_MESSAGE',
            'documentId': 'doc',
            'url': room,
            'payload': {
              'id': 'baseline',
              'isTutorEligible': true,
              'sourceDocumentId': 'doc',
            },
          });
          return reply(command(script), 'READY');
        },
      );
      await seed(s);
      expect(s.messages.single.isTutorEligible, isFalse);
      s.dispose();
    },
  );
}
