import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:wgc_broadcaster/wgc_broadcaster.dart';

enum CameraCaptureArea { board, app }

/// Captures the presentation or app content, never other desktop windows.
class CameraBroadcastService extends ChangeNotifier {
  static final CameraBroadcastService _instance = CameraBroadcastService._();
  factory CameraBroadcastService() => _instance;
  CameraBroadcastService._();
  static const width = 1280;
  static const height = 720;
  GlobalKey? _source;
  GlobalKey? _appSource;
  CameraCaptureArea _captureArea = CameraCaptureArea.app;
  int _areaRevision = 0;
  CameraCaptureArea get captureArea => _captureArea;
  GlobalKey? get _selectedSource =>
      _captureArea == CameraCaptureArea.app ? _appSource : _source;
  @visibleForTesting
  GlobalKey? get captureSourceForTesting => _selectedSource;
  void setCaptureArea(CameraCaptureArea area) {
    if (_captureArea == area) return;
    _captureArea = area;
    _areaRevision++;
    notifyListeners();
  }

  void attachApp(GlobalKey key) {
    _appSource = key;
  }

  void detachApp(GlobalKey key) {
    if (_appSource == key) {
      _appSource = null;
      unawaited(stop());
    }
  }

  Timer? _timer;
  bool _capturing = false;
  bool _running = false;
  bool _starting = false;
  int _generation = 0;
  String? _error;
  ui.Image? _preview;
  DateTime? _receiverSeen;
  int _frames = 0;
  final Stopwatch _clock = Stopwatch();
  bool get isBroadcasting => _running;
  bool get isStarting => _starting;
  String? get errorMessage => _error;
  ui.Image? get preview => _preview;
  double get fps => _clock.elapsedMilliseconds == 0
      ? 0
      : _frames * 1000 / _clock.elapsedMilliseconds;
  bool get receiverConnected =>
      _receiverSeen != null &&
      DateTime.now().difference(_receiverSeen!).inSeconds < 2;
  void attach(GlobalKey key) {
    _source = key;
  }

  void detach(GlobalKey key) {
    if (_source == key) {
      _source = null;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_source == null) {
          unawaited(stop());
        }
      });
    }
  }

  Future<void> start() async {
    if (_running || _starting) return;
    _starting = true;
    _error = null;
    final generation = ++_generation;
    notifyListeners();
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
        throw StateError('Camera ảo hiện chỉ hỗ trợ Windows.');
      }
      if (_source?.currentContext == null) {
        throw StateError('Mở bảng dạy trước khi phát camera ảo.');
      }
      if (_selectedSource?.currentContext == null) {
        throw StateError('Khung ứng dụng chưa sẵn sàng.');
      }
      if (!await WgcBroadcaster.startBroadcast()) {
        throw StateError('Không khởi động được camera ảo.');
      }
      if (generation != _generation) {
        await WgcBroadcaster.stopBroadcast();
        return;
      }
      _running = true;
      _frames = 0;
      _receiverSeen = null;
      _clock
        ..reset()
        ..start();
      await _tick(generation);
    } catch (error) {
      _error = '$error';
      await stop();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> _tick(int generation) async {
    final elapsed = Stopwatch()..start();
    await _capture(generation);
    if (_running && generation == _generation) {
      _timer = Timer(
        Duration(milliseconds: (33 - elapsed.elapsedMilliseconds).clamp(0, 33)),
        () => unawaited(_tick(generation)),
      );
    }
  }

  Future<void> _capture(int generation) async {
    if (_capturing || !_running || generation != _generation) return;
    _capturing = true;
    ui.Image? source;
    ui.Image? frame;
    try {
      await SchedulerBinding.instance.endOfFrame;
      if (!_running || generation != _generation) return;
      final areaRevision = _areaRevision;
      final boundary =
          _selectedSource?.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || !boundary.attached || boundary.size.isEmpty) {
        throw StateError('Khung trình bày không còn khả dụng.');
      }
      final ratio = (width / boundary.size.width).clamp(
        0.0,
        height / boundary.size.height,
      );
      source = await boundary.toImage(pixelRatio: ratio);
      if (source.width == width && source.height == height) {
        // Avoid a second GPU render/readback for the normal 16:9 stage.
        frame = source;
        source = null;
      } else {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xff14221d), ui.BlendMode.src);
        final fitted = applyBoxFit(
          BoxFit.contain,
          ui.Size(source.width.toDouble(), source.height.toDouble()),
          const ui.Size(1280, 720),
        );
        canvas.drawImageRect(
          source,
          ui.Rect.fromLTWH(
            0,
            0,
            source.width.toDouble(),
            source.height.toDouble(),
          ),
          Alignment.center.inscribe(
            fitted.destination,
            const ui.Rect.fromLTWH(0, 0, 1280, 720),
          ),
          ui.Paint()..filterQuality = ui.FilterQuality.low,
        );
        final picture = recorder.endRecording();
        try {
          frame = await picture.toImage(width, height);
        } finally {
          picture.dispose();
        }
      }
      final bytes = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!_running ||
          generation != _generation ||
          areaRevision != _areaRevision ||
          bytes == null) {
        return;
      }
      final consumed = await WgcBroadcaster.sendFrame(
        width,
        height,
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      if (generation != _generation || !_running) return;
      if (consumed) _receiverSeen = DateTime.now();
      _frames++;
      final old = _preview;
      _preview = frame;
      frame = null;
      notifyListeners();
      if (old != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    } catch (error) {
      if (generation == _generation) {
        _error = 'Camera ảo: $error';
        await stop();
      }
    } finally {
      source?.dispose();
      frame?.dispose();
      _capturing = false;
    }
  }

  Future<void> stop() async {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    _running = false;
    _receiverSeen = null;
    _clock.stop();
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        await WgcBroadcaster.stopBroadcast();
      }
    } finally {
      final old = _preview;
      _preview = null;
      if (old != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      notifyListeners();
    }
  }
}
