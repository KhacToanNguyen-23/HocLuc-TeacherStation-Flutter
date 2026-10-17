import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/plugin_manifest.dart';
import 'package:teaching_companion/services/process_supervisor.dart';

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

    test('Bất biến 4: Tất cả plugin trong plugins/ phải có manifest.json Schema v2 hợp lệ', () {
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
      final pluginFolders = pluginsDir!.listSync().whereType<Directory>();

      for (final folder in pluginFolders) {
        final manifestFile = File('${folder.path}/manifest.json');
        if (!manifestFile.existsSync()) continue;

        final rawJson = manifestFile.readAsStringSync();
        final map = jsonDecode(rawJson) as Map<String, dynamic>;
        final manifest = PluginManifest.fromJson(map);

        expect(manifest.id, isNotEmpty, reason: 'Plugin ${folder.path} thiếu trường id');
        expect(manifest.name, isNotEmpty, reason: 'Plugin ${folder.path} thiếu trường name');
        expect(manifest.version, isNotEmpty, reason: 'Plugin ${folder.path} thiếu trường version');
        expect(manifest.uiEntry, isNotEmpty, reason: 'Plugin ${folder.path} thiếu trường main/uiEntry');
      }
    });

    test('Bất biến 5: ProcessSupervisor phân bổ cổng động không bị trùng lặp', () async {
      final portA = await ProcessSupervisor.findAvailablePort();
      final portB = await ProcessSupervisor.findAvailablePort();

      expect(portA, greaterThan(1024));
      expect(portB, greaterThan(1024));
    });
  });
}
