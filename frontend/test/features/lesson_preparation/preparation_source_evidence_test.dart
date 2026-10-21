import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_source_evidence.dart';

void main() {
  testWidgets('one pending probe cannot double submit citation', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    int probes = 0, changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationSourceEvidence(
            item: const {},
            sources: const [
              {
                'id': 'video',
                'name': 'Lesson.mp4',
                'revision': 0,
                'mimeType': 'video/mp4',
              },
            ],
            onChanged: (_) => changes++,
            onPreview: (_, _) {},
            onProbe: (_) {
              probes++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Gắn nguồn đã kiểm chứng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gắn nguồn'));
    await tester.pump();
    await tester.tap(find.text('Gắn nguồn'));
    expect(probes, 1);
    pending.complete({'durationSeconds': 30});
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    expect(changes, 1);
    expect(find.text('Liên kết đoạn nguồn'), findsNothing);
  });
  testWidgets('shows uncited AI status and seeks owned source at exact time', (
    tester,
  ) async {
    double? seek;
    final item = <String, dynamic>{'aiAdded': true};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationSourceEvidence(
            item: item,
            sources: const [
              {
                'id': 'video',
                'name': 'Lesson.mp4',
                'revision': 3,
                'mimeType': 'video/mp4',
              },
            ],
            onChanged: (_) {},
            onPreview: (_, seconds) => seek = seconds,
          ),
        ),
      ),
    );
    expect(find.text('AI đề xuất — cần giáo viên kiểm chứng'), findsOneWidget);
    expect(find.text('Chưa có nguồn tham chiếu.'), findsOneWidget);
    item['sourceRefs'] = [
      {'sourceAssetId': 'video', 'sourceRevision': 3, 'start': 42.5, 'end': 50},
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationSourceEvidence(
            item: item,
            sources: const [
              {
                'id': 'video',
                'name': 'Lesson.mp4',
                'revision': 3,
                'mimeType': 'video/mp4',
              },
            ],
            onChanged: (_) {},
            onPreview: (_, seconds) => seek = seconds,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lesson.mp4'));
    expect(seek, 42.5);
    expect(find.text('Phiên bản 3 · 42.5–50 giây'), findsOneWidget);
  });

  testWidgets('removes citation without touching public content', (
    tester,
  ) async {
    List<Map<String, dynamic>>? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationSourceEvidence(
            item: {
              'body': 'Public text',
              'sourceRefs': [
                {'sourceAssetId': 'image', 'sourceRevision': 0},
              ],
            },
            sources: const [
              {'id': 'image', 'name': 'Image.png', 'revision': 0},
            ],
            onChanged: (refs) => changed = refs,
            onPreview: (_, _) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Gỡ tham chiếu'));
    expect(changed, isEmpty);
  });
}
