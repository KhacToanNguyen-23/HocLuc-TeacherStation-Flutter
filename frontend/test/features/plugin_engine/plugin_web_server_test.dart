import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_storage_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_web_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;
  final server = PluginWebServer.instance;

  setUp(() async {
    HttpOverrides.global = null;
    tempTestDir = Directory.systemTemp.createTempSync('hocluc_web_test_');
    PluginStorageManager.instance.setBaseDirectoryForTesting(tempTestDir);
    await server.start();
  });

  tearDown(() async {
    await server.stop();
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('PluginWebServer Tests', () {
    test('Server binds to local port and reports isRunning', () {
      expect(server.isRunning, isTrue);
      expect(server.port, isNotNull);
      expect(server.port!, greaterThan(1024));
    });

    test('getUrl constructs proper local loopback URL', () {
      final url = server.getUrl('com.test.tool', 'ui/index.html');
      expect(url, equals('http://127.0.0.1:${server.port}/plugins/com.test.tool/ui/index.html'));
    });

    test('Serves static plugin file with correct CORS and Content-Type', () async {
      final pluginDir = Directory('${tempTestDir.path}/com.test.calc/v1.0.0/ui');
      pluginDir.createSync(recursive: true);

      final indexFile = File('${pluginDir.path}/index.html');
      indexFile.writeAsStringSync('<!DOCTYPE html><html><body><h1>Calc UI</h1></body></html>');

      final manifestFile = File('${tempTestDir.path}/com.test.calc/v1.0.0/manifest.json');
      manifestFile.writeAsStringSync(jsonEncode({
        'id': 'com.test.calc',
        'name': 'Calculator',
        'version': '1.0.0',
        'main': 'ui/index.html',
      }));

      final client = HttpClient();
      final uri = Uri.parse(server.getUrl('com.test.calc', 'ui/index.html')!);
      final request = await client.getUrl(uri);
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('Access-Control-Allow-Origin'), equals('*'));
      expect(response.headers.contentType?.mimeType, equals('text/html'));

      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('<h1>Calc UI</h1>'));

      client.close();
    });

    test('Returns 404 for non-existent plugin asset', () async {
      final client = HttpClient();
      final uri = Uri.parse('http://127.0.0.1:${server.port}/plugins/nonexistent/ui/index.html');
      final request = await client.getUrl(uri);
      final response = await request.close();

      expect(response.statusCode, HttpStatus.notFound);
      client.close();
    });
  });
}

