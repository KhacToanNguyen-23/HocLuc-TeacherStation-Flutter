import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audio_bridge/audio_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'local_service.dart';

class AudioTranslationService extends ChangeNotifier {
  AudioTranslationService({
    required this.service,
    AudioBridge? bridge,
    this.manageRuntime = false,
  }) : bridge = bridge ?? AudioBridge();
  final LocalService service;
  final AudioBridge bridge;
  final bool manageRuntime;
  final String clientId = base64Url.encode(
    List<int>.generate(24, (_) => Random.secure().nextInt(256)),
  );
  bool _ownsRuntime = false;
  Future<Map<String, dynamic>>? _connectInFlight;
  List<Map<String, dynamic>> devices = [];
  String inputId = '', outputId = '', voice = 'af_heart', language = 'vi';
  String mode = 'unavailable',
      message = 'Chọn micro và thiết bị đầu ra.',
      vi = '',
      en = '';
  bool requested = false,
      muted = false,
      captureReady = false,
      supported = false,
      installed = false;
  double level = 0;
  bool isTeacherInput(Map<String, dynamic> device) =>
      device['input'] == true &&
      !RegExp(
        r'stereo mix|what u hear|cable output|voicemeeter|loopback',
        caseSensitive: false,
      ).hasMatch(device['name'] as String);
  int _generation = 0;
  int _nativeGeneration = -1;
  bool _disposed = false;
  StreamSubscription<Map<String, dynamic>>? _native;
  StreamSubscription<dynamic>? _socketEvents;
  WebSocketChannel? _socket;
  Completer<void>? _capture;
  Map<String, dynamic> metrics = {};

  static String normalizeLanguage(Object? value) =>
      value == 'English' || value == 'en' ? 'en' : 'vi';
  bool get canTranslate =>
      supported &&
      mode != 'file_preparing' &&
      mode != 'preview' &&
      inputId.isNotEmpty &&
      outputId.isNotEmpty &&
      language == 'en' &&
      !muted;
  String get statusLabel => switch (mode) {
    'original' => 'Đang phát giọng gốc',
    'preparing' => 'Đang chuẩn bị tiếng Anh',
    'english' => 'Đang phát bản dịch tiếng Anh',
    'muted' => 'Đã tắt micro',
    'file_preparing' => 'Đang xử lý WAV nghe thử',
    'preview' => 'Đang nghe thử tại máy',
    'error_original' => 'Đã quay về giọng gốc',
    _ => 'Âm thanh chưa sẵn sàng',
  };
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refreshDevices() async {
    try {
      devices = await bridge.devices();
      supported = true;
      if (!devices.any((d) => isTeacherInput(d) && d['id'] == inputId)) {
        inputId = '';
      }
      if (!devices.any((d) => d['input'] == false && d['id'] == outputId)) {
        outputId = '';
      }
      _native ??= bridge.events.listen(
        _nativeEvent,
        onError: (Object error) => _fail(error.toString(), deviceLost: true),
      );
    } catch (_) {
      supported = false;
      message = 'Luồng audio này cần bản Flutter Windows native.';
    }
    try {
      if (manageRuntime) await service.connect();
      final health = await service.request('audio/status');
      installed = health['installed'] == true;
    } catch (_) {
      installed = false;
    }
    _notify();
  }

  void restore(Map<String, dynamic> config) {
    final saved = config['audio'] is Map
        ? Map<String, dynamic>.from(config['audio'] as Map)
        : <String, dynamic>{};
    language = normalizeLanguage(saved['targetLanguage'] ?? config['language']);
    inputId = saved['inputDeviceId'] as String? ?? '';
    outputId = saved['outputDeviceId'] as String? ?? '';
    voice = saved['voiceId'] as String? ?? 'af_heart';
    if (!['af_heart', 'am_michael', 'af_bella'].contains(voice)) {
      voice = 'af_heart';
    }
    requested = false;
  }

  Map<String, dynamic> get preferences => {
    'schemaVersion': 2,
    'targetLanguage': language,
    'inputDeviceId': inputId,
    'outputDeviceId': outputId,
    'voiceId': voice,
    'denoiseRequested': false,
  };
  Future<void> selectLanguage(String value) async {
    language = normalizeLanguage(value);
    if (language != 'en') await setTranslation(false);
    _notify();
  }

  Future<void> selectDevice({String? input, String? output}) async {
    await stop();
    if (input != null) inputId = input;
    if (output != null) outputId = output;
    message = 'Thiết bị đã chọn. Bấm Phát giọng gốc để kiểm tra đường audio.';
    _notify();
  }

  void _nativeEvent(Map<String, dynamic> event) {
    if (_disposed) return;
    switch (event['type']) {
      case 'ready':
        captureReady = true;
        if (_capture != null && !_capture!.isCompleted) _capture!.complete();
        _notify();
      case 'level':
        level = (event['value'] as num?)?.toDouble() ?? 0;
        _notify();
      case 'pcm':
        if (event['generation'] == _nativeGeneration &&
            requested &&
            mode == 'english' &&
            !muted &&
            _socket != null) {
          _socket!.sink.add(event['samples'] as Uint8List);
        }
      case 'error':
        final error = event['message']?.toString() ?? 'Thiết bị audio đã ngắt.';
        if (_capture != null && !_capture!.isCompleted) {
          _capture!.completeError(StateError(error));
        }
        unawaited(_fail(error, deviceLost: true));
      case 'previewEnded':
        if (mode == 'preview') {
          mode = 'unavailable';
          message = 'Đã nghe thử bản dịch. Toggle phát tiếng Anh vẫn tắt.';
          _notify();
        }
    }
  }

  Future<void> startOriginal() async {
    final generation = _generation;
    if (!supported || inputId.isEmpty || outputId.isEmpty) {
      throw StateError('Chọn micro và đầu ra trước.');
    }
    if (captureReady) return;
    _capture = Completer<void>();
    final ready = _capture!.future.timeout(const Duration(seconds: 5));
    await bridge.start(inputId, outputId, muted: muted);
    await ready;
    if (_disposed || generation != _generation) return;
    await bridge.mute(muted);
    mode = muted
        ? 'muted'
        : requested
        ? 'preparing'
        : 'original';
    message =
        'Trong Meet, chọn capture endpoint tương ứng với đầu ra audio ảo này.';
    _notify();
  }

  Future<void> setTranslation(bool enabled) async {
    if (mode == 'preview' || mode == 'file_preparing') await stop();
    final generation = ++_generation;
    requested = false;
    if (captureReady) await bridge.mode(false);
    if (generation != _generation) return;
    await _closeSocket();
    if (generation != _generation) return;
    if (!enabled) {
      mode = muted
          ? 'muted'
          : captureReady
          ? 'original'
          : 'unavailable';
      _notify();
      return;
    }
    if (!canTranslate) {
      message = 'Chọn English, micro và thiết bị đầu ra trước khi bật dịch.';
      _notify();
      return;
    }
    requested = true;
    mode = 'preparing';
    message =
        'Đang nạp model local; giọng gốc còn phát cho đến khi tiếng Anh sẵn sàng.';
    _notify();
    try {
      await startOriginal();
      if (generation != _generation || !requested) return;
      mode = 'preparing';
      _notify();
      _connectInFlight = service.post(
        'audio/connect',
        data: {'voice': voice, 'language': 'en', 'clientId': clientId},
      );
      final session = await _connectInFlight!;
      _ownsRuntime = true;
      if (generation != _generation || !requested) return;
      final channel = WebSocketChannel.connect(
        Uri.parse(session['url'] as String),
      );
      _socket = channel;
      await channel.ready.timeout(const Duration(seconds: 10));
      if (generation != _generation) {
        await channel.sink.close();
        return;
      }
      _socketEvents = channel.stream.listen(
        (dynamic data) async {
          if (_disposed || generation != _generation || !requested) return;
          try {
            if (data is List<int>) {
              if (mode == 'english' && !muted) {
                await bridge.enqueue(Uint8List.fromList(data));
              }
            } else {
              final event = jsonDecode(data as String) as Map<String, dynamic>;
              if (event['type'] == 'ready') {
                _nativeGeneration = await bridge.mode(true);
                if (generation != _generation || !requested) {
                  return;
                }
                mode = 'english';
                message =
                    'Tiếng Anh đang phát ra thiết bị đã chọn. Kiểm tra micro trong Meet.';
              } else if (event['type'] == 'transcript') {
                vi = event['vi'] as String? ?? '';
                en = event['en'] as String? ?? '';
                metrics = Map<String, dynamic>.from(
                  event['metrics'] as Map? ?? {},
                );
              } else if (event['type'] == 'error') {
                await _fail(
                  event['message']?.toString() ?? 'Model không xử lý được.',
                );
              }
              _notify();
            }
          } catch (error) {
            if (generation == _generation) await _fail(error.toString());
          }
        },
        onError: (Object error) {
          if (generation == _generation) unawaited(_fail(error.toString()));
        },
        onDone: () {
          if (generation == _generation && requested) {
            unawaited(_fail('AI runtime đã ngắt.'));
          }
        },
      );
    } catch (error) {
      if (generation == _generation) await _fail(error.toString());
    }
  }

  Future<void> setMuted(bool value) async {
    final generation = ++_generation;
    final resume = requested && !value;
    muted = value;
    if (mode == 'preview' && value) await bridge.stop();
    if (captureReady) {
      await bridge.mute(value);
      await bridge.mode(false);
    }
    if (generation != _generation) return;
    if (value) await _closeSocket();
    if (generation != _generation) return;
    mode = value
        ? 'muted'
        : captureReady
        ? 'original'
        : 'unavailable';
    if (resume) await setTranslation(true);
    _notify();
  }

  Future<void> _fail(String reason, {bool deviceLost = false}) async {
    final generation = ++_generation;
    requested = false;
    if (deviceLost) captureReady = false;
    if (captureReady) {
      try {
        await bridge.mode(false);
      } catch (_) {
        captureReady = false;
      }
    }
    if (generation != _generation) return;
    await _closeSocket();
    if (generation != _generation) return;
    mode = muted
        ? 'muted'
        : captureReady
        ? 'error_original'
        : 'unavailable';
    message = reason;
    _notify();
  }

  Future<void> _closeSocket() async {
    final subscription = _socketEvents;
    final socket = _socket;
    _socketEvents = null;
    _socket = null;
    await subscription?.cancel();
    if (socket != null) {
      try {
        await socket.sink.close().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    final filePreparing = mode == 'file_preparing';
    ++_generation;
    requested = false;
    try {
      await bridge.stop();
    } catch (_) {}
    await _closeSocket();
    if (filePreparing && manageRuntime) {
      try {
        await service.post('audio/stop', data: {'clientId': clientId});
      } catch (_) {}
    }
    captureReady = false;
    mode = muted ? 'muted' : 'unavailable';
    level = 0;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_shutdown());
    unawaited(_native?.cancel());
    super.dispose();
  }

  Future<void> _shutdown() async {
    await stop();
    if (manageRuntime) {
      if (_connectInFlight != null) {
        try {
          await _connectInFlight!.timeout(const Duration(seconds: 15));
        } catch (_) {}
      }
      if (_ownsRuntime || _connectInFlight != null) {
        try {
          await service.post('audio/stop', data: {'clientId': clientId});
        } catch (_) {}
      }
      service.dispose();
    }
  }

  Future<void> previewFile(Uint8List wav, String monitor) async {
    if (requested || captureReady || muted) {
      throw StateError('Dừng audio trực tiếp trước khi nghe thử WAV.');
    }
    if (wav.length > 4000000) throw StateError('WAV tối đa 4 MB và 15 giây.');
    final generation = ++_generation;
    mode = 'file_preparing';
    message = 'Đang nhận dạng, dịch và tạo giọng từ WAV; chưa phát vào lớp.';
    _notify();
    _ownsRuntime = true;
    try {
      await service.connect();
      if (_disposed || generation != _generation) return;
      final response = await service.client
          .post(
            Uri.parse(
              '${service.base}/api/audio/file?voice=$voice&clientId=$clientId',
            ),
            headers: {
              'X-Companion-Token': service.companionToken!,
              'Content-Type': 'audio/wav',
            },
            body: wav,
          )
          .timeout(const Duration(seconds: 180));
      if (_disposed || generation != _generation) return;
      final result =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw StateError(
          result['error']?.toString() ?? 'Không xử lý được WAV.',
        );
      }
      vi = result['vi'] as String? ?? '';
      en = result['en'] as String? ?? '';
      metrics = Map<String, dynamic>.from(result['metrics'] as Map? ?? {});
      final samples = base64Decode(result['samples'] as String);
      if (samples.isEmpty) {
        throw StateError('Không nhận được lời nói trong WAV.');
      }
      mode = 'preview';
      message = 'Bản dịch chỉ phát tại thiết bị nghe thử đã chọn.';
      _notify();
      await bridge.preview(monitor, samples);
    } catch (error) {
      if (!_disposed && generation == _generation) {
        await _fail(error.toString());
      }
    }
  }
}
