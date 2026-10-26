import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/theme/app_theme.dart';
import 'package:teaching_companion/features/meet_tutor/domain/models/tutor_models.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_controller.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_gateway.dart';
import 'package:teaching_companion/features/meet_tutor/presentation/widgets/tutor_settings.dart';

class FakeGateway implements TutorGateway {
  final tested = <TutorConfig>[];
  Completer<void>? pending;
  Object? error;
  @override
  Future<void> test(TutorConfig config) async {
    tested.add(config);
    if (pending != null) {
      await pending!.future;
    }
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<TutorResult> answer(
    TutorConfig config,
    String question,
    TutorContext context,
  ) async => const TutorResult(answer: '', evidence: {});
}

class FakeController extends TutorController {
  FakeController(FakeGateway gateway)
    : super(
        gateway: gateway,
        context: (_) async =>
            const TutorContext(revision: 0, currentPage: 1, sources: []),
        contextRevision: () => 0,
        send: (_) async => false,
      );
  final applied = <TutorConfig>[];
  final pendingReviews = <TutorReview>[];
  @override
  List<TutorReview> get reviews => List.unmodifiable(pendingReviews);
  @override
  int get queued => 2;
  @override
  void configure(TutorConfig value) {
    applied.add(value);
    super.configure(value);
  }

  @override
  void dismissReview(TutorReview review) {
    pendingReviews.remove(review);
    notifyListeners();
  }
}

void main() {
  late FakeGateway gateway;
  late FakeController controller;
  setUp(() {
    gateway = FakeGateway();
    controller = FakeController(gateway);
  });
  tearDown(() => controller.dispose());

  Future<void> mount(
    WidgetTester tester, {
    double width = 320,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
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
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'https://custom.example/v1',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'custom-model');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret-test-key');
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  bool canApply(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed != null;

  testWidgets(
    'explicit test then apply uses the identical immutable draft and stays paused',
    (tester) async {
      await mount(tester);
      expect(gateway.tested, isEmpty);
      expect(canApply(tester), isFalse);
      await fill(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      await tap(tester, 'Kiểm tra kết nối');
      expect(controller.applied, isEmpty);
      expect(canApply(tester), isTrue);
      await tap(tester, 'Áp dụng');
      expect(
        identical(controller.applied.single, gateway.tested.single),
        isTrue,
      );
      expect(controller.config!.apiKey, 'secret-test-key');
      expect(controller.enabled, isFalse);
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(controller.enabled, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(controller.enabled, isFalse);
    },
  );

  testWidgets('editing clears successful test and pauses active controller', (
    tester,
  ) async {
    controller.configure(
      const TutorConfig(baseUrl: 'https://old.example/v1', model: 'old'),
    );
    controller.setEnabled(true);
    await mount(tester);
    await fill(tester);
    expect(controller.enabled, isFalse);
    await tap(tester, 'Kiểm tra kết nối');
    expect(canApply(tester), isTrue);
    await tester.enterText(find.byType(TextFormField).at(1), 'changed');
    await tester.pump();
    expect(canApply(tester), isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('stale in-flight success cannot authorize changed draft', (
    tester,
  ) async {
    gateway.pending = Completer<void>();
    await mount(tester);
    await fill(tester);
    await tap(tester, 'Kiểm tra kết nối');
    await tester.enterText(find.byType(TextFormField).at(2), 'replacement-key');
    gateway.pending!.complete();
    await tester.pump();
    expect(canApply(tester), isFalse);
    expect(controller.applied, isEmpty);
  });

  testWidgets(
    'validation prevents calls and provider errors never expose secrets',
    (tester) async {
      await mount(tester);
      await tap(tester, 'Kiểm tra kết nối');
      expect(gateway.tested, isEmpty);
      await fill(tester);
      gateway.error = StateError(
        'Authorization: secret-test-key provider-private-body',
      );
      await tap(tester, 'Kiểm tra kết nối');
      expect(find.textContaining('Không kết nối được.'), findsOneWidget);
      expect(find.textContaining('provider-private-body'), findsNothing);
      expect(canApply(tester), isFalse);
    },
  );

  testWidgets(
    'narrow scaled inspector shows status, counters and dismissible reviews',
    (tester) async {
      controller.busy = true;
      controller.sentCount = 3;
      controller.pendingReviews.add(
        const TutorReview('Học sinh', 'Tại sao cần nguồn?', 'Chưa đủ căn cứ.'),
      );
      await mount(tester, width: 240, scale: 1.5);
      expect(
        find.text(
          'Tự gửi cả câu trả lời dự kiến với nhãn “Chưa chắc chắn”, không cần duyệt. Chưa đọc nét viết tay/PDF quét hoặc nghe lời giảng.',
        ),
        findsOneWidget,
      );
      expect(find.text('Đang xử lý'), findsOneWidget);
      expect(find.text('Đang chờ: 2'), findsOneWidget);
      expect(find.text('Đã gửi: 3'), findsOneWidget);
      expect(find.text('Tại sao cần nguồn?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Bỏ qua');
      expect(controller.reviews, isEmpty);
      expect(
        find.textContaining('Không có câu trả lời chờ duyệt'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switch exposes an accessible name in a narrow inspector', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, width: 240, scale: 1.5);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    expect(
      find.bySemanticsLabel('Tự động trả lời câu hỏi Meet'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('disposing during test is safe and a new session has no key', (
    tester,
  ) async {
    gateway.pending = Completer<void>();
    await mount(tester);
    await fill(tester);
    await tap(tester, 'Kiểm tra kết nối');
    await tester.pumpWidget(const SizedBox());
    gateway.pending!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await mount(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      isEmpty,
    );
    expect(
      find.textContaining('Khởi động lại ứng dụng cần nhập lại'),
      findsOneWidget,
    );
  });
}
