import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/services/plugin_manager.dart';
import 'package:teaching_companion/services/plugin_storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late Directory tempTestDir;

  setUp(() {
    tempTestDir = Directory.systemTemp.createTempSync('hocluc_test_plugins_');
    PluginStorageManager.instance.setBaseDirectoryForTesting(tempTestDir);
    PluginManager.instance.resetForTesting();
  });

  tearDown(() {
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('PluginStorageManager Tests', () {
    test('getPluginsRootDirectory returns test directory', () {
      final root = PluginStorageManager.instance.getPluginsRootDirectory();
      expect(root.existsSync(), isTrue);
      expect(root.path, equals(tempTestDir.path));
    });

    test(
      'installFromZip extracts archive to disk and parses manifest',
      () async {
        final archive = Archive();
        final manifestJson = jsonEncode({
          'id': 'com.hocluc.test.math',
          'name': 'Math Tool',
          'version': '1.0.0',
          'main': 'ui/index.html',
        });

        archive.addFile(
          ArchiveFile(
            'manifest.json',
            manifestJson.length,
            utf8.encode(manifestJson),
          ),
        );
        archive.addFile(
          ArchiveFile('ui/index.html', 12, utf8.encode('<h1>Math</h1>')),
        );

        final zipBytes = ZipEncoder().encode(archive);
        final installedDir = await PluginStorageManager.instance.installFromZip(
          zipBytes,
        );

        expect(installedDir.existsSync(), isTrue);
        expect(File('${installedDir.path}/manifest.json').existsSync(), isTrue);
        expect(File('${installedDir.path}/ui/index.html').existsSync(), isTrue);

        final manifest = PluginStorageManager.instance.loadManifestFromDir(
          installedDir,
        );
        expect(manifest, isNotNull);
        expect(manifest!.id, equals('com.hocluc.test.math'));
        expect(manifest.name, equals('Math Tool'));
      },
    );

    test('uninstall removes plugin directory from disk', () async {
      final archive = Archive();
      final manifestJson = jsonEncode({
        'id': 'com.hocluc.test.remove',
        'name': 'Remove Me',
        'version': '1.0.0',
      });
      archive.addFile(
        ArchiveFile(
          'manifest.json',
          manifestJson.length,
          utf8.encode(manifestJson),
        ),
      );
      final zipBytes = ZipEncoder().encode(archive);
      final installedDir = await PluginStorageManager.instance.installFromZip(
        zipBytes,
      );
      expect(installedDir.existsSync(), isTrue);

      await PluginStorageManager.instance.uninstall('com.hocluc.test.remove');
      expect(installedDir.existsSync(), isFalse);
    });

    test(
      'PluginManager installPluginFromBytes installs and reads files from disk',
      () async {
        final archive = Archive();
        final manifestJson = jsonEncode({
          'id': 'com.hocluc.test.reader',
          'name': 'Reader',
          'version': '2.0.0',
          'main': 'ui/index.html',
        });
        archive.addFile(
          ArchiveFile(
            'manifest.json',
            manifestJson.length,
            utf8.encode(manifestJson),
          ),
        );
        archive.addFile(
          ArchiveFile('ui/index.html', 15, utf8.encode('<html>Read</html>')),
        );
        final zipBytes = ZipEncoder().encode(archive);

        final plugin = await PluginManager.instance.installPluginFromBytes(
          zipBytes,
          'reader.hlep',
        );

        expect(plugin.id, equals('com.hocluc.test.reader'));
        expect(
          PluginManager.instance.isInstalled('com.hocluc.test.reader'),
          isTrue,
        );
        expect(
          plugin.getFileString('ui/index.html'),
          equals('<html>Read</html>'),
        );

        await PluginManager.instance.uninstallPlugin('com.hocluc.test.reader');
        expect(
          PluginManager.instance.isInstalled('com.hocluc.test.reader'),
          isFalse,
        );
      },
    );
  });
}
