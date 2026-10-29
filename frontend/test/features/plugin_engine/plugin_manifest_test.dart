import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Phase 02: PluginManifest & PluginManager', () {
    test('PluginManifest parses manifest.json correctly', () {
      final jsonMap = {
        'id': 'com.hocluc.plugin.english',
        'name': 'Trợ giảng Tiếng Anh',
        'version': '1.0.0',
        'author': 'Học Lực Studio',
        'description': 'Phân tích ngữ pháp và từ vựng cho giáo viên',
        'category': 'language',
        'ui': {
          'entry': 'ui/index.html',
          'placement': 'drawer_panel',
          'default_width': 420,
        },
        'backend': {
          'has_sidecar': true,
          'executable': 'engine/service.exe',
          'development_entry': 'engine/dart/bin/service.dart',
          'port': 18888,
        },
      };

      final manifest = PluginManifest.fromJson(jsonMap);
      expect(manifest.id, 'com.hocluc.plugin.english');
      expect(manifest.name, 'Trợ giảng Tiếng Anh');
      expect(manifest.version, '1.0.0');
      expect(manifest.uiPlacement, 'drawer_panel');
      expect(manifest.uiDefaultWidth, 420);
      expect(manifest.uiEntry, 'ui/index.html');
      expect(manifest.hasSidecar, isTrue);
      expect(manifest.backendExecutable, 'engine/service.exe');
      expect(manifest.backendPort, 18888);
      expect(
        manifest.backend?.developmentEntry,
        'engine/dart/bin/service.dart',
      );

      final restored = manifest.toJson();
      expect(restored['id'], manifest.id);
      expect(restored['ui']['default_width'], 420);
      expect(
        restored['backend']['development_entry'],
        'engine/dart/bin/service.dart',
      );
    });

    test(
      'PluginManager installs, manages and uninstalls .hlep package from bytes',
      () async {
        final manager = PluginManager();
        expect(manager.installedPlugins, isEmpty);

        // Create a test zip archive in memory
        final archive = Archive();
        final manifestContent = utf8.encode(
          jsonEncode({
            'id': 'com.test.math',
            'name': 'Toán học vui',
            'version': '1.0.0',
            'ui': {
              'entry': 'ui/index.html',
              'placement': 'drawer_panel',
              'default_width': 400,
            },
          }),
        );
        archive.addFile(
          ArchiveFile('manifest.json', manifestContent.length, manifestContent),
        );

        final htmlContent = utf8.encode('<h1>Math Plugin</h1>');
        archive.addFile(
          ArchiveFile('ui/index.html', htmlContent.length, htmlContent),
        );

        final zipBytes = ZipEncoder().encode(archive);

        // Install
        final plugin = await manager.installPluginFromBytes(
          zipBytes,
          'math.hlep',
        );
        expect(plugin.manifest.id, 'com.test.math');
        expect(plugin.manifest.name, 'Toán học vui');
        expect(manager.installedPlugins.length, 1);
        expect(manager.getPlugin('com.test.math'), isNotNull);

        // Verify file extraction in memory
        final entryHtml = manager.getFileString(
          'com.test.math',
          'ui/index.html',
        );
        expect(entryHtml, '<h1>Math Plugin</h1>');

        // Uninstall
        manager.uninstallPlugin('com.test.math');
        expect(manager.installedPlugins, isEmpty);
        expect(manager.getPlugin('com.test.math'), isNull);
      },
    );

    test('PluginManager rejects zip packages without manifest.json', () async {
      final manager = PluginManager();
      final archive = Archive();
      final text = utf8.encode('some file');
      archive.addFile(ArchiveFile('readme.txt', text.length, text));
      final zipBytes = ZipEncoder().encode(archive);

      expect(
        () => manager.installPluginFromBytes(zipBytes, 'invalid.hlep'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'PluginManifest parses Schema v2.1 contributes.tools and inject_sdk',
      () {
        final jsonMap = {
          'id': 'com.hocluc.plugin.opensource_calc',
          'name': 'OpenSource Calc',
          'version': '2.1.0',
          'placement': 'floating_window',
          'default_width': 380,
          'default_height': 640,
          'resizable': true,
          'inject_sdk': true,
          'contributes': {
            'tools': [
              {
                'id': 'plot_graph',
                'label': 'Vẽ đồ thị',
                'icon': 'auto_awesome',
                'action': 'rpc_event',
                'target': 'plot',
              },
            ],
          },
        };

        final manifest = PluginManifest.fromJson(jsonMap);
        expect(manifest.id, 'com.hocluc.plugin.opensource_calc');
        expect(manifest.uiDefaultHeight, 640.0);
        expect(manifest.resizable, isTrue);
        expect(manifest.injectSdk, isTrue);
        expect(manifest.contributesTools.length, 1);
        expect(manifest.contributesTools.first.id, 'plot_graph');
        expect(manifest.contributesTools.first.label, 'Vẽ đồ thị');
      },
    );

    test('PluginManifest round-trips transparent WebView opt-in', () {
      final manifest = PluginManifest.fromJson({
        'id': 'com.test.glass',
        'name': 'Glass test',
        'ui': {'entry': 'ui/index.html', 'transparent_background': true},
      });

      expect(manifest.transparentBackground, isTrue);
      expect(manifest.toJson()['ui']['transparent_background'], isTrue);
    });
  });
}
