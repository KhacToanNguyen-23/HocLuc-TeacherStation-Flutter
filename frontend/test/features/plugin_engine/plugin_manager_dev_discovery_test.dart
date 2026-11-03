import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testRoot;
  late Directory bundledDirectory;

  setUp(() {
    testRoot = Directory.systemTemp.createTempSync('plugin_dev_discovery_');
    bundledDirectory = Directory('${testRoot.path}/bundled')..createSync();
    PluginStorageManager.instance.setBaseDirectoryForTesting(
      Directory('${testRoot.path}/cache'),
    );
    PluginManager.instance.resetForTesting();
  });

  tearDown(() {
    PluginManager.instance.resetForTesting();
    if (testRoot.existsSync()) testRoot.deleteSync(recursive: true);
  });

  test(
    'unpacked development source takes precedence over a bundled archive',
    () async {
      const pluginId = 'com.hocluc.test.dev-precedence';
      await _writePluginArchive(
        bundledDirectory,
        id: pluginId,
        name: 'Bundled plugin',
      );
      final sourceDirectory = Directory(
        '${bundledDirectory.path}/plugin-source',
      )..createSync();
      await File('${sourceDirectory.path}/manifest.json').writeAsString(
        jsonEncode({
          'id': pluginId,
          'name': 'Working source',
          'version': '1.0.0',
          'ui': {'entry': 'ui/index.html'},
        }),
      );
      await Directory('${sourceDirectory.path}/ui').create();
      await File(
        '${sourceDirectory.path}/ui/index.html',
      ).writeAsString('<h1>Working source</h1>');

      final manager = PluginManager.instance;
      await manager.discoverAvailablePlugins(
        standardDirectories: [bundledDirectory],
      );

      final plugin = manager.availablePlugins
          .whereType<InstalledPlugin>()
          .singleWhere((item) => item.id == pluginId);
      expect(plugin.name, 'Working source');
      expect(plugin.sourceFile, isNull);
      expect(
        plugin.installDirectory!.path.replaceAll('\\', '/').toLowerCase(),
        sourceDirectory.path.replaceAll('\\', '/').toLowerCase(),
      );
      expect(plugin.isDevelopmentSource, isTrue);
    },
  );
}

Future<void> _writePluginArchive(
  Directory directory, {
  required String id,
  required String name,
}) async {
  final manifestBytes = utf8.encode(
    jsonEncode({
      'id': id,
      'name': name,
      'version': '1.0.0',
      'ui': {'entry': 'ui/index.html'},
    }),
  );
  final archive = Archive()
    ..addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
  final bytes = ZipEncoder().encode(archive);
  await File('${directory.path}/plugin.hlep').writeAsBytes(bytes);
}
