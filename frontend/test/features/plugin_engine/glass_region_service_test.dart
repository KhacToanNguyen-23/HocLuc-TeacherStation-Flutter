import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/services/glass_region_service.dart';

void main() {
  group('GlassRegionService', () {
    late GlassRegionService service;
    const viewA = 'view-a';
    const viewB = 'view-b';
    const viewport = Size(1200, 800);
    const webViewBounds = Rect.fromLTWH(100, 50, 600, 400);

    setUp(() => service = GlassRegionService());
    tearDown(() => service.dispose());

    int startView(String token) => service.beginNavigation(token);

    Map<String, Object> regionPayload({
      String id = 'result-card',
      double x = 100,
      double y = 80,
      double width = 200,
      double height = 100,
      bool visible = true,
    }) => {
      'region_id': id,
      'bounds': {'x': x, 'y': y, 'width': width, 'height': height},
      'viewport': {'width': viewport.width, 'height': viewport.height},
      'visible': visible,
    };

    test(
      'maps CSS viewport pixels using measured scale and WebView origin',
      () {
        final generation = startView(viewA);

        final accepted = service.handleMessage(
          viewToken: viewA,
          pluginId: 'test.glass',
          navigationGeneration: generation,
          action: 'glass:register',
          payload: regionPayload(),
          webViewBounds: webViewBounds,
        );

        expect(accepted, isTrue);
        expect(
          service.regionFor(viewA, 'result-card')?.bounds,
          const Rect.fromLTWH(150, 90, 100, 50),
        );
      },
    );

    test(
      'rejects invalid and excessive bounds while clipping partial viewport bounds',
      () {
        final generation = startView(viewA);

        expect(
          service.handleMessage(
            viewToken: viewA,
            pluginId: 'test.glass',
            navigationGeneration: generation,
            action: 'glass:register',
            payload: regionPayload(x: double.nan),
            webViewBounds: webViewBounds,
          ),
          isFalse,
        );
        expect(
          service.handleMessage(
            viewToken: viewA,
            pluginId: 'test.glass',
            navigationGeneration: generation,
            action: 'glass:register',
            payload: regionPayload(x: 1190, width: 20),
            webViewBounds: webViewBounds,
          ),
          isTrue,
        );
        expect(
          service.regionFor(viewA, 'result-card')?.localBounds,
          const Rect.fromLTWH(595, 40, 5, 50),
        );
        expect(
          service.handleMessage(
            viewToken: viewA,
            pluginId: 'test.glass',
            navigationGeneration: generation,
            action: 'glass:register',
            payload: regionPayload(width: 5000),
            webViewBounds: webViewBounds,
          ),
          isFalse,
        );
        expect(service.regionsFor(viewA), hasLength(1));
      },
    );

    test(
      'removes a region when an update moves it fully outside the viewport',
      () {
        final generation = startView(viewA);
        service.handleMessage(
          viewToken: viewA,
          pluginId: 'test.glass',
          navigationGeneration: generation,
          action: 'glass:register',
          payload: regionPayload(),
          webViewBounds: webViewBounds,
        );

        expect(
          service.handleMessage(
            viewToken: viewA,
            pluginId: 'test.glass',
            navigationGeneration: generation,
            action: 'glass:update',
            payload: regionPayload(x: 1300),
            webViewBounds: webViewBounds,
          ),
          isTrue,
        );
        expect(service.regionFor(viewA, 'result-card'), isNull);
      },
    );

    test('scopes identical region IDs to separate WebView instances', () {
      final generationA = startView(viewA);
      final generationB = startView(viewB);

      expect(
        service.handleMessage(
          viewToken: viewA,
          pluginId: 'test.glass',
          navigationGeneration: generationA,
          action: 'glass:register',
          payload: regionPayload(x: 10),
          webViewBounds: webViewBounds,
        ),
        isTrue,
      );
      expect(
        service.handleMessage(
          viewToken: viewB,
          pluginId: 'test.glass',
          navigationGeneration: generationB,
          action: 'glass:register',
          payload: regionPayload(x: 20),
          webViewBounds: const Rect.fromLTWH(500, 300, 300, 200),
        ),
        isTrue,
      );

      expect(service.regionsFor(viewA), hasLength(1));
      expect(service.regionsFor(viewB), hasLength(1));
      expect(
        service.regionFor(viewA, 'result-card')?.bounds,
        const Rect.fromLTWH(105, 90, 100, 50),
      );
      expect(
        service.regionFor(viewB, 'result-card')?.bounds,
        const Rect.fromLTWH(505, 320, 50, 25),
      );
    });

    test('updates visibility and unregisters only the addressed region', () {
      final generation = startView(viewA);
      service.handleMessage(
        viewToken: viewA,
        pluginId: 'test.glass',
        navigationGeneration: generation,
        action: 'glass:register',
        payload: regionPayload(),
        webViewBounds: webViewBounds,
      );

      expect(
        service.handleMessage(
          viewToken: viewA,
          pluginId: 'test.glass',
          navigationGeneration: generation,
          action: 'glass:update',
          payload: regionPayload(x: 200, visible: false),
          webViewBounds: webViewBounds,
        ),
        isTrue,
      );
      expect(service.regionFor(viewA, 'result-card'), isNull);

      expect(
        service.handleMessage(
          viewToken: viewA,
          pluginId: 'test.glass',
          navigationGeneration: generation,
          action: 'glass:unregister',
          payload: {'region_id': 'result-card'},
          webViewBounds: webViewBounds,
        ),
        isTrue,
      );
      expect(service.regionsFor(viewA), isEmpty);
    });

    test('rejects stale generations and clears only a navigating view', () {
      final oldGeneration = startView(viewA);
      service.handleMessage(
        viewToken: viewA,
        pluginId: 'test.glass',
        navigationGeneration: oldGeneration,
        action: 'glass:register',
        payload: regionPayload(),
        webViewBounds: webViewBounds,
      );
      final generationB = startView(viewB);
      service.handleMessage(
        viewToken: viewB,
        pluginId: 'test.glass',
        navigationGeneration: generationB,
        action: 'glass:register',
        payload: regionPayload(),
        webViewBounds: webViewBounds,
      );

      final newGeneration = service.beginNavigation(viewA);
      expect(newGeneration, greaterThan(oldGeneration));
      expect(service.regionsFor(viewA), isEmpty);
      expect(service.regionsFor(viewB), hasLength(1));
      expect(
        service.handleMessage(
          viewToken: viewA,
          pluginId: 'test.glass',
          navigationGeneration: oldGeneration,
          action: 'glass:register',
          payload: regionPayload(id: 'stale-card'),
          webViewBounds: webViewBounds,
        ),
        isFalse,
      );
    });

    test('clearing hidden regions retains the active document generation', () {
      final generation = startView(viewA);
      service.handleMessage(
        viewToken: viewA,
        pluginId: 'test.glass',
        navigationGeneration: generation,
        action: 'glass:register',
        payload: regionPayload(),
        webViewBounds: webViewBounds,
      );

      service.clearViewRegions(viewA);

      expect(service.regionsFor(viewA), isEmpty);
      expect(service.currentGeneration(viewA), generation);
    });

    test(
      'coalesces a burst of geometry changes into one notification',
      () async {
        var notifications = 0;
        service.addListener(() => notifications++);
        final generation = startView(viewA);
        notifications = 0;

        for (var left = 100.0; left < 110; left++) {
          service.handleMessage(
            viewToken: viewA,
            pluginId: 'test.glass',
            navigationGeneration: generation,
            action: 'glass:register',
            payload: regionPayload(x: left),
            webViewBounds: webViewBounds,
          );
        }

        expect(notifications, 0);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(notifications, 1);
        expect(service.regionFor(viewA, 'result-card')?.bounds.left, 154.5);
      },
    );

    test('bounds region count per WebView and removes all on disposal', () {
      final generation = startView(viewA);
      for (
        var index = 0;
        index < GlassRegionService.maxRegionsPerView;
        index++
      ) {
        expect(
          service.handleMessage(
            viewToken: viewA,
            pluginId: 'test.glass',
            navigationGeneration: generation,
            action: 'glass:register',
            payload: regionPayload(id: 'card-$index'),
            webViewBounds: webViewBounds,
          ),
          isTrue,
        );
      }
      expect(
        service.handleMessage(
          viewToken: viewA,
          pluginId: 'test.glass',
          navigationGeneration: generation,
          action: 'glass:register',
          payload: regionPayload(id: 'one-too-many'),
          webViewBounds: webViewBounds,
        ),
        isFalse,
      );

      service.disposeView(viewA);
      expect(service.regionsFor(viewA), isEmpty);
      expect(service.currentGeneration(viewA), isNull);
    });
  });
}
