import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/domain/models/preparation_document.dart';
import 'package:teaching_companion/features/lesson_preparation/domain/models/preparation_section_tools.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_support_panel.dart';

void main() {
  test(
    'student projection includes activities and reviewed hints without private teaching text',
    () {
      final section = <String, dynamic>{
        'id': 's',
        'title': 'A',
        'minutes': 5,
        'teacherNotes': 'PRIVATE_NOTE',
        'activities': [
          {
            'id': 'a',
            'title': 'Discuss',
            'minutes': 8,
            'teacherAction': 'PRIVATE_ACTION',
            'studentAction': 'PUBLIC_TASK',
          },
        ],
        'supportCards': [
          {
            'id': 'h',
            'kind': 'hint',
            'teacherText': 'PRIVATE_ANSWER',
            'publicText': 'PUBLIC_HINT',
            'publicReviewed': true,
            'publicReviewedText': 'PUBLIC_HINT',
          },
          {
            'id': 'e',
            'kind': 'example',
            'teacherText': 'PRIVATE_EXAMPLE',
            'publicText': 'UNREVIEWED_TEXT',
            'publicReviewed': false,
          },
        ],
      };
      final doc = PreparationDocument({
        'title': 'A',
        'sections': [section],
      });
      final output = doc.studentProjection().toString();
      expect(output, contains('PUBLIC_TASK'));
      expect(output, contains('PUBLIC_HINT'));
      expect(output, isNot(contains('PRIVATE_')));
      expect(output, isNot(contains('UNREVIEWED_TEXT')));
      expect(sectionChecks(section).join(' '), contains('vượt 5 phút'));
      expect(
        sectionChecks(section).join(' '),
        contains('chưa liên kết mục tiêu'),
      );
      final copied = doc.copy();
      expect(
        copied.rows('sections').single['activities'],
        section['activities'],
      );
    },
  );
  testWidgets(
    'editing approved public hint resets approval and keeps teacher answer private',
    (tester) async {
      List<PreparationMap>? saved;
      final section = <String, dynamic>{
        'supportCards': [
          {
            'id': 'h',
            'kind': 'hint',
            'teacherText': 'PRIVATE_ANSWER',
            'publicText': 'Old public hint',
            'publicReviewed': true,
            'publicReviewedText': 'Old public hint',
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreparationSupportPanel(
                section: section,
                onChanged: (rows) => saved = rows,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Thẻ hỗ trợ (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gợi ý từng bước'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nội dung cho học sinh (tùy chọn)'),
        'New unapproved hint',
      );
      await tester.pump();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await tester.tap(find.text('Lưu thẻ'));
      await tester.pumpAndSettle();
      expect(saved!.single['teacherText'], 'PRIVATE_ANSWER');
      expect(saved!.single['publicReviewed'], isFalse);
      expect(saved!.single.containsKey('publicReviewedText'), isFalse);
      expect(
        studentSectionProjection({'supportCards': saved})['supportCards'],
        isEmpty,
      );
    },
  );
}
