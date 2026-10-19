import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_marketplace_service.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_storage_manager.dart';

List<int> _createTestHlepBytes(Map<String, dynamic> manifestJson) {
  final archive = Archive();
  final manifestBytes = utf8.encode(jsonEncode(manifestJson));
  archive.addFile(
    ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
  );
  final htmlBytes = utf8.encode(
    '<!DOCTYPE html><html><head><title>Plugin</title></head><body><h1>OK</h1></body></html>',
  );
  archive.addFile(ArchiveFile('ui/index.html', htmlBytes.length, htmlBytes));
  return ZipEncoder().encode(archive);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('hocluc_marketplace_test_');
    PluginStorageManager.instance.setBaseDirectoryForTesting(tempDir);
    PluginManager.instance.resetForTesting();
  });

  tearDown(() async {
    PluginManager.instance.resetForTesting();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Plugin Marketplace Sync, Download & Multi-Instance Host Tests', () {
    test(
      'syncMarketplaceCatalog fetches remote plugins and install() downloads .hlep on demand',
      () async {
        final calcManifest = {
          'id': 'org.open.scientific_calc',
          'name': 'Máy tính Khoa học',
          'version': '1.2.0',
          'description': 'Máy tính nổi mã nguồn mở',
          'category': 'math',
          'ui': {
            'entry': 'ui/index.html',
            'placement': 'floating_window',
            'default_width': 350,
            'default_height': 620,
            'resizable': false,
            'inject_sdk': true,
          },
        };
        final zipBytes = _createTestHlepBytes(calcManifest);

        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/marketplace/plugins') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode([
                  {
                    'id': 'org.open.scientific_calc',
                    'name': 'Máy tính Khoa học',
                    'version': '1.2.0',
                    'description': 'Máy tính nổi mã nguồn mở',
                    'author': 'Open Source',
                    'category': 'math',
                    'uiPlacement': 'floating_window',
                    'uiDefaultWidth': 350,
                    'uiDefaultHeight': 620,
                    'resizable': false,
                    'injectSdk': true,
                    'iconUrl':
                        '/api/marketplace/plugins/org.open.scientific_calc/icon',
                    'downloadUrl':
                        '/api/marketplace/plugins/org.open.scientific_calc/download',
                    'sizeBytes': zipBytes.length,
                    'sha256': 'abc1234',
                    'contributesTools': [],
                  },
                ]),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path ==
              '/api/marketplace/plugins/org.open.scientific_calc/download') {
            return http.Response.bytes(zipBytes, 200);
          }
          return http.Response('Not Found', 404);
        });

        PluginMarketplaceService.instance.configureForTesting(
          client: mockClient,
          baseUrl: 'http://marketplace.test',
        );

        final catalog = await PluginManager.instance.syncMarketplaceCatalog();
        expect(catalog, hasLength(1));
        expect(
          PluginManager.instance.availablePlugins.any(
            (p) => p.id == 'org.open.scientific_calc',
          ),
          isTrue,
        );
        expect(
          PluginManager.instance.isInstalled('org.open.scientific_calc'),
          isFalse,
        );

        // Trigger on-demand download & extraction
        await PluginManager.instance.install('org.open.scientific_calc');

        expect(
          PluginManager.instance.isInstalled('org.open.scientific_calc'),
          isTrue,
        );
        final installed = PluginManager.instance.getPlugin(
          'org.open.scientific_calc',
        );
        expect(installed, isNotNull);
        expect(installed!.installDirectory, isNotNull);
        expect(installed.installDirectory!.existsSync(), isTrue);
        expect(installed.getFileString('ui/index.html'), contains('<h1>OK</h1>'));
      },
    );

    test(
      'StudioState runs floating_window plugin and drawer_panel lesson plugin simultaneously',
      () {
        final studio = StudioState();

        final drawerPlugin = InstalledPlugin(
          manifest: PluginManifest(
            id: 'org.open.lesson_assistant',
            name: 'Trợ giảng Bài học',
            uiPlacement: 'drawer_panel',
            contributesTools: const [
              PluginToolContribution(
                id: 'grammar_analysis',
                label: 'Phân tích câu',
                icon: 'auto_Fix_high',
              ),
            ],
          ),
        );

        final floatingPlugin = InstalledPlugin(
          manifest: PluginManifest(
            id: 'org.open.floating_calc',
            name: 'Máy tính Nổi',
            uiPlacement: 'floating_window',
          ),
        );

        // 1. Open lesson drawer plugin first
        studio.openPlugin(drawerPlugin, openModal: true);
        expect(studio.activePlugin?.id, equals('org.open.lesson_assistant'));
        expect(studio.showPluginDrawer, isTrue);
        expect(studio.floatingPlugin, isNull);

        // 2. Open floating calculator while lesson plugin is active
        studio.openPlugin(floatingPlugin, openModal: false);
        expect(
          studio.activePlugin?.id,
          equals('org.open.lesson_assistant'),
          reason: 'Mở cửa sổ nổi không được ghi đè plugin gắn bài giảng',
        );
        expect(studio.showPluginDrawer, isTrue);
        expect(studio.floatingPlugin?.id, equals('org.open.floating_calc'));
        expect(studio.pluginFloating, isTrue);

        // 3. Close floating calculator -> lesson plugin remains intact
        studio.closeFloatingPlugin();
        expect(studio.floatingPlugin, isNull);
        expect(studio.pluginFloating, isFalse);
        expect(studio.activePlugin?.id, equals('org.open.lesson_assistant'));
        expect(studio.showPluginDrawer, isTrue);
      },
    );
  });
}

