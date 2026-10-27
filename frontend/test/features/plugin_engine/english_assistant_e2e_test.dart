import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_storage_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_web_server.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempInstallDirectory;
  group('Phase 05: English Assistant End-to-End Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempInstallDirectory = await Directory.systemTemp.createTemp(
        'hocluc_english_e2e_',
      );
      PluginStorageManager.instance.setBaseDirectoryForTesting(
        tempInstallDirectory,
      );
      PluginManager.instance.resetForTesting();
    });
    tearDown(() async {
      await PluginWebServer.instance.stop();
      PluginManager.instance.resetForTesting();
      if (tempInstallDirectory.existsSync()) {
        await tempInstallDirectory.delete(recursive: true);
      }
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

        // Sample installation is subject-agnostic. Filesystem enumeration
        // order differs across platforms, so English is not guaranteed first.
        final installed = PluginManager.instance.installedPlugins;
        expect(installed, hasLength(1));
        final sample = PluginManager.instance.getPlugin(installed.single.id);
        expect(sample, isNotNull);
        expect(sample!.installDirectory, isNotNull);
        expect(
          File('${sample.installDirectory!.path}/manifest.json').existsSync(),
          isTrue,
        );
        expect(find.text(sample.manifest.name), findsOneWidget);
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
          contains('window.HocLuc.board.insertAnnotation'),
        );
        expect(
          installed.getFileString('engine/service.py'),
          contains('FastAPI'),
        );
      },
    );

    test(
      'glass preset events flow through the SDK and update the plugin UI',
      () async {
        final sdkFile = File('assets/scripts/hocluc-plugin-sdk.js');
        final appFile = File('../plugins/english_assistant/ui/app.js');
        expect(sdkFile.existsSync(), isTrue);
        expect(appFile.existsSync(), isTrue);

        final sdkResult = await Process.run('node', [
          '-e',
          '''
const HocLuc = require('./assets/scripts/hocluc-plugin-sdk.js');
let received;
HocLuc.onHostEvent('GLASS_PRESET_CHANGE', (payload) => { received = payload.preset; });
HocLuc.__dispatchHostEvent({ event: 'GLASS_PRESET_CHANGE', payload: { preset: 'solid' } });
if (received !== 'solid') process.exit(1);
''',
        ]);
        expect(
          sdkResult.exitCode,
          0,
          reason:
              'The SDK must deliver host glass events to onHostEvent subscribers.',
        );

        final appResult = await Process.run('node', [
          '-e',
          r'''
const fs = require('node:fs');
const vm = require('node:vm');
const rootStyle = new Map();
const root = {
  dataset: {},
  style: { setProperty: (name, value) => rootStyle.set(name, value) },
};
let tick = 0;
let glassHandler;
let registeredRegion;
const element = () => ({
  addEventListener(name, handler) { this.handlers = this.handlers || {}; this.handlers[name] = handler; },
  appendChild() {},
  style: {},
  value: '',
});
const elements = new Map();
for (const id of ['inputSentence', 'btnAnalyze', 'resultsCard', 'tokensContainer', 'grammarAlert', 'grammarMessage', 'btnPinToBoard', 'backendBadge']) elements.set(id, element());
global.performance = { timeOrigin: 1700000000000, now: () => ++tick };
global.window = {
  location: { search: '' },
  addEventListener() {},
  HocLuc: {
    onHostEvent: (name, handler) => { glassHandler = handler; },
    glass: {
      registerRegion: (id, target) => { registeredRegion = { id, target }; return () => {}; },
      updateRegion() {},
      unregisterRegion() {},
    },
  },
};
global.document = {
  documentElement: root,
  getElementById: (id) => elements.get(id) || element(),
  querySelectorAll: () => [],
  createElement: () => element(),
};
vm.runInThisContext(fs.readFileSync('../plugins/english_assistant/ui/app.js', 'utf8'));
if (root.dataset.glassPreset !== 'frosted') process.exit(1);
const expected = {
  clear: ['0.15', '10px'],
  frosted: ['0.28', '20px'],
  solid: ['0.85', '28px'],
};
for (let index = 0; index < 30; index++) {
  const preset = ['clear', 'frosted', 'solid'][index % 3];
  glassHandler({
    preset,
    dispatched_at_epoch_ms: 1700000000000 + tick + 1,
  });
  if (root.dataset.glassPreset !== preset) process.exit(2);
  if (rootStyle.get('--glass-bg-opacity') !== expected[preset][0]) process.exit(3);
  if (rootStyle.get('--glass-blur') !== expected[preset][1]) process.exit(4);
}
glassHandler({ preset: 'unknown', dispatched_at_epoch_ms: 1700000000000 });
if (root.dataset.glassPreset !== 'solid') process.exit(5);
const report = window.__glassPresetLatencyReport();
if (report.count !== 30 || report.medianMs >= 50 || report.p95Ms >= 50 || report.maxMs >= 50) process.exit(6);
const input = elements.get('inputSentence');
input.value = 'The student reads a book';
elements.get('btnAnalyze').handlers.click().then(() => {
  if (!registeredRegion || registeredRegion.id !== 'analysis-result-card') process.exitCode = 7;
  if (registeredRegion.target !== elements.get('resultsCard')) process.exitCode = 8;
});
''',
        ]);
        expect(
          appResult.exitCode,
          0,
          reason:
              'The app must validate preset events, update CSS variables, and measure 30 changes below 50 ms.',
        );

        final appJs = await appFile.readAsString();
        expect(appJs, contains('onHostEvent'));
        expect(appJs, contains('GLASS_PRESET_CHANGE'));
        expect(appJs, contains('--glass-bg-opacity'));
        expect(appJs, contains('--glass-blur'));
        for (final preset in ['clear', 'frosted', 'solid']) {
          expect(appJs, contains(preset));
        }
        expect(appJs, contains('registerRegion'));
        expect(appJs, contains('analysis-result-card'));
      },
    );
  });
}
