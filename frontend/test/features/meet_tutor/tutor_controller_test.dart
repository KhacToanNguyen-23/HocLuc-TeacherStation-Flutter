import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/meet_events.dart';
import 'package:teaching_companion/features/meet_tutor/domain/models/tutor_models.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_controller.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_gateway.dart';

const source = TutorSource(
  id: 'p1',
  label: 'Trang 1',
  text: 'A triangle has three sides.',
);
const supported = TutorResult(
  answer: 'A triangle has three sides.',
  evidence: {'p1': 'A triangle has three sides.'},
);
const config = TutorConfig(baseUrl: 'https://example.test/v1', model: 'test');
MeetChatMessage question(
  String id, {
  String text = 'What is a triangle?',
  bool self = false,
}) => MeetChatMessage(
  id: id,
  sender: 'An',
  text: text,
  time: '10:00',
  isSelf: self,
);

class FakeGateway implements TutorGateway {
  int calls = 0;
  TutorResult result = supported;
  Completer<TutorResult>? pending;
  bool fail = false;
  @override
  Future<void> test(TutorConfig config) async {}
  @override
  Future<TutorResult> answer(
    TutorConfig config,
    String question,
    TutorContext context,
  ) async {
    calls++;
    if (fail) throw StateError('private provider error');
    return pending == null ? result : pending!.future;
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 15));

void main() {
  late FakeGateway gateway;
  late TutorController controller;
  late List<String> sent;
  late int revision;
  late bool confirmed;
  late List<TutorSource> sources;
  setUp(() {
    gateway = FakeGateway();
    sent = [];
    revision = 1;
    confirmed = true;
    sources = [source];
    controller = TutorController(
      gateway: gateway,
      context: (_) async =>
          TutorContext(revision: revision, currentPage: 1, sources: sources),
      contextRevision: () => revision,
      send: (text) async {
        sent.add(text);
        return confirmed;
      },
      sendInterval: Duration.zero,
    );
    controller.syncMeeting('room1', true, []);
    controller.configure(config);
    controller.setEnabled(true);
  });
  tearDown(() => controller.dispose());

  test(
    'proven pre-dispatch cancellation gets a changed-context notice without retrying old answer',
    () async {
      final release = Completer<void>();
      final tutor = TutorController(
        gateway: gateway,
        context: (_) async =>
            TutorContext(revision: revision, currentPage: 1, sources: sources),
        contextRevision: () => revision,
        send: (_) async => false,
        sendInterval: Duration.zero,
        detailedSend: (text, valid) async {
          await release.future;
          if (!valid()) return MeetTutorDelivery.notDispatched;
          sent.add(text);
          return MeetTutorDelivery.confirmed;
        },
      );
      addTearDown(tutor.dispose);
      tutor.syncMeeting('room1', true, []);
      tutor.configure(config);
      tutor.setEnabled(true);
      tutor.syncMeeting('room1', true, [question('race')]);
      await settle();
      revision++;
      tutor.contextChanged();
      release.complete();
      await settle();
      expect(sent.single, contains(TutorController.changedReply));
      expect(sent.single, isNot(contains(source.text)));
      expect(tutor.reviews, isEmpty);
    },
  );

  test(
    'uncertain transport never triggers a second fallback that could duplicate a sent message',
    () async {
      var attempts = 0;
      final tutor = TutorController(
        gateway: gateway,
        context: (_) async =>
            TutorContext(revision: revision, currentPage: 1, sources: sources),
        contextRevision: () => revision,
        send: (_) async => false,
        detailedSend: (_, _) async {
          attempts++;
          revision++;
          return MeetTutorDelivery.unconfirmed;
        },
      );
      addTearDown(tutor.dispose);
      tutor.syncMeeting('room1', true, []);
      tutor.configure(config);
      tutor.setEnabled(true);
      tutor.syncMeeting('room1', true, [question('ambiguous')]);
      await settle();
      expect(attempts, 1);
      expect(tutor.reviews, hasLength(1));
    },
  );

  test(
    'out-of-scope question always gets the canonical classroom reply',
    () async {
      gateway.result = const TutorResult(
        answer: 'Do not forward this unrelated answer.',
        evidence: {},
        confidence: TutorConfidence.outOfScope,
      );
      controller.syncMeeting('room1', true, [
        question('daily', text: 'What should I eat today?'),
      ]);
      await settle();
      expect(
        sent.single,
        '[Trợ giảng AI] @An: Không nằm trong nội dung bài học',
      );
      expect(controller.reviews, isEmpty);
    },
  );

  test(
    'a question without punctuation or recognized keywords still receives a reply',
    () async {
      controller.syncMeeting('room1', true, [
        question('plain', text: 'em hỏi cách làm bước này'),
      ]);
      await settle();
      expect(sent, hasLength(1));
    },
  );

  test(
    'burst overflow produces busy replies and continues queued questions',
    () async {
      gateway.pending = Completer();
      controller.syncMeeting(
        'room1',
        true,
        List.generate(25, (i) => question('$i', text: 'Question $i?')),
      );
      await settle();
      gateway.pending!.complete(supported);
      await settle();
      await settle();
      expect(sent, hasLength(21));
      expect(sent.where((m) => m.contains('Hệ thống đang bận')), hasLength(1));
      expect(sent.last, contains('Thông báo chung'));
      expect(gateway.calls, 20);
    },
  );

  test(
    'overlong question gets a fixed response without calling the provider',
    () async {
      controller.syncMeeting('room1', true, [
        question('long', text: 'x' * 1600),
      ]);
      await settle();
      expect(gateway.calls, 0);
      expect(sent.single, contains('Câu hỏi quá dài'));
    },
  );

  test(
    'exception in context extraction is also answered without exposing exception',
    () async {
      final tutor = TutorController(
        gateway: gateway,
        context: (_) async => throw StateError('private path or key'),
        contextRevision: () => revision,
        send: (text) async {
          sent.add(text);
          return true;
        },
      );
      addTearDown(tutor.dispose);
      tutor.syncMeeting('room1', true, []);
      tutor.configure(config);
      tutor.setEnabled(true);
      tutor.syncMeeting('room1', true, [question('error')]);
      await settle();
      expect(sent.single, contains(TutorController.apiFailureReply));
      expect(sent.single, isNot(contains('private')));
    },
  );

  test(
    'answers each distinct message even for repeated questions and ignores self',
    () async {
      final messages = [
        question('1'),
        question('2', self: true),
        question('3', text: '[Trợ giảng AI] why?'),
      ];
      controller.syncMeeting('room1', true, messages);
      await settle();
      controller.syncMeeting('room1', true, [...messages, question('4')]);
      await settle();
      expect(gateway.calls, 2);
      expect(sent, hasLength(2));
      expect(controller.sentCount, 2);
      expect(sent.first, contains('Nguồn: Trang 1'));
    },
  );
  test('does not replay questions seen while paused', () async {
    controller.setEnabled(false);
    controller.syncMeeting('room1', true, [question('old')]);
    controller.setEnabled(true);
    controller.syncMeeting('room1', true, [question('old')]);
    await settle();
    expect(gateway.calls, 0);
  });
  test('pause discards in-flight completion', () async {
    gateway.pending = Completer();
    controller.syncMeeting('room1', true, [question('1')]);
    await settle();
    controller.setEnabled(false);
    gateway.pending!.complete(supported);
    await settle();
    expect(sent, isEmpty);
  });
  test(
    'context change rejects completion and queued questions from old page',
    () async {
      gateway.pending = Completer();
      controller.syncMeeting('room1', true, [
        question('1'),
        question('2', text: 'Why three sides?'),
      ]);
      await settle();
      revision++;
      gateway.pending!.complete(supported);
      await settle();
      expect(sent, hasLength(2));
      expect(sent.every((m) => m.contains(TutorController.changedReply)), true);
      expect(gateway.calls, 1);
      expect(controller.reviews, isEmpty);
    },
  );
  test(
    'changing provider invalidates old work without sending or mixing rooms',
    () async {
      gateway.pending = Completer();
      controller.syncMeeting('room1', true, [question('1')]);
      await settle();
      controller.configure(
        const TutorConfig(baseUrl: 'https://other.test', model: 'other'),
      );
      gateway.pending!.complete(supported);
      await settle();
      expect(sent, isEmpty);
      expect(controller.enabled, false);
    },
  );
  test('room change pauses and baselines its history', () async {
    gateway.pending = Completer();
    controller.syncMeeting('room1', true, [question('1')]);
    await settle();
    controller.syncMeeting('room2', true, [question('other')]);
    gateway.pending!.complete(supported);
    await settle();
    controller.setEnabled(true);
    controller.syncMeeting('room2', true, [question('other')]);
    await settle();
    expect(sent, isEmpty);
    expect(controller.reviews, isEmpty);
  });
  test(
    'no sources can auto-send a tentative answer with explicit uncertainty',
    () async {
      sources = [];
      gateway.result = const TutorResult(
        answer: 'A triangle usually means a shape with three sides.',
        evidence: {},
        confidence: TutorConfidence.tentative,
      );
      controller.syncMeeting('room1', true, [question('1')]);
      await settle();
      expect(gateway.calls, 1);
      expect(controller.reviews, isEmpty);
      expect(sent.single, contains('Chưa chắc chắn — câu trả lời dự kiến.'));
      expect(sent.single, contains('Chưa có nguồn bài học xác nhận.'));
      expect(controller.sentCount, 1);
    },
  );

  test(
    'low-confidence inference auto-sends with verified citations without approval',
    () async {
      gateway.result = const TutorResult(
        answer: 'This may explain why the figure is a triangle.',
        evidence: {'p1': 'A triangle has three sides.'},
        confidence: TutorConfidence.tentative,
      );
      controller.syncMeeting('room1', true, [question('1')]);
      await settle();
      expect(sent.single, contains('Chưa chắc chắn'));
      expect(sent.single, contains('Nguồn: Trang 1'));
      expect(controller.reviews, isEmpty);
    },
  );

  test(
    'invalid answers send a fixed fallback without leaking rejected content',
    () async {
      for (final result in [
        const TutorResult(
          answer: 'Maybe.',
          evidence: {'fake': 'Invented source.'},
          confidence: TutorConfidence.tentative,
        ),
        const TutorResult(
          answer: '',
          evidence: {},
          confidence: TutorConfidence.tentative,
        ),
        const TutorResult(
          answer: 'Review text must not be sent.',
          evidence: {},
          confidence: TutorConfidence.unavailable,
        ),
      ]) {
        gateway.result = result;
        controller.syncMeeting('room1', true, [
          question('bad-${sent.length}', text: 'Why ${sent.length}?'),
        ]);
        await settle();
      }
      expect(sent, hasLength(3));
      expect(sent.every((m) => m.contains(TutorController.invalidReply)), true);
      expect(controller.reviews, isEmpty);
    },
  );

  test(
    're-enable processes a new question while an obsolete provider future remains unresolved',
    () async {
      final obsolete = Completer<TutorResult>();
      gateway.pending = obsolete;
      controller.syncMeeting('room1', true, [question('old')]);
      await settle();
      expect(gateway.calls, 1);
      controller.setEnabled(false);
      gateway.pending = null;
      controller.setEnabled(true);
      controller.syncMeeting('room1', true, [question('old'), question('new')]);
      await settle();
      expect(gateway.calls, 2);
      expect(sent, hasLength(1));
      expect(controller.busy, isFalse);
      obsolete.complete(supported);
      await settle();
      expect(sent, hasLength(1));
    },
  );
  test('pause also cancels in-flight low-confidence response', () async {
    gateway.pending = Completer();
    controller.syncMeeting('room1', true, [question('1')]);
    await settle();
    controller.setEnabled(false);
    gateway.pending!.complete(
      const TutorResult(
        answer: 'Possibly three sides.',
        evidence: {},
        confidence: TutorConfidence.tentative,
      ),
    );
    await settle();
    expect(sent, isEmpty);
  });
  test('fabricated quote and unsupported prose fail closed', () async {
    gateway.result = const TutorResult(
      answer: 'The answer is 100.',
      evidence: {'p1': 'A triangle has three sides.'},
    );
    controller.syncMeeting('room1', true, [question('1')]);
    await settle();
    expect(sent.single, contains(TutorController.invalidReply));
    expect(sent.single, isNot(contains('The answer is 100.')));
    expect(controller.reviews, isEmpty);
    expect(
      const TutorResult(
        answer: 'Fabricated quote.',
        evidence: {'p1': 'Fabricated quote.'},
      ).supportedBy([source]),
      false,
    );
  });
  test(
    'provider failure sends an apology while ambiguous delivery stays journal-only',
    () async {
      gateway.fail = true;
      controller.syncMeeting('room1', true, [question('1')]);
      await settle();
      expect(sent.single, contains(TutorController.apiFailureReply));
      expect(sent.single, isNot(contains('private')));
      expect(controller.reviews, isEmpty);
      gateway.fail = false;
      confirmed = false;
      controller.syncMeeting('room1', true, [
        question('1'),
        question('2', text: 'Why is it a triangle?'),
      ]);
      await settle();
      expect(controller.sentCount, 1);
      expect(controller.reviews, hasLength(1));
    },
  );
  test('single sequential bounded queue under burst', () async {
    gateway.pending = Completer();
    final burst = List.generate(
      25,
      (i) => question('$i', text: 'Question $i?'),
    );
    controller.syncMeeting('room1', true, burst);
    await settle();
    expect(gateway.calls, 1);
    expect(controller.queued, 20);
    expect(controller.reviews, isEmpty);
    final sentBeforePause = sent.length;
    controller.setEnabled(false);
    gateway.pending!.complete(supported);
    await settle();
    expect(sent, hasLength(sentBeforePause));
  });

  test(
    'baseline handshake gates enabling and excludes history arriving during preparation',
    () async {
      final baseline = Completer<bool>();
      final tutor = TutorController(
        gateway: gateway,
        context: (_) async =>
            TutorContext(revision: revision, currentPage: 1, sources: sources),
        contextRevision: () => revision,
        send: (text) async {
          sent.add(text);
          return true;
        },
        prepareObservation: () => baseline.future,
      );
      addTearDown(tutor.dispose);
      tutor.syncMeeting('room1', true, []);
      tutor.configure(config);
      tutor.setEnabled(true);
      expect(tutor.enabled, false);
      tutor.syncMeeting('room1', true, [question('history')]);
      baseline.complete(true);
      await settle();
      expect(tutor.enabled, true);
      tutor.syncMeeting('room1', true, [question('history')]);
      await settle();
      expect(gateway.calls, 0);
    },
  );

  test('pending enable cannot revive after pause', () async {
    final baseline = Completer<bool>();
    final tutor = TutorController(
      gateway: gateway,
      context: (_) async =>
          TutorContext(revision: revision, currentPage: 1, sources: sources),
      contextRevision: () => revision,
      send: (_) async => true,
      prepareObservation: () => baseline.future,
    );
    addTearDown(tutor.dispose);
    tutor.syncMeeting('room1', true, []);
    tutor.configure(config);
    tutor.setEnabled(true);
    tutor.setEnabled(false);
    baseline.complete(true);
    await settle();
    expect(tutor.enabled, false);
  });

  test(
    'guard is rechecked by delayed transport and cancelled on context change',
    () async {
      final release = Completer<void>();
      int cancelled = 0;
      final tutor = TutorController(
        gateway: gateway,
        context: (_) async =>
            TutorContext(revision: revision, currentPage: 1, sources: sources),
        contextRevision: () => revision,
        send: (_) async => throw StateError('unguarded path'),
        guardedSend: (text, valid) async {
          await release.future;
          if (!valid()) return false;
          sent.add(text);
          return true;
        },
        cancelSend: () => cancelled++,
      );
      addTearDown(tutor.dispose);
      tutor.syncMeeting('room1', true, []);
      tutor.configure(config);
      tutor.setEnabled(true);
      tutor.syncMeeting('room1', true, [question('1')]);
      await settle();
      revision++;
      tutor.contextChanged();
      release.complete();
      await settle();
      expect(sent, isEmpty);
      expect(cancelled, greaterThan(0));
    },
  );
}
