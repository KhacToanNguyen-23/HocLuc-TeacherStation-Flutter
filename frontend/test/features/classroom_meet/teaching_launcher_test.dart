import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';

class SessionLocal extends LocalService {
  Map<String, dynamic> active = {};
  int ends = 0;
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> getActiveClassroom({bool strict = false}) async {
    await gate?.future;
    return Map.of(active);
  }

  @override
  Future<bool> endClassroom({
    String? classroomId,
    Map<String, dynamic>? content,
  }) async {
    ends++;
    active = {};
    return true;
  }
}

class TestStudio extends StatefulWidget {
  const TestStudio({
    super.key,
    required this.target,
    required this.home,
    required this.created,
  });
  final TeachingTarget target;
  final Widget Function() home;
  final VoidCallback created;
  @override
  State<TestStudio> createState() => _TestStudioState();
}

class _TestStudioState extends State<TestStudio> {
  int marks = 0;
  @override
  void initState() {
    super.initState();
    widget.created();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('Studio ${widget.target.title}'),
        Text('Nét vẽ $marks'),
        TextButton(
          onPressed: () => setState(() => marks++),
          child: const Text('Vẽ'),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => widget.home())),
          child: const Text('Danh sách lớp'),
        ),
      ],
    ),
  );
}

void main() {
  const a = TeachingTarget(
    title: 'Toán',
    courseId: 'a',
    meetingUrl: 'https://meet.google.com/abc-defg-hij',
  );
  const b = TeachingTarget(
    title: 'Lý',
    courseId: 'b',
    meetingUrl: 'https://meet.google.com/klm-nopq-rst',
  );
  setUp(() {
    MeetAutomationService().setMeetingUrl('');
  });

  test('account change refuses ongoing session without ending it', () async {
    final local = SessionLocal()
      ..active = {'id': 'old-session', 'status': 'ONGOING'};
    addTearDown(local.dispose);
    await expectLater(
      TeachingLauncher.requireIdleForAccountChange(localService: local),
      throwsStateError,
    );
    expect(local.ends, 0);
    expect(local.active['id'], 'old-session');
    local.active = {};
    await TeachingLauncher.requireIdleForAccountChange(localService: local);
  });

  testWidgets('same class returns to existing Studio and keeps board', (
    tester,
  ) async {
    final local = SessionLocal();
    addTearDown(local.dispose);
    var created = 0;
    late Widget Function() home;
    home = () => Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => TeachingLauncher.open(
            context,
            a,
            localService: local,
            studioBuilder: (target, _) => TestStudio(
              target: target,
              home: home,
              created: () {
                created++;
                local.active = {
                  'status': 'ONGOING',
                  'id': 'session-a',
                  'meetingUrl': a.meetingUrl,
                };
              },
            ),
          ),
          child: const Text('Mở Toán'),
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: home()));
    await tester.tap(find.text('Mở Toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vẽ'));
    await tester.pump();
    await tester.tap(find.text('Danh sách lớp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở Toán'));
    await tester.pumpAndSettle();
    expect(find.text('Nét vẽ 1'), findsOneWidget);
    expect(created, 1);
    expect(local.ends, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('switching class requires confirmation and removes old Studio', (
    tester,
  ) async {
    final local = SessionLocal();
    addTearDown(local.dispose);
    var left = 0;
    late Widget Function() home;
    Future<void> open(BuildContext context, TeachingTarget target) =>
        TeachingLauncher.open(
          context,
          target,
          localService: local,
          leaveMeeting: () async {
            left++;
          },
          studioBuilder: (target, _) => TestStudio(
            target: target,
            home: home,
            created: () {
              local.active = {
                'status': 'ONGOING',
                'id': target.courseId,
                'meetingUrl': target.meetingUrl,
              };
            },
          ),
        );
    home = () => Builder(
      builder: (context) => Scaffold(
        body: Row(
          children: [
            TextButton(
              onPressed: () => open(context, a),
              child: const Text('Mở Toán'),
            ),
            TextButton(
              onPressed: () => open(context, b),
              child: const Text('Mở Lý'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: home()));
    await tester.tap(find.text('Mở Toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Danh sách lớp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở Lý'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ở lại'));
    await tester.pumpAndSettle();
    expect(left, 0);
    expect(local.ends, 0);
    await tester.tap(find.text('Mở Lý'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kết thúc và chuyển lớp'));
    await tester.pumpAndSettle();
    expect(left, 1);
    expect(local.ends, 1);
    expect(find.text('Studio Lý'), findsOneWidget);
    expect(find.text('Studio Toán', skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('double click while preparing opens only one Studio', (
    tester,
  ) async {
    final local = SessionLocal()..gate = Completer<void>();
    addTearDown(local.dispose);
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                for (var i = 0; i < 2; i++) {
                  unawaited(
                    TeachingLauncher.open(
                      context,
                      a,
                      localService: local,
                      studioBuilder: (_, _) {
                        created++;
                        return const Scaffold(body: Text('Studio duy nhất'));
                      },
                    ),
                  );
                }
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    local.gate!.complete();
    await tester.pumpAndSettle();
    expect(created, 1);
    expect(local.ends, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

