import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemMicrophoneDevice {
  const SystemMicrophoneDevice(this.id, this.name);
  final String id;
  final String name;
}

/// Controls the Windows capture endpoint, including audio captured by Meet.
/// Merely opening/closing the app never changes the user's mute or volume.
class SystemMicrophoneService extends ChangeNotifier {
  static final _instance = SystemMicrophoneService._(
    const MethodChannel('hocluc/audio'),
  );
  factory SystemMicrophoneService() => _instance;
  SystemMicrophoneService._(this._channel);
  @visibleForTesting
  SystemMicrophoneService.forTesting(this._channel);
  final MethodChannel _channel;
  Future<void>? _pending;
  List<SystemMicrophoneDevice> devices = const [];
  String selectedId = ''; // Follow Windows' default input, without changing it.
  String deviceName = '';
  String? errorMessage;
  bool ready = false;
  bool muted = false;
  double volume = 0;
  double level = 0;
  bool get busy => _pending != null;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _perform(Future<void> Function() operation) {
    if (_pending != null) return _pending!;
    final future = Future<void>.sync(operation)
        .catchError((Object error) {
          ready = false;
          level = 0;
          errorMessage = 'Không điều khiển được microphone Windows: $error';
        })
        .whenComplete(() {
          _pending = null;
          notifyListeners();
        });
    _pending = future;
    notifyListeners();
    return future;
  }

  void _accept(Map<dynamic, dynamic>? state) {
    if (state == null || state['muted'] is! bool || state['volume'] is! num) {
      throw StateError('Windows không trả về trạng thái microphone.');
    }
    muted = state['muted'] as bool;
    volume = (state['volume'] as num).toDouble().clamp(0, 1);
    level = muted ? 0 : ((state['level'] as num?)?.toDouble() ?? 0).clamp(0, 1);
    deviceName = state['name'] as String? ?? 'Microphone';
    ready = true;
    errorMessage = null;
  }

  Future<void> refresh({bool discover = false}) {
    if (!supported) return Future.value();
    return _perform(() async {
      if (discover || devices.isEmpty) {
        final list = await _channel.invokeListMethod<dynamic>(
          'systemMicrophoneDevices',
        );
        devices = (list ?? []).map((dynamic item) {
          final device = item as Map;
          return SystemMicrophoneDevice(
            device['id'] as String,
            device['name'] as String,
          );
        }).toList();
      }
      _accept(
        await _channel.invokeMapMethod<dynamic, dynamic>(
          'systemMicrophoneState',
          {'id': selectedId},
        ),
      );
    });
  }

  Future<void> selectDevice(String id) async {
    if (_pending != null) await _pending;
    await _perform(() async {
      final state = await _channel.invokeMapMethod<dynamic, dynamic>(
        'systemMicrophoneState',
        {'id': id},
      );
      _accept(state);
      selectedId = id;
    });
  }

  Future<void> toggleMute() async {
    if (_pending != null) await _pending;
    if (!ready) await refresh(discover: true);
    if (!ready) return;
    await _perform(() async {
      // Read immediately before toggling: hardware/Windows may have changed it.
      final state = await _channel.invokeMapMethod<dynamic, dynamic>(
        'systemMicrophoneState',
        {'id': selectedId},
      );
      if (state?['muted'] is! bool) {
        throw StateError('Không đọc được trạng thái mute.');
      }
      _accept(
        await _channel.invokeMapMethod<dynamic, dynamic>(
          'setSystemMicrophoneMute',
          {'id': selectedId, 'muted': !(state!['muted'] as bool)},
        ),
      );
    });
  }

  Future<void> setVolume(double value) async {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(value, 'volume');
    }
    if (_pending != null) await _pending;
    if (!ready) return;
    await _perform(() async {
      _accept(
        await _channel.invokeMapMethod<dynamic, dynamic>(
          'setSystemMicrophoneVolume',
          {'id': selectedId, 'volume': value},
        ),
      );
    });
  }
}
