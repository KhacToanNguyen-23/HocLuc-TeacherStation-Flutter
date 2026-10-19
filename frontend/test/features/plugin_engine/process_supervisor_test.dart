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

