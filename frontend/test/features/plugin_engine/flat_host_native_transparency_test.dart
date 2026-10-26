import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/presentation/flat_host_native.dart';
import 'package:teaching_companion/features/plugin_engine/presentation/flat_host_message.dart';
import 'package:teaching_companion/features/plugin_engine/services/glass_region_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('updates native transparency when reused for another plugin', (
    tester,
  ) async {
    const controllerChannel = MethodChannel('io.jns.webview.win');
    const viewChannel = MethodChannel('io.jns.webview.win/744');
    const eventsChannel = EventChannel('io.jns.webview.win/744/events');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MockStreamHandlerEventSink? eventSink;
    var failOpaqueRestore = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    messenger.setMockMethodCallHandler(controllerChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getWebViewVersion':
          return 'test-webview2';
        case 'initialize':
          return {'textureId': 744};
        case 'dispose':
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(viewChannel, (call) async {
      calls.add(call);
      if (call.method == 'setBackgroundColor' &&
          call.arguments == -1 &&
          failOpaqueRestore) {
        throw PlatformException(code: 'opaque_restore_unavailable');
      }
      return null;
    });
    messenger.setMockStreamHandler(
      eventsChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          eventSink = sink;
        },
      ),
    );
    try {
      failOpaqueRestore = true;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlatHost(
              url: 'https://example.test/glass-plugin',
              transparentBackground: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      eventSink!.success({'type': 'loadingStateChanged', 'value': 2});
      await tester.pump();
      expect(
        calls.lastWhere((call) => call.method == 'executeScript').arguments,
        contains("hoclucTransparentBackground = 'true'"),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlatHost(
              url: 'https://example.test/opaque-plugin',
              transparentBackground: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      eventSink!.success({'type': 'loadingStateChanged', 'value': 2});
      await tester.pump();
      expect(
        calls.lastWhere((call) => call.method == 'executeScript').arguments,
        contains("hoclucTransparentBackground = 'false'"),
      );
      expect(
        find.byKey(const ValueKey('webview-opaque-fallback')),
        findsOneWidget,
      );

      final opaqueBackgroundCall = calls.lastIndexWhere(
        (call) => call.method == 'setBackgroundColor',
      );
      final opaqueNavigationCall = calls.lastIndexWhere(
        (call) => call.method == 'loadUrl',
      );
      expect(opaqueBackgroundCall, greaterThan(0));
      expect(calls[opaqueBackgroundCall].arguments, -1);
      expect(opaqueNavigationCall, greaterThan(opaqueBackgroundCall));
      expect(
        calls[opaqueNavigationCall].arguments,
        'https://example.test/opaque-plugin',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlatHost(
              url: 'https://example.test/glass-plugin-again',
              transparentBackground: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      eventSink!.success({'type': 'loadingStateChanged', 'value': 2});
      await tester.pump();
      expect(
        calls.lastWhere((call) => call.method == 'executeScript').arguments,
        contains("hoclucTransparentBackground = 'true'"),
      );
      expect(
        find.byKey(const ValueKey('webview-opaque-fallback')),
        findsNothing,
      );

      final transparentBackgroundCall = calls.lastIndexWhere(
        (call) => call.method == 'setBackgroundColor',
      );
      final transparentNavigationCall = calls.lastIndexWhere(
        (call) => call.method == 'loadUrl',
      );
      expect(transparentBackgroundCall, greaterThan(opaqueNavigationCall));
      expect(calls[transparentBackgroundCall].arguments, 0);
      expect(transparentNavigationCall, greaterThan(transparentBackgroundCall));
      expect(
        calls[transparentNavigationCall].arguments,
        'https://example.test/glass-plugin-again',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(controllerChannel, null);
      messenger.setMockMethodCallHandler(viewChannel, null);
      messenger.setMockStreamHandler(eventsChannel, null);
    }
  });

  testWidgets('queues plugin replacement until the old navigation completes', (
    tester,
  ) async {
    const controllerChannel = MethodChannel('io.jns.webview.win');
    const viewChannel = MethodChannel('io.jns.webview.win/745');
    const eventsChannel = EventChannel('io.jns.webview.win/745/events');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MockStreamHandlerEventSink? eventSink;
    dynamic receivedMessage;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    messenger.setMockMethodCallHandler(controllerChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getWebViewVersion':
          return 'test-webview2';
        case 'initialize':
          return {'textureId': 745};
        case 'dispose':
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(viewChannel, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      eventsChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          eventSink = sink;
        },
      ),
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlatHost(
              url: 'https://example.test/old-plugin',
              onMessage: (message) => receivedMessage = message,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(eventSink, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlatHost(
              url: 'https://example.test/new-plugin',
              onMessage: (message) => receivedMessage = message,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(calls.where((call) => call.method == 'loadUrl').length, 1);

      // Completing the old document should start the queued replacement but
      // must not make it ready or allow its messages through.
      eventSink!.success({'type': 'loadingStateChanged', 'value': 2});
      await tester.pump();
      expect(calls.where((call) => call.method == 'loadUrl').length, 2);
      eventSink!.success({
        'type': 'webMessageReceived',
        'value': jsonEncode({'action': 'old:document'}),
      });
      await tester.pump();
      expect(receivedMessage, isNull);

      eventSink!.success({'type': 'loadingStateChanged', 'value': 2});
      await tester.pump();
      expect(receivedMessage, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(controllerChannel, null);
      messenger.setMockMethodCallHandler(viewChannel, null);
      messenger.setMockStreamHandler(eventsChannel, null);
    }
  });

  testWidgets('sets transparent WebView background before first navigation', (
    tester,
  ) async {
    const controllerChannel = MethodChannel('io.jns.webview.win');
    const viewChannel = MethodChannel('io.jns.webview.win/741');
    const eventsChannel = EventChannel('io.jns.webview.win/741/events');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    messenger.setMockMethodCallHandler(controllerChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getWebViewVersion':
          return 'test-webview2';
        case 'initialize':
          return {'textureId': 741};
        case 'dispose':
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(viewChannel, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      eventsChannel,
      const MockStreamHandler.inline(onListen: _ignoreEvents),
    );
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlatHost(
              url: 'https://example.test/plugin',
              transparentBackground: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final initializeCall = calls.indexWhere(
        (call) => call.method == 'initialize',
      );
      final backgroundCall = calls.indexWhere(
        (call) => call.method == 'setBackgroundColor',
      );
      final navigationCall = calls.indexWhere(
        (call) => call.method == 'loadUrl',
      );

      expect(initializeCall, isNonNegative);
      expect(backgroundCall, greaterThan(initializeCall));
      expect(calls[backgroundCall].arguments, 0);
      expect(navigationCall, greaterThan(backgroundCall));
      expect(calls[navigationCall].arguments, 'https://example.test/plugin');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(controllerChannel, null);
      messenger.setMockMethodCallHandler(viewChannel, null);
      messenger.setMockStreamHandler(eventsChannel, null);
    }
  });

  testWidgets('continues in opaque fallback when WebView transparency fails', (
    tester,
  ) async {
    const controllerChannel = MethodChannel('io.jns.webview.win');
    const viewChannel = MethodChannel('io.jns.webview.win/743');
    const eventsChannel = EventChannel('io.jns.webview.win/743/events');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    messenger.setMockMethodCallHandler(controllerChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getWebViewVersion':
          return 'test-webview2';
        case 'initialize':
          return {'textureId': 743};
        case 'dispose':
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(viewChannel, (call) async {
      calls.add(call);
      if (call.method == 'setBackgroundColor') {
        throw PlatformException(code: 'transparency_unavailable');
      }
      return null;
    });
    messenger.setMockStreamHandler(
      eventsChannel,
      const MockStreamHandler.inline(onListen: _ignoreEvents),
    );
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlatHost(
              url: 'https://example.test/plugin',
              transparentBackground: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final backgroundCall = calls.indexWhere(
        (call) => call.method == 'setBackgroundColor',
      );
      final navigationCall = calls.indexWhere(
        (call) => call.method == 'loadUrl',
      );
      expect(backgroundCall, isNonNegative);
      expect(navigationCall, greaterThan(backgroundCall));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(controllerChannel, null);
      messenger.setMockMethodCallHandler(viewChannel, null);
      messenger.setMockStreamHandler(eventsChannel, null);
    }
  });

  testWidgets('pairs plugin messages with their WebView identity and bounds', (
    tester,
  ) async {
    const controllerChannel = MethodChannel('io.jns.webview.win');
    const viewChannel = MethodChannel('io.jns.webview.win/742');
    const eventsChannel = EventChannel('io.jns.webview.win/742/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MockStreamHandlerEventSink? eventSink;
    FlatHostMessage? received;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    messenger.setMockMethodCallHandler(controllerChannel, (call) async {
      switch (call.method) {
        case 'getWebViewVersion':
          return 'test-webview2';
        case 'initialize':
          return {'textureId': 742};
        case 'dispose':
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(viewChannel, (_) async => null);
    messenger.setMockStreamHandler(
      eventsChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          eventSink = sink;
        },
      ),
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 200,
                child: FlatHost(
                  url: 'https://example.test/plugin',
                  onPluginMessage: (message) => received = message,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(eventSink, isNotNull);
      eventSink!.success({'type': 'loadingStateChanged', 'value': 2});
      await tester.pump();

      eventSink!.success({
        'type': 'webMessageReceived',
        'value': jsonEncode({'action': 'glass:register'}),
      });
      await tester.pump();

      expect(received, isNotNull);
      expect(received!.data, {'action': 'glass:register'});
      expect(received!.viewToken, startsWith('webview-instance-'));
      expect(received!.navigationGeneration, greaterThan(0));
      expect(received!.webViewBounds, const Rect.fromLTWH(0, 0, 300, 200));

      final service = GlassRegionService.instance;
      expect(
        service.handleMessage(
          viewToken: received!.viewToken,
          pluginId: 'test.glass.host',
          navigationGeneration: received!.navigationGeneration,
          action: 'glass:register',
          payload: const {
            'region_id': 'card',
            'bounds': {'x': 10, 'y': 10, 'width': 80, 'height': 40},
            'viewport': {'width': 300, 'height': 200},
            'visible': true,
          },
          webViewBounds: received!.webViewBounds,
        ),
        isTrue,
      );
      expect(service.regionFor(received!.viewToken, 'card'), isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 200,
                child: FlatHost(
                  url: 'https://example.test/plugin',
                  visible: false,
                  onPluginMessage: (message) => received = message,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(service.regionFor(received!.viewToken, 'card'), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(controllerChannel, null);
      messenger.setMockMethodCallHandler(viewChannel, null);
      messenger.setMockStreamHandler(eventsChannel, null);
    }
  });
}

void _ignoreEvents(Object? _, MockStreamHandlerEventSink _) {}
