import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/lesson_preparation/domain/models/preparation_document.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_variant_sheet.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';

class VariantApi extends PreparationApi {
  Map? sent;
  bool stale = false;
  @override
  Future<dynamic> get(String path) async {
    if (path == 'variant-classes') {
      return {
        'classes': [
          {'id': 'local-a', 'name': 'Class A'},
        ],
      };
    }
    if (path == 'courses') {
      return {
        'courses': [
          {'id': 'google-b', 'name': 'Class B'},
        ],
      };
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    sent = body as Map;
    if (stale) throw PreparationFailure('Bài đã thay đổi', 409);
    return {'planningId': 'new-variant'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> open(
    WidgetTester tester,
    VariantApi api,
    ValueChanged<String> onCreated,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: PreparationVariantSheet(
                    api: api,
                    planningId: 'original',
                    document: PreparationDocument({
                      'title': 'Source',
                      'revision': 7,
                    }),
                    onCreated: onCreated,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'creates selected class snapshot with source revision and private adaptation',
    (tester) async {
      final api = VariantApi();
      String? opened;
      await open(tester, api, (id) => opened = id);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class A · Lớp trong app').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Simpler examples');
      await tester.scrollUntilVisible(
        find.text('Tạo và mở biến thể'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Tạo và mở biến thể'));
      await tester.pumpAndSettle();
      expect(opened, 'new-variant');
      expect(api.sent, containsPair('classId', 'local-a'));
      expect(api.sent, containsPair('classKind', 'local'));
      expect(api.sent, containsPair('expectedRevision', 7));
      expect(api.sent, containsPair('adaptationNotes', 'Simpler examples'));
    },
  );
  testWidgets(
    'Google class selection retains kind and stale error keeps dialog',
    (tester) async {
      final api = VariantApi()..stale = true;
      await open(tester, api, (_) => fail('must not navigate on conflict'));
      await tester.tap(find.text('Tải lớp Google Classroom'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class B · Google Classroom').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tạo và mở biến thể'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Tạo và mở biến thể'));
      await tester.pumpAndSettle();
      expect(api.sent, containsPair('classKind', 'google'));
      expect(find.text('Bài đã thay đổi'), findsOneWidget);
      expect(find.byType(PreparationVariantSheet), findsOneWidget);
    },
  );
}
