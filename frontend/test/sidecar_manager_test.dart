import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/services/sidecar_manager.dart';

void main() {
  group('Phase 04: SidecarManager', () {
    test('SidecarManager checks health accurately with mock client', () async {
      final mockClient = MockClient((request) async {
        if (request.url.port == 18888) {
          return http.Response('{"status": "ok"}', 200);
        }
        return http.Response('Not found', 404);
      });

      final manager = SidecarManager(client: mockClient);
      expect(await manager.checkHealth(18888), isTrue);
      expect(await manager.checkHealth(19999), isFalse);
    });

    test('SidecarManager handles non-existent binary gracefully', () async {
      final manager = SidecarManager();
      final started = await manager.startSidecar(
        executable: 'non_existent_service.exe',
        port: 18888,
      );
      expect(started, isFalse);
      expect(manager.isRunning, isFalse);
      expect(manager.activePort, isNull);
    });

    test('SidecarManager stopSidecar resets active state', () async {
      final manager = SidecarManager();
      await manager.stopSidecar();
      expect(manager.isRunning, isFalse);
      expect(manager.activePort, isNull);
    });
  });
}
