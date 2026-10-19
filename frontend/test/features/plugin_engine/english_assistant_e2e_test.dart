import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/presentation/board_sticker_card.dart';
import 'package:teaching_companion/features/studio_board/presentation/subject_tool_palette.dart';
import 'package:teaching_companion/features/studio_board/presentation/stage_container.dart';

List<int> createEnglishAssistantZip() {
  final archive = Archive();
  final manifestJson = jsonEncode({
    'id': 'com.hocluc.plugin.english',
    'name': 'Trợ giảng Tiếng Anh',
    'version': '1.0.0',
    'author': 'Học Lực Studio',
    'description': 'Bóc tách S-V-O và bắt lỗi thì/ngữ pháp',
    'main': 'ui/index.html',
    'icon': 'icon.png',
    'placement': 'drawer_panel',
    'default_width': 420,
    'backend': {
      'type': 'python',
      'entry': 'engine/service.py',
      'port': 18888,
      'health_endpoint': '/health',
    },
    'permissions': ['board:insert_annotation'],
  });

  const htmlContent = '<html><body><h3>English Assistant</h3></body></html>';

  archive.addFile(
    ArchiveFile(
      'manifest.json',
      manifestJson.length,
      utf8.encode(manifestJson),
    ),
  );
  archive.addFile(
    ArchiveFile('ui/index.html', htmlContent.length, utf8.encode(htmlContent)),
  );
  archive.addFile(ArchiveFile('icon.png', 4, [0x89, 0x50, 0x4E, 0x47]));

  return ZipEncoder().encode(archive);
}

void main() {
  group('Phase 05: English Assistant End-to-End Tests', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });
    test(
      '1. Install english_assistant.hlep and verify manifest & files',
      () async {
        final zipBytes = createEnglishAssistantZip();
        final installed = await PluginManager.instance.installPluginFromBytes(
          zipBytes,
          'english_assistant.hlep',
        );

        expect(installed.manifest.id, 'com.hocluc.plugin.english');
        expect(installed.manifest.name, 'Trợ giảng Tiếng Anh');
        expect(installed.manifest.defaultWidth, 420);
        expect(installed.manifest.backend?.port, 18888);
        expect(
          installed.getFileString('ui/index.html'),
          contains('English Assistant'),
        );
        expect(
          PluginManager.instance.getPlugin('com.hocluc.plugin.english'),
          isNotNull,
        );
      },
    );

    testWidgets(
      '2. Full Studio flow: Open plugin, bridge message, sticker on canvas, save/load',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final studio = StudioState();
        final zipBytes = createEnglishAssistantZip();
        await PluginManager.instance.installPluginFromBytes(
          zipBytes,
          'english_assistant.hlep',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StageContainer(studio: studio)),
          ),
        );
        await tester.pumpAndSettle();

        // Open left questions/materials drawer
        studio.setQuestionsDrawer(true);
        await tester.pumpAndSettle();

        // Verify "Trợ giảng Tiếng Anh" appears in the drawer list
        expect(find.text('Trợ giảng Tiếng Anh'), findsOneWidget);

        // Tap on the plugin item to open it
        await tester.tap(find.text('Trợ giảng Tiếng Anh'));
        await tester.pumpAndSettle();

        expect(studio.showPluginDrawer, isFalse);
        expect(studio.activePlugin?.manifest.id, 'com.hocluc.plugin.english');
        expect(find.byType(SubjectToolPalette), findsOneWidget);

        // Simulate bridge event INSERT_ANNOTATION coming from WebView/Iframe
        studio.handlePluginMessage({
          'type': 'INSERT_ANNOTATION',
          'pluginId': 'com.hocluc.plugin.english',
          'text': 'The smart student reads a book eagerly in the classroom.',
          'tokens': [
            {'text': 'The', 'role': null},
            {'text': 'smart', 'role': null},
            {'text': 'student', 'role': 'subject'},
            {'text': 'reads', 'role': 'verb'},
            {'text': 'a', 'role': null},
            {'text': 'book', 'role': 'object'},
          ],
          'grammarIssue': 'Sentence is grammatically sound.',
        });
        await tester.pumpAndSettle();

        // Verify sticker appears in studio state and UI
        expect(studio.currentStickers.length, 1);
        final sticker = studio.currentStickers.first;
        expect(
          sticker.text,
          'The smart student reads a book eagerly in the classroom.',
        );
        expect(sticker.tokens.length, 6);
        expect(sticker.grammarIssue, 'Sentence is grammatically sound.');

        // Check BoardStickerCard is rendered on the interactive chalkboard
        expect(find.byType(BoardStickerCard), findsOneWidget);
        expect(find.text('student'), findsOneWidget);
        expect(find.text('reads'), findsOneWidget);
        expect(find.text('book'), findsOneWidget);

        // Test drag / position update
        studio.updateStickerRect(
          sticker.id,
          const Rect.fromLTWH(0.25, 0.35, 0.5, 0.2),
        );
        await tester.pumpAndSettle();
        expect(studio.currentStickers.first.normalizedRect.left, 0.25);
        expect(studio.currentStickers.first.normalizedRect.top, 0.35);

        // Test lesson save and restore persistence (.hls JSON)
        final savedData = studio.exportLessonJson();
        final newStudio = StudioState();
        newStudio.restoreFromJson(savedData);

        expect(newStudio.currentStickers.length, 1);
        final restoredSticker = newStudio.currentStickers.first;
        expect(restoredSticker.id, sticker.id);
        expect(restoredSticker.text, sticker.text);
        expect(restoredSticker.normalizedRect.left, 0.25);
        expect(restoredSticker.normalizedRect.top, 0.35);

        // Test delete sticker in UI
        final cardCloseBtn = find.descendant(
          of: find.byType(BoardStickerCard),
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(cardCloseBtn);
        await tester.pumpAndSettle();
        expect(studio.currentStickers.isEmpty, isTrue);
      },
    );

    testWidgets(
      '3. DrawerQuestions has "Cài thêm tiện ích môn" quick install option',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final studio = StudioState();
        PluginManager.instance.uninstallPlugin('com.hocluc.plugin.english');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StageContainer(studio: studio)),
          ),
        );
        await tester.pumpAndSettle();

        studio.setQuestionsDrawer(true);
        await tester.pumpAndSettle();

        // Find "Cài thêm tiện ích môn" button
        final installButton = find.text('Cài thêm tiện ích môn');
        expect(installButton, findsOneWidget);

        // Tapping it opens dialog / options
        await tester.tap(installButton);
        await tester.pumpAndSettle();

        // Dialog shows option to install sample plugin
        expect(find.textContaining('Cài đặt Plugin Mẫu'), findsOneWidget);

        // Tap on sample install option
        await tester.tap(find.textContaining('Cài đặt Plugin Mẫu'));
        await tester.pumpAndSettle();

        // Plugin should now be installed
        expect(
          PluginManager.instance.getPlugin('com.hocluc.plugin.english'),
          isNotNull,
        );
        expect(find.text('Trợ giảng Tiếng Anh'), findsOneWidget);
      },
    );

    test(
      '4. Verify real packaged file plugins/english_assistant.hlep',
      () async {
        final file = File('../plugins/english_assistant.hlep');
        expect(file.existsSync(), isTrue);
        final bytes = await file.readAsBytes();
        final installed = await PluginManager.instance.installPluginFromBytes(
          bytes,
          'english_assistant.hlep',
        );
        expect(installed.manifest.id, 'com.hocluc.plugin.english');
        expect(installed.manifest.name, 'Trợ giảng Tiếng Anh');
        expect(
          installed.getFileString('ui/index.html'),
          contains('Trợ Giảng Tiếng Anh'),
        );
        expect(
          installed.getFileString('ui/app.js'),
          contains('INSERT_ANNOTATION'),
        );
        expect(
          installed.getFileString('engine/service.py'),
          contains('FastAPI'),
        );
      },
    );
  });
}

