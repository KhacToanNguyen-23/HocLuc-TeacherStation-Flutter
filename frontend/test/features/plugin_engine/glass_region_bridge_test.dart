import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/services/glass_region_service.dart';
import 'package:teaching_companion/features/plugin_engine/services/host_bridge.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

void main() {
  const viewToken = 'bridge-test-view';
  const webViewBounds = Rect.fromLTWH(40, 30, 600, 400);
  const payload = {
    'region_id': 'result-card',
    'bounds': {'x': 40, 'y': 50, 'width': 200, 'height': 100},
    'viewport': {'width': 1200, 'height': 800},
    'visible': true,
  };
  final service = GlassRegionService.instance;
  late StudioState studio;
  late PluginManifest manifest;
  late int generation;
  Map<String, Object> messagePayload(Map<String, Object> value) => {
    'host_generation': generation,
    'action': 'glass:register',
    'payload': value,
  };

  setUp(() {
    studio = StudioState();
    manifest = PluginManifest(id: 'test.glass.bridge', name: 'Glass bridge');
    studio.activePlugin = InstalledPlugin(manifest: manifest);
    generation = service.beginNavigation(viewToken);
  });

  tearDown(() {
    service.disposeView(viewToken);
    studio.dispose();
  });

  test('registers a region through the typed HocLuc host bridge', () async {
    final response = await HostBridge.instance.handleMessage(
      rawMessage: messagePayload(payload),
      studio: studio,
      manifest: manifest,
      executeJs: null,
      viewToken: viewToken,
      navigationGeneration: generation,
      webViewBounds: webViewBounds,
    );

    expect(response['success'], isTrue);
    expect(response['data']['accepted'], isTrue);
    expect(
      service.regionFor(viewToken, 'result-card')?.bounds,
      const Rect.fromLTWH(60, 55, 100, 50),
    );
    expect(service.regionFor(viewToken, 'result-card')?.pluginId, manifest.id);
  });

  test(
    'rejects a stale navigation message without restoring its region',
    () async {
      service.beginNavigation(viewToken);
      final response = await HostBridge.instance.handleMessage(
        rawMessage: messagePayload(payload),
        studio: studio,
        manifest: manifest,
        executeJs: null,
        viewToken: viewToken,
        navigationGeneration: generation,
        webViewBounds: webViewBounds,
      );

      expect(response['success'], isFalse);
      expect(service.regionFor(viewToken, 'result-card'), isNull);
    },
  );

  test('rejects glass actions without a host-owned WebView identity', () async {
    final response = await HostBridge.instance.handleMessage(
      rawMessage: messagePayload(payload),
      studio: studio,
      manifest: manifest,
      executeJs: null,
    );

    expect(response['success'], isFalse);
    expect(response['error'], contains('WebView context'));
  });

  test(
    'rejects messages from a plugin view that is no longer active',
    () async {
      studio.activePlugin = null;
      final response = await HostBridge.instance.handleMessage(
        rawMessage: messagePayload(payload),
        studio: studio,
        manifest: manifest,
        executeJs: null,
        viewToken: viewToken,
        navigationGeneration: generation,
        webViewBounds: webViewBounds,
      );

      expect(response['success'], isFalse);
      expect(service.regionFor(viewToken, 'result-card'), isNull);
    },
  );

  test(
    'rejects a queued message carrying the previous document generation',
    () async {
    final response = await HostBridge.instance.handleMessage(
      rawMessage: {
        'host_generation': generation - 1,
        'action': 'glass:register',
        'payload': payload,
      },
      studio: studio,
      manifest: manifest,
      executeJs: null,
      viewToken: viewToken,
      navigationGeneration: generation,
      webViewBounds: webViewBounds,
    );

    expect(response['success'], isFalse);
    expect(response['error'], contains('Stale glass region document'));
    expect(service.regionFor(viewToken, 'result-card'), isNull);
    },
  );
}
