import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:teaching_companion/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/services/process_supervisor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Architecture Invariant Tests (Hệ Thống Phòng Vệ Kiến Trúc)', () {
    test('Bất biến 1: Không có chuỗi hardcode tên riêng plugin trong lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'Thư mục lib/ phải tồn tại');

      const forbiddenTokens = [
        'english_assistant',
        'com.hocluc.plugin.',
        'casio_calculator',
      ];
      final violations = <String>[];
      final files = libDir.listSync(recursive: true).whereType<File>();

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        for (final token in forbiddenTokens) {
          if (content.contains(token)) {
            violations.add('${file.path}: chứa chuỗi hardcode "$token"');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện vi phạm kiến trúc hardcode tên plugin:\n${violations.join("\n")}',
      );
    });

    test('Bất biến 2: Không có cổng tĩnh cố định 18888 trong lib/', () {
      final libDir = Directory('lib');
      final violations = <String>[];
      final files = libDir.listSync(recursive: true).whereType<File>();

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        if (content.contains('18888')) {
          violations.add('${file.path}: chứa cổng tĩnh hardcode "18888"');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện vi phạm kiến trúc cổng mạng tĩnh:\n${violations.join("\n")}',
      );
    });

    test('Bất biến 3: Không import chéo trực tiếp từ lib/ vào plugins/', () {
      final libDir = Directory('lib');
      final violations = <String>[];
      final files = libDir.listSync(recursive: true).whereType<File>();

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        if (content.contains('package:plugins/')) {
          violations.add('${file.path}: import trực tiếp "package:plugins/"');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện vi phạm nhập chéo gói plugin vào Core:\n${violations.join("\n")}',
      );
    });

    test('Bất biến 4: Tất cả plugin trong plugins/ phải có manifest.json Schema v2.1 hợp lệ và gói .hlep đồng bộ', () {
      final candidates = [
        Directory('plugins'),
        Directory('../plugins'),
      ];

      Directory? pluginsDir;
      for (final c in candidates) {
        if (c.existsSync()) {
          pluginsDir = c;
          break;
        }
      }

      expect(pluginsDir, isNotNull, reason: 'Phải tìm thấy thư mục plugins/');

      // 1. Kiểm tra không có gói .hlep mồ côi (Orphan Packages)
      final allHlepFiles = pluginsDir!
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.hlep'));
      for (final hlep in allHlepFiles) {
        final pluginName = p.basenameWithoutExtension(hlep.path);
        final matchingFolder = Directory('${pluginsDir.path}/$pluginName');
        expect(
          matchingFolder.existsSync(),
          isTrue,
          reason:
              'Phát hiện gói mồ côi: ${hlep.path}. Thư mục nguồn plugins/$pluginName không tồn tại! Hãy xóa file .hlep này nếu plugin đã bị gỡ bỏ.',
        );
      }

      final pluginFolders = pluginsDir.listSync().whereType<Directory>();

      for (final folder in pluginFolders) {
        final manifestFile = File('${folder.path}/manifest.json');
        if (!manifestFile.existsSync()) continue;

        final folderName = folder.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last;
        final rawJson = manifestFile.readAsStringSync();
        final map = jsonDecode(rawJson) as Map<String, dynamic>;
        final manifest = PluginManifest.fromJson(map);

        expect(manifest.id, isNotEmpty, reason: 'Plugin ${folder.path} thiếu trường id');
        expect(manifest.name, isNotEmpty, reason: 'Plugin ${folder.path} thiếu trường name');
        expect(manifest.version, isNotEmpty, reason: 'Plugin ${folder.path} thiếu trường version');
        expect(manifest.uiEntry, isNotEmpty, reason: 'Plugin ${folder.path} thiếu trường ui.entry/main');
        expect(
          ['floating_window', 'bottom_drawer', 'drawer_panel', 'right_panel'],
          contains(manifest.uiPlacement),
          reason: 'Plugin ${folder.path} có ui.placement không hợp lệ: ${manifest.uiPlacement}',
        );
        expect(
          manifest.uiDefaultWidth,
          greaterThan(100),
          reason: 'Plugin ${folder.path} phải khai báo default_width > 100',
        );
        expect(
          manifest.uiDefaultHeight,
          greaterThan(100),
          reason: 'Plugin ${folder.path} phải khai báo default_height > 100',
        );

        final uiEntryFile = File('${folder.path}/${manifest.uiEntry}');
        expect(
          uiEntryFile.existsSync(),
          isTrue,
          reason: 'Plugin ${folder.path} thiếu file giao diện chính ${manifest.uiEntry}',
        );

        final hlepFile = File('${pluginsDir.path}/$folderName.hlep');
        expect(
          hlepFile.existsSync(),
          isTrue,
          reason:
              'Plugin "$folderName" chưa được đóng gói thành plugins/$folderName.hlep. Hãy chạy: node scripts/package_plugin.mjs $folderName',
        );

        // 2. Kiểm tra Deep Content Integrity của gói .hlep
        final archiveBytes = hlepFile.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(archiveBytes);
        final archiveFilesMap = {
          for (final f in archive.files) f.name.replaceAll('\\', '/'): f
        };

        // Kiểm tra manifest.json bên trong zip khớp phiên bản
        final zipManifestFile = archiveFilesMap['manifest.json'];
        expect(
          zipManifestFile,
          isNotNull,
          reason: 'Gói $folderName.hlep thiếu manifest.json bên trong archive!',
        );
        final zipManifestMap = jsonDecode(
          utf8.decode(zipManifestFile!.content as List<int>),
        ) as Map<String, dynamic>;
        expect(
          zipManifestMap['version'],
          equals(manifest.version),
          reason:
              'Gói $folderName.hlep có version (${zipManifestMap['version']}) không khớp với manifest.json trên đĩa (${manifest.version})! Hãy chạy: node scripts/package_plugin.mjs $folderName',
        );

        // Kiểm tra mọi file trên đĩa đều có trong zip
        final diskFiles = folder
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) {
          final rel = p.relative(f.path, from: folder.path).replaceAll('\\', '/');
          return !rel.contains('__pycache__') &&
              !rel.contains('.venv') &&
              !rel.contains('node_modules') &&
              !rel.startsWith('.');
        });

        for (final diskFile in diskFiles) {
          final relPath =
              p.relative(diskFile.path, from: folder.path).replaceAll('\\', '/');
          expect(
            archiveFilesMap.containsKey(relPath),
            isTrue,
            reason:
                'Gói $folderName.hlep bị THIẾU FILE: $relPath! Hãy chạy: node scripts/package_plugin.mjs $folderName',
          );
        }
      }
    });

    test('Bất biến 5: ProcessSupervisor phân bổ cổng động không bị trùng lặp', () async {
      final portA = await ProcessSupervisor.findAvailablePort();
      final portB = await ProcessSupervisor.findAvailablePort();

      expect(portA, greaterThan(1024));
      expect(portB, greaterThan(1024));
    });

    test('Bất biến 6: Không có God Class vượt quá giới hạn dòng (Frontend <= 900 dòng, Backend <= 600 dòng)', () {
      const maxDartLines = 900;
      const maxJavaLines = 600;
      final violations = <String>[];

      final libDir = Directory('lib');
      if (libDir.existsSync()) {
        final dartFiles = libDir.listSync(recursive: true).whereType<File>();
        for (final file in dartFiles) {
          if (!file.path.endsWith('.dart')) continue;
          final lineCount = file.readAsLinesSync().length;
          if (lineCount > maxDartLines) {
            violations.add(
              'Frontend God File: ${file.path} có $lineCount dòng (vượt giới hạn $maxDartLines dòng)',
            );
          }
        }
      }

      final backendCandidates = [
        Directory('backend/api/src/main/java'),
        Directory('../backend/api/src/main/java'),
      ];
      for (final dir in backendCandidates) {
        if (dir.existsSync()) {
          final javaFiles = dir.listSync(recursive: true).whereType<File>();
          for (final file in javaFiles) {
            if (!file.path.endsWith('.java')) continue;
            final lineCount = file.readAsLinesSync().length;
            if (lineCount > maxJavaLines) {
              violations.add(
                'Backend God File: ${file.path} có $lineCount dòng (vượt giới hạn $maxJavaLines dòng)',
              );
            }
          }
          break;
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Phát hiện file vượt ngưỡng dòng tối đa (Anti-God-Class Invariant):\n${violations.join("\n")}',
      );
    });

    test('Bất biến 7: Không có file .dart mồ côi (Dead Code) và không giữ Map<String, Uint8List> trong RAM của InstalledPlugin', () {
      final libDir = Directory('lib');
      final testDir = Directory('test');
      final allDartFiles = [
        ...libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
        if (testDir.existsSync())
          ...testDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
      ];

      final combinedSource = StringBuffer();
      for (final f in allDartFiles) {
        combinedSource.write(f.readAsStringSync());
        combinedSource.write('\n');
      }
      final fullCorpus = combinedSource.toString();

      final orphanFiles = <String>[];
      final libDartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in libDartFiles) {
        final fileName = file.uri.pathSegments.last;
        if (fileName == 'main.dart' || fileName == 'services.dart') continue;
        // Must appear in an import, export, or part directive in the codebase
        if (!fullCorpus.contains("'$fileName'") &&
            !fullCorpus.contains('/$fileName\'') &&
            !fullCorpus.contains('"$fileName"') &&
            !fullCorpus.contains('/$fileName"')) {
          orphanFiles.add(file.path);
        }
      }

      expect(
        orphanFiles,
        isEmpty,
        reason: 'Phát hiện file .dart mồ côi (Dead Code) trong lib/:\n${orphanFiles.join("\n")}',
      );

      final pluginManagerFiles = [
        File('lib/features/plugin_engine/services/plugin_manager.dart'),
        File('lib/services/plugin_manager.dart'),
      ];
      for (final pluginManagerFile in pluginManagerFiles) {
        if (pluginManagerFile.existsSync()) {
          final pmContent = pluginManagerFile.readAsStringSync();
          expect(
            pmContent.contains('Map<String, Uint8List> files'),
            isFalse,
            reason: 'InstalledPlugin không được giữ Map<String, Uint8List> files trong RAM (vi phạm AGENTS.md Rule 2.4)',
          );
        }
      }
    });

    test('Bất biến 8: Cấm file code trôi nổi trực tiếp trong lib/widgets/ và lib/services/', () {
      final forbiddenDirs = [Directory('lib/widgets'), Directory('lib/services')];
      final violations = <String>[];

      for (final dir in forbiddenDirs) {
        if (dir.existsSync()) {
          final files = dir.listSync(recursive: true).whereType<File>();
          for (final f in files) {
            violations.add('File trôi nổi trong ${dir.path}: ${f.path}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện file trôi nổi ngoài module Clean Architecture (phải đặt trong lib/features/ hoặc lib/core/):\n${violations.join("\n")}',
      );
    });

    test('Bất biến 9: Cấm file test nằm phẳng ở thư mục gốc test/ (ngoại trừ architecture_test.dart)', () {
      final testDir = Directory('test');
      expect(testDir.existsSync(), isTrue, reason: 'Thư mục test/ phải tồn tại');

      final rootFiles = testDir.listSync(recursive: false).whereType<File>();
      final violations = <String>[];

      for (final f in rootFiles) {
        final baseName = p.basename(f.path);
        if (baseName != 'architecture_test.dart') {
          violations.add('File test nằm phẳng ở root test/: $baseName');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện file test nằm phẳng ở root test/ (phải đặt trong test/features/ hoặc test/e2e_browser/):\n${violations.join("\n")}',
      );
    });

    test('Bất biến 10: Cấm khai báo dependency path ma trong pubspec.yaml', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml phải tồn tại');

      final content = pubspecFile.readAsStringSync();
      final lines = content.split('\n');
      final ghostDependencies = <String>[];

      final pathRegex = RegExp(r'^\s{4,}path:\s*(.+)$');
      for (var i = 0; i < lines.length; i++) {
        final rawLine = lines[i];
        final match = pathRegex.firstMatch(rawLine);
        if (match != null) {
          final pathVal = match.group(1)!.trim().replaceAll("'", '').replaceAll('"', '');
          final resolvedDir = Directory(pathVal);
          if (!resolvedDir.existsSync()) {
            ghostDependencies.add('Dòng ${i + 1}: path: $pathVal không tồn tại trên đĩa');
          }
        }
      }

      expect(
        ghostDependencies,
        isEmpty,
        reason: 'Phát hiện dependency ma (path không tồn tại) trong pubspec.yaml:\n${ghostDependencies.join("\n")}',
      );
    });
  });
}

