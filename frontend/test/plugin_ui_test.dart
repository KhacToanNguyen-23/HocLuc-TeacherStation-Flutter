import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/plugin_manifest.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/plugin_manager.dart';
import 'package:teaching_companion/widgets/floating_plugin_window.dart';
import 'package:teaching_companion/widgets/plugin_host_drawer.dart';

void main() {
  group('Phase 03: Hybrid Plugin Host UI', () {
    late StudioState studio;
    late InstalledPlugin dummyPlugin;

    setUp(() {
      studio = StudioState()..loading = false;
      final manifest = PluginManifest(
        id: 'com.test.english',
        name: 'Trợ giảng Tiếng Anh',
        uiPlacement: 'drawer_panel',
        uiDefaultWidth: 420,
      );
      dummyPlugin = InstalledPlugin(
        manifest: manifest,
        files: {'ui/index.html': utf8.encode('<h1>English Plugin UI</h1>')},
      );
    });

    tearDown(() => studio.dispose());

    test('StudioState manages plugin lifecycle and bridge messages', () {
      expect(studio.activePlugin, isNull);
      expect(studio.showPluginDrawer, isFalse);
      expect(studio.pluginFloating, isFalse);

      // Open plugin
      studio.openPlugin(dummyPlugin, openModal: true);
      expect(studio.activePlugin?.manifest.id, 'com.test.english');
      expect(studio.showPluginDrawer, isTrue);
      expect(studio.pluginFloating, isFalse);

      // Pop out to floating window
      studio.togglePluginFloating();
      expect(studio.pluginFloating, isTrue);

      // Dock back to drawer
      studio.togglePluginFloating();
      expect(studio.pluginFloating, isFalse);

      // Handle bridge INSERT_ANNOTATION message
      expect(studio.currentStickers, isEmpty);
      studio.handlePluginMessage({
        'action': 'INSERT_ANNOTATION',
        'payload': {
          'raw_text': 'I love coding',
          'tokens': [
            {'text': 'I', 'role': 'SUBJECT'},
            {'text': 'love', 'role': 'VERB'},
            {'text': 'coding', 'role': 'OBJECT'},
          ],
          'issues': ['⚠️ Great sentence!'],
        },
      });

      expect(studio.currentStickers.length, 1);
      final sticker = studio.currentStickers.first;
      expect(sticker.rawText, 'I love coding');
      expect(sticker.tokens.length, 3);
      expect(sticker.issues.first, '⚠️ Great sentence!');

      // Close plugin
      studio.closePlugin();
      expect(studio.activePlugin, isNull);
      expect(studio.showPluginDrawer, isFalse);
    });

    testWidgets(
      'PluginHostDrawer renders header, pop-out button, and close button',
      (tester) async {
        studio.openPlugin(dummyPlugin, openModal: true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [PluginHostDrawer(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trợ giảng Tiếng Anh'), findsOneWidget);
        expect(find.byIcon(Icons.open_in_new), findsOneWidget); // Pop-out icon
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Tap pop-out button
        await tester.tap(find.byIcon(Icons.open_in_new));
        await tester.pump();
        expect(studio.pluginFloating, isTrue);
      },
    );

    testWidgets('FloatingPluginWindow renders and docks back to drawer', (
      tester,
    ) async {
      studio.openPlugin(dummyPlugin);
      studio.togglePluginFloating();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingPluginWindow(studio: studio)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trợ giảng Tiếng Anh'), findsOneWidget);
      expect(find.byIcon(Icons.vertical_split), findsOneWidget); // Dock icon

      // Tap dock icon
      await tester.tap(find.byIcon(Icons.vertical_split));
      await tester.pump();
      expect(studio.pluginFloating, isFalse);
    });
  });
}
