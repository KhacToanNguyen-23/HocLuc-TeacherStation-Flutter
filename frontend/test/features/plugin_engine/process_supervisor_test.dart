import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/plugin_engine/services/host_bridge.dart';
import 'package:teaching_companion/features/plugin_engine/services/process_supervisor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProcessSupervisor Unit Tests', () {
    test('findAvailablePort returns a valid non-zero port', () async {
      final port1 = await ProcessSupervisor.findAvailablePort();
      final port2 = await ProcessSupervisor.findAvailablePort();

      expect(port1, greaterThan(1024));
      expect(port2, greaterThan(1024));
    });

    test(
      'runs a Dart development entry when the packaged binary is absent',
      () async {
        final pluginDirectory = Directory.systemTemp.createTempSync(
          'plugin_dart_dev_runtime_',
        );
        const pluginId = 'com.hocluc.test.dart-dev-runtime';
        final sourceFile = File(
          '${pluginDirectory.path}/engine/dart/bin/dev_server.dart',
        );
        await sourceFile.parent.create(recursive: true);
        await sourceFile.writeAsString('''
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = int.parse(args[1]);
  final server = await HttpServer.bind('127.0.0.1', port);
  server.listen((request) async {
    request.response.write('ok');
    await request.response.close();
  });
}
''');
        final manifest = PluginManifest.fromJson({
          'id': pluginId,
          'name': 'Dart dev runtime',
          'backend': {
            'type': 'binary',
            'entry': 'engine/bin/missing_release_binary.exe',
            'development_entry': 'engine/dart/bin/dev_server.dart',
            'health_endpoint': '/health',
          },
        });
        final supervisor = ProcessSupervisor.testing(
          healthProbe: _probeWithRawSocket,
        );

        try {
          final instance = await supervisor.startSidecar(
            manifest: manifest,
            pluginDirectory: pluginDirectory.path,
          );
          expect(instance, isNotNull);
          expect(
            await _probeWithRawSocket(
              Uri.parse('http://127.0.0.1:${instance!.port}/health'),
            ),
            isTrue,
          );
        } finally {
          await supervisor.stopSidecar(pluginId);
          await pluginDirectory.delete(recursive: true);
        }
      },
    );

    test(
      'runs the English Assistant package entry from source in debug mode',
      () async {
        final pluginDirectory = Directory(
          '../plugins/english_assistant',
        ).absolute;
        final manifestJson =
            jsonDecode(
                  File(
                    '${pluginDirectory.path}/manifest.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final manifest = PluginManifest.fromJson(manifestJson);
        final supervisor = ProcessSupervisor.testing(
          healthProbe: _probeWithRawSocket,
        );

        try {
          final instance = await supervisor.startSidecar(
            manifest: manifest,
            pluginDirectory: pluginDirectory.path,
          );
          expect(instance, isNotNull);
          expect(
            await _probeWithRawSocket(
              Uri.parse('http://127.0.0.1:${instance!.port}/health'),
            ),
            isTrue,
          );
        } finally {
          await supervisor.stopSidecar(manifest.id);
        }
      },
    );
  });

  group('HostBridge RPC Unit Tests', () {
    test('context:get returns app info', () async {
      final studio = StudioState();
      final manifest = PluginManifest(
        id: 'com.hocluc.test',
        name: 'Test Plugin',
      );

      final res = await HostBridge.instance.handleMessage(
        rawMessage: {'id': '123', 'action': 'context:get'},
        studio: studio,
        manifest: manifest,
        executeJs: null,
      );

      expect(res['success'], isTrue);
      expect(res['data']['pluginId'], equals('com.hocluc.test'));
      expect(res['data']['appVersion'], equals('2.0.0'));
    });

    test(
      'storage:set and storage:get persists key-values per plugin',
      () async {
        final studio = StudioState();
        final manifest = PluginManifest(
          id: 'com.hocluc.test',
          name: 'Test Plugin',
          permissions: const ['storage'],
        );

        await HostBridge.instance.handleMessage(
          rawMessage: {
            'id': 'set_1',
            'action': 'storage:set',
            'payload': {'key': 'theme', 'value': 'dark_emerald'},
          },
          studio: studio,
          manifest: manifest,
          executeJs: null,
        );

        final getRes = await HostBridge.instance.handleMessage(
          rawMessage: {
            'id': 'get_1',
            'action': 'storage:get',
            'payload': {'key': 'theme'},
          },
          studio: studio,
          manifest: manifest,
          executeJs: null,
        );

        expect(getRes['success'], isTrue);
        expect(getRes['data']['value'], equals('dark_emerald'));
      },
    );
  });
}

Future<bool> _probeWithRawSocket(Uri targetUri) async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      targetUri.host,
      targetUri.port,
    ).timeout(const Duration(seconds: 1));
    socket.write(
      'GET ${targetUri.path} HTTP/1.1\r\n'
      'Host: ${targetUri.host}:${targetUri.port}\r\n'
      'Connection: close\r\n\r\n',
    );
    await socket.flush();
    final response = await utf8.decoder
        .bind(socket)
        .join()
        .timeout(const Duration(seconds: 1));
    return response.startsWith('HTTP/1.1 200');
  } catch (_) {
    return false;
  } finally {
    socket?.destroy();
  }
}
