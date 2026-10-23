import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/features/plugin_engine/services/host_bridge.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_event_hub.dart';

void main() {
  test('dispatch prunes failing views and reports successful delivery', () {
    final delivered = <String>[];
    void disposedView(String _) => throw StateError('disposed WebView');
    void liveView(String script) => delivered.add(script);
    final hub = PluginEventHub.instance;
    const pluginId = 'com.hocluc.test.disposed_view';
    hub.register(pluginId, disposedView);
    hub.register(pluginId, liveView);

    expect(
      hub.dispatch(pluginId, 'GLASS_PRESET_CHANGE', {'preset': 'clear'}),
      isTrue,
    );
    expect(delivered, hasLength(1));

    hub.unregister(pluginId, liveView);
    expect(
      hub.dispatch(pluginId, 'GLASS_PRESET_CHANGE', {'preset': 'solid'}),
      isFalse,
    );
    expect(delivered, hasLength(1));
  });

  test('dispatch reports failure when no live view accepts the event', () {
    final hub = PluginEventHub.instance;
    const pluginId = 'com.hocluc.test.all_views_disposed';
    void firstDisposedView(String _) => throw StateError('disposed view 1');
    void secondDisposedView(String _) => throw StateError('disposed view 2');
    hub.register(pluginId, firstDisposedView);
    hub.register(pluginId, secondDisposedView);

    expect(
      hub.dispatch(pluginId, 'GLASS_PRESET_CHANGE', {'preset': 'clear'}),
      isFalse,
    );
    expect(
      hub.dispatch(pluginId, 'GLASS_PRESET_CHANGE', {'preset': 'solid'}),
      isFalse,
    );
  });

  test(
    'message streams are released after their last listener cancels',
    () async {
      final hub = PluginEventHub.instance;
      const pluginId = 'com.hocluc.test.message_stream_cleanup';
      final firstStream = hub.messagesFor(pluginId);
      final subscription = firstStream.listen((_) {});
      await subscription.cancel();

      final receivedByReleasedStream = <PluginHostMessage>[];
      final releasedSubscription = firstStream.listen(
        receivedByReleasedStream.add,
      );
      final nextStream = hub.messagesFor(pluginId);
      final receivedByCurrentStream = <PluginHostMessage>[];
      final currentSubscription = nextStream.listen(
        receivedByCurrentStream.add,
      );
      hub.receiveFromPlugin(
        pluginId: pluginId,
        action: 'test:event',
        payload: const {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(receivedByReleasedStream, isEmpty);
      expect(receivedByCurrentStream, hasLength(1));
      await releasedSubscription.cancel();
      await currentSubscription.cancel();
    },
  );

  test('host events fan out to every live view for a plugin', () {
    final firstViewScripts = <String>[];
    final secondViewScripts = <String>[];
    void firstView(String script) => firstViewScripts.add(script);
    void secondView(String script) => secondViewScripts.add(script);
    final hub = PluginEventHub.instance;
    const pluginId = 'com.hocluc.test.multi_view';
    hub.register(pluginId, firstView);
    hub.register(pluginId, secondView);

    expect(
      hub.dispatch(pluginId, 'GLASS_PRESET_CHANGE', {'preset': 'clear'}),
      isTrue,
    );
    expect(firstViewScripts, hasLength(1));
    expect(secondViewScripts, hasLength(1));

    hub.unregister(pluginId, firstView);
    expect(
      hub.dispatch(pluginId, 'GLASS_PRESET_CHANGE', {'preset': 'solid'}),
      isTrue,
    );
    expect(firstViewScripts, hasLength(1));
    expect(secondViewScripts, hasLength(2));

    hub.unregister(pluginId, secondView);
    expect(
      hub.dispatch(pluginId, 'GLASS_PRESET_CHANGE', {'preset': 'frosted'}),
      isFalse,
    );
  });

  test('replacing a mounted plugin view removes its prior plugin sender', () {
    final hub = PluginEventHub.instance;
    const oldPluginId = 'com.hocluc.test.lifecycle_old_plugin';
    const newPluginId = 'com.hocluc.test.lifecycle_new_plugin';
    final oldPageScripts = <String>[];
    final newPageScripts = <String>[];
    void oldPageSender(String script) => oldPageScripts.add(script);
    void newPageSender(String script) => newPageScripts.add(script);
    hub.register(oldPluginId, oldPageSender);

    // FlatHost invokes the prior widget's disposal callback before navigating.
    hub.unregister(oldPluginId, oldPageSender);
    hub.register(newPluginId, newPageSender);

    expect(
      hub.dispatch(oldPluginId, 'GLASS_PRESET_CHANGE', {'preset': 'clear'}),
      isFalse,
    );
    expect(
      hub.dispatch(newPluginId, 'GLASS_PRESET_CHANGE', {'preset': 'clear'}),
      isTrue,
    );
    expect(oldPageScripts, isEmpty);
    expect(newPageScripts, hasLength(1));
    hub.unregister(newPluginId, newPageSender);
  });

  test('host events are routed as JSON through the registered SDK sender', () {
    final sentScripts = <String>[];
    void sender(String script) => sentScripts.add(script);
    final hub = PluginEventHub.instance;
    hub.register('com.hocluc.test.events', sender);

    final dispatched = hub.dispatch(
      'com.hocluc.test.events',
      'board:pdf_text_fragments',
      {
        'page_number': 2,
        'fragments': [
          {'text': "A student's answer"},
        ],
      },
    );

    expect(dispatched, isTrue);
    expect(sentScripts, hasLength(1));
    const prefix = 'window.HocLuc && window.HocLuc.__dispatchHostEvent(';
    final payloadJson = sentScripts.single.substring(
      prefix.length,
      sentScripts.single.length - 2,
    );
    final event = jsonDecode(payloadJson) as Map<String, dynamic>;
    expect(event['event'], 'board:pdf_text_fragments');
    expect(event['payload']['page_number'], 2);

    hub.unregister('com.hocluc.test.events', sender);
    expect(
      hub.dispatch('com.hocluc.test.events', 'ignored', const {}),
      isFalse,
    );
  });

  test('a newly registered view is hydrated with the current glass preset', () {
    final hub = PluginEventHub.instance;
    const pluginId = 'com.hocluc.test.glass_preset_hydration';
    final scripts = <String>[];
    void lateView(String script) => scripts.add(script);

    // The preset may change while this plugin has no mounted WebView.
    HostBridge.instance.notifyGlassPreset(
      pluginId: pluginId,
      preset: GlassPreset.solid,
    );

    hub.register(pluginId, lateView);

    expect(scripts, hasLength(1));
    const prefix = 'window.HocLuc && window.HocLuc.__dispatchHostEvent(';
    final payloadJson = scripts.single.substring(
      prefix.length,
      scripts.single.length - 2,
    );
    final event = jsonDecode(payloadJson) as Map<String, dynamic>;
    expect(event['event'], 'GLASS_PRESET_CHANGE');
    expect(event['payload']['preset'], 'solid');

    hub.unregister(pluginId, lateView);
  });

  test(
    'a mounted view receives the host preset with an epoch dispatch time',
    () {
      final hub = PluginEventHub.instance;
      const pluginId = 'com.hocluc.test.initial_glass_preset';
      final scripts = <String>[];
      void view(String script) => scripts.add(script);

      HostBridge.instance.registerPluginView(
        pluginId: pluginId,
        preset: GlassPreset.frosted,
        sender: view,
      );

      expect(scripts, hasLength(1));
      const prefix = 'window.HocLuc && window.HocLuc.__dispatchHostEvent(';
      final payloadJson = scripts.single.substring(
        prefix.length,
        scripts.single.length - 2,
      );
      final event = jsonDecode(payloadJson) as Map<String, dynamic>;
      expect(event['payload']['preset'], 'frosted');
      final dispatchedAt = event['payload']['dispatched_at_epoch_ms'] as int;
      expect(dispatchedAt, greaterThan(1700000000000));

      hub.unregister(pluginId, view);
    },
  );

  test('disposing one view preserves synchronization for its sibling view', () {
    final hub = PluginEventHub.instance;
    const pluginId = 'com.hocluc.test.glass_preset_view_disposal';
    final disposedScripts = <String>[];
    final survivingScripts = <String>[];
    void disposedView(String script) => disposedScripts.add(script);
    void survivingView(String script) => survivingScripts.add(script);
    hub.register(pluginId, disposedView);
    hub.register(pluginId, survivingView);

    hub.unregister(pluginId, disposedView);
    HostBridge.instance.notifyGlassPreset(
      pluginId: pluginId,
      preset: GlassPreset.clear,
    );

    expect(disposedScripts, isEmpty);
    expect(survivingScripts, hasLength(1));
    expect(survivingScripts.single, contains('GLASS_PRESET_CHANGE'));

    hub.unregister(pluginId, survivingView);
  });
}
