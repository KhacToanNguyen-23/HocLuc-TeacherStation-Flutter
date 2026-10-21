import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_question_picker.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_controller.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';

class _Api extends PreparationApi {
  @override
  Future<dynamic> get(String path) async => {
    'items': [
      {
        'id': 'q1',
        'title': 'Reviewed group',
        'groupId': 'g1',
        'groupContent': 'Shared passage',
        'groupAssets': [],
        'questionCount': 2,
        'questions': [
          {
            'stem': 'Question one',
            'choices': [],
            'answer': 'PRIVATE_ANSWER',
            'solution': 'Teacher explanation',
            'assets': [],
          },
          {
            'stem': 'Question two',
            'choices': [],
            'answer': 'Second answer',
            'solution': '',
            'assets': [],
          },
        ],
      },
    ],
  };
}

void main() {
  testWidgets(
    'picker previews full context and keeps answers explicitly private',
    (tester) async {
      final api = _Api();
      final c = PreparationController(
        planId: 'p1',
        api: api,
        title: 'Lesson',
        subject: 'General',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreparationQuestionPicker(controller: c)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reviewed group'), findsOneWidget);
      await tester.tap(find.text('Reviewed group'));
      await tester.pumpAndSettle();
      expect(find.text('Shared passage'), findsOneWidget);
      expect(find.text('Question two'), findsOneWidget);
      expect(
        find.textContaining('Riêng giáo viên — Đáp án: PRIVATE_ANSWER'),
        findsOneWidget,
      );
      expect(find.text('Chèn 2 câu'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      api.dispose();
    },
  );
}
