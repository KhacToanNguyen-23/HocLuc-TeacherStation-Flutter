import 'dart:async';
import 'dart:convert';

/// Routes host initiated events to the webview registered for a plugin.
/// The event payload is serialized as data and passed through the injected SDK.
class PluginEventHub {
  PluginEventHub._();

  static final PluginEventHub instance = PluginEventHub._();

  final Map<String, Set<void Function(String)>> _senders = {};
  final Map<String, StreamController<PluginHostMessage>> _messages = {};
  final Map<String, Map<String, dynamic>> _latestGlassPresetPayloads = {};

  Stream<PluginHostMessage> messagesFor(String pluginId) =>
      _messageController(pluginId).stream;

  void register(
    String pluginId,
    void Function(String) sender, {
    Map<String, dynamic>? initialGlassPresetPayload,
  }) {
    _senders.putIfAbsent(pluginId, () => <void Function(String)>{}).add(sender);
    if (initialGlassPresetPayload != null) {
      _latestGlassPresetPayloads[pluginId] = Map<String, dynamic>.from(
        initialGlassPresetPayload,
      );
    }

    final latestPreset = _latestGlassPresetPayloads[pluginId];
    if (latestPreset != null) {
      _sendTo(
        pluginId,
        sender,
        _hostEventScript('GLASS_PRESET_CHANGE', latestPreset),
      );
    }
  }

  void unregister(String pluginId, void Function(String) sender) {
    final senders = _senders[pluginId];
    if (senders == null) return;
    senders.remove(sender);
    if (senders.isEmpty) _senders.remove(pluginId);
  }

  bool dispatch(String pluginId, String event, Map<String, dynamic> payload) {
    if (event == 'GLASS_PRESET_CHANGE') {
      _latestGlassPresetPayloads[pluginId] = Map<String, dynamic>.from(payload);
    }
    final senders = _senders[pluginId];
    if (senders == null || senders.isEmpty) return false;
    final script = _hostEventScript(event, payload);
    var delivered = false;
    for (final sender in senders.toList(growable: false)) {
      try {
        delivered = _sendTo(pluginId, sender, script) || delivered;
      } catch (_) {
        // A view may be disposed between registration and this dispatch.
        unregister(pluginId, sender);
      }
    }
    return delivered;
  }

  String _hostEventScript(String event, Map<String, dynamic> payload) {
    final eventJson = jsonEncode({'event': event, 'payload': payload});
    return 'window.HocLuc && window.HocLuc.__dispatchHostEvent($eventJson);';
  }

  bool _sendTo(String pluginId, void Function(String) sender, String script) {
    try {
      sender(script);
      return true;
    } catch (_) {
      unregister(pluginId, sender);
      return false;
    }
  }

  void receiveFromPlugin({
    required String pluginId,
    required String action,
    required Map<String, dynamic> payload,
  }) {
    final controller = _messages[pluginId];
    if (controller?.hasListener != true) return;
    controller!.add(PluginHostMessage(action: action, payload: payload));
  }

  StreamController<PluginHostMessage> _messageController(String pluginId) {
    return _messages.putIfAbsent(pluginId, () {
      late final StreamController<PluginHostMessage> controller;
      controller = StreamController<PluginHostMessage>.broadcast(
        onCancel: () {
          if (!controller.hasListener &&
              identical(_messages[pluginId], controller)) {
            _messages.remove(pluginId);
          }
        },
      );
      return controller;
    });
  }
}

class PluginHostMessage {
  const PluginHostMessage({required this.action, required this.payload});

  final String action;
  final Map<String, dynamic> payload;
}
