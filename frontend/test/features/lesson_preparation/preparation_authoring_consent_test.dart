import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_authoring_consent.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_capabilities_status.dart';

void main() {
  testWidgets(
    'API consent shows exact payload and requires each confirmation',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await PreparationAuthoringConsent.confirm(
                    context,
                    capabilities: {
                      'authoring': {
                        'baseUrl': 'https://provider.example/v1',
                        'model': 'lesson-model',
                      },
                    },
                    text: 'Exactly selected transcript',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Exactly selected transcript'), findsOneWidget);
      expect(find.text('API: https://provider.example/v1'), findsOneWidget);
      expect(find.text('Model: lesson-model'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(result, false);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Gửi nội dung để AI sinh giáo án?'), findsOneWidget);
      await tester.tap(find.text('Gửi và tạo bản nháp'));
      await tester.pumpAndSettle();
      expect(result, true);
    },
  );

  testWidgets('missing backend key is visible without local Ollama controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreparationCapabilitiesStatus(
              capabilities: {
                'authoring': {'ready': false, 'keyConfigured': false},
              },
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('HOCLUC_AUTHORING_API_KEY'), findsOneWidget);
    expect(find.textContaining('Ollama'), findsNothing);
  });
}
