import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/smart_chalk_annotation.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/english_analyzer.dart';
import 'package:teaching_companion/features/studio_board/presentation/smart_chalk_overlay.dart';
import 'package:teaching_companion/features/studio_board/presentation/subject_tool_palette.dart';
import 'package:teaching_companion/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';

void main() {
  group('Hybrid S-V-O-A & OCR Architecture Tests', () {
    test(
      '1. Single word "I" only tags Subject (S) without fake Verb or Object',
      () {
        final sticker = EnglishSentenceAnalyzer.analyze(text: 'I');
        expect(sticker.tokens.length, equals(1));
        expect(sticker.tokens.first['text'], equals('I'));
        expect(sticker.tokens.first['role'], equals('subject'));
      },
    );

    test('2. Sentence with Adverb tags Adverbial (A) properly', () {
      final sticker = EnglishSentenceAnalyzer.analyze(
        text: 'She runs quickly in the park',
      );
      final roles = sticker.tokens
          .map((t) => t['role'])
          .whereType<String>()
          .toList();
      expect(roles, contains('subject'));
      expect(roles, contains('verb'));
      expect(roles, contains('adverb'));
      expect(roles, contains('object'));

      final token = ChalkWordToken(
        word: 'quickly',
        role: 'adverb',
        relativeRect: const Rect.fromLTWH(0.2, 0, 0.2, 1),
      );
      expect(token.color, equals(const Color(0xffa6e3a1)));
    });

    test(
      '3. Deduplication prevents stacked overlapping annotations on same area',
      () {
        final studio = StudioState();

        studio.addStroke(
          BoardStroke(Colors.white, 3.0, [
            const Offset(0.25, 0.35),
            const Offset(0.30, 0.35),
          ]),
        );

        // Teacher taps twice at the exact same location
        final tap1 = studio.analyzeHandwritingAt(const Offset(0.25, 0.35));
        expect(tap1, isTrue);
        expect(studio.currentChalkAnnotations.length, equals(1));

        final tap2 = studio.analyzeHandwritingAt(const Offset(0.25, 0.35));
        expect(tap2, isTrue);
        // Still only 1 annotation, NOT 2 overlapping!
        expect(studio.currentChalkAnnotations.length, equals(1));
      },
    );

    test(
      '4. Cách 2: addTypedChalkAnnotation adds clean S-V-O-A annotation on canvas',
      () {
        final studio = StudioState();
        studio.addTypedChalkAnnotation('She runs quickly');

        expect(studio.currentChalkAnnotations.length, equals(1));
        final annotation = studio.currentChalkAnnotations.first;
        expect(annotation.rawText, equals('She runs quickly'));

        final roles = annotation.tokens
            .map((t) => t.role)
            .whereType<String>()
            .toList();
        expect(roles, contains('subject'));
        expect(roles, contains('verb'));
        expect(roles, contains('adverb'));
      },
    );

    testWidgets('5. SmartChalkOverlay renders S, V, A badges cleanly', (
      tester,
    ) async {
      final studio = StudioState();
      studio.addTypedChalkAnnotation('She runs quickly');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(children: [SmartChalkOverlay(studio: studio)]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('S'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('6. SubjectToolPalette has "Nhập câu" button for Cách 2', (
      tester,
    ) async {
      final studio = StudioState();
      studio.openPlugin(
        InstalledPlugin(
          manifest: PluginManifest(
            id: 'com.hocluc.plugin.english',
            name: 'Trợ giảng Tiếng Anh',
            contributesTools: const [
              PluginToolContribution(
                id: 'quick_sentence',
                label: 'Nhập câu',
                icon: 'edit_note',
                action: 'quick_input',
                widgetKey: 'quick_sentence_button',
                tooltip: 'Nhập / Chọn câu bóc tách S-V-O-A',
              ),
            ],
          ),
        ),
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [SubjectToolPalette(studio: studio)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputBtn = find.byKey(const Key('quick_sentence_button'));
      expect(inputBtn, findsOneWidget);
      expect(find.text('Nhập câu'), findsOneWidget);

      await tester.tap(inputBtn);
      await tester.pumpAndSettle();

      // Dialog opens with presets and text field
      expect(find.text('Nhập / Chọn câu bóc tách S-V-O-A'), findsOneWidget);
      expect(find.text('Gạch chân lên bảng'), findsOneWidget);
    });
  });
}

