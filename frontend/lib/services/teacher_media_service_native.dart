import 'dart:async';
import 'package:camera/camera.dart';
import 'package:camera/camera.dart' as cam_lib;
import 'package:flutter/material.dart';
import 'media_device_service.dart';

/// Manages physical webcam & microphone hardware integration.
/// Combines CameraController / virtual output pipeline with MediaDeviceService audio metering.
class TeacherMediaService extends ChangeNotifier {
  static final TeacherMediaService _instance = TeacherMediaService._internal();
  factory TeacherMediaService() => _instance;
  TeacherMediaService._internal() {
    _deviceService.addListener(_onDeviceServiceChanged);
  }

  final MediaDeviceService _deviceService = MediaDeviceService();
  CameraController? _controller;
  Future<void>? _pending;
  List<CameraDescription> _cameras = [];
  String? _selectedCamera;
  String? _errorMessage;
  bool _cameraEnabled = true;
  bool _initialized = false;

  void _onDeviceServiceChanged() {
    notifyListeners();
  }

  MediaDeviceService get deviceService => _deviceService;

  bool get isCameraActive =>
      _cameraEnabled && (_controller?.value.isInitialized ?? false);

  bool get isMicActive =>
      !_deviceService.isMicMuted &&
      (_deviceService.isMicActive || !_deviceService.isInitialized);

  bool get supportsAudio => true;

  bool get isInitialized => _initialized || _deviceService.isInitialized;

  bool get isInitializing => _pending != null;

  double get audioLevel => _deviceService.currentAudioLevel;

  String? get errorMessage => _errorMessage;

  List<CameraDescription> get cameras => List.unmodifiable(_cameras);

  String? get selectedCamera => _selectedCamera;

  List<String> get availableCameras =>
      _cameras.isNotEmpty
          ? _cameras.map((c) => c.name).toList()
          : _deviceService.cameras.map((c) => c.label).toList();

  List<String> get availableMicrophones =>
      _deviceService.microphones.map((m) => m.label).toList();

  Future<void> initMedia() {
    if (_pending != null) return _pending!.then((_) => initMedia());
    if (isCameraActive && _deviceService.isInitialized) return Future.value();
    return _run(_initialize);
  }

  Future<void> _run(Future<void> Function() operation) {
    final future = operation();
    _pending = future;
    notifyListeners();
    return future.whenComplete(() {
      if (identical(_pending, future)) {
        _pending = null;
      }
      notifyListeners();
    });
  }

  Future<void> _initialize() async {
    _errorMessage = null;

    // Initialize audio device & level stream
    try {
      if (!_deviceService.isInitialized) {
        await _deviceService.init();
      }
    } catch (_) {}

    // Initialize camera device
    try {
      final allCameras = await cam_lib.availableCameras();
      _cameras = allCameras.where((camera) {
        final name = camera.name.toLowerCase();
        return !name.contains('unity') &&
            !name.contains('virtual') &&
            !name.contains('obs');
      }).toList();

      if (_cameras.isNotEmpty) {
        final camera = _cameras.firstWhere(
          (c) => c.name == _selectedCamera,
          orElse: () => _cameras.first,
        );
        _selectedCamera = camera.name;
        await _releaseCamera();
        final controller = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        _controller = controller;
        controller.addListener(_onCameraChanged);
        await controller.initialize();
        _initialized = true;
      } else {
        _initialized = true;
      }
    } catch (error) {
      _errorMessage = 'Không mở được webcam: $error';
      await _releaseCamera();
      _initialized = true;
    }
    notifyListeners();
  }

  void _onCameraChanged() {
    final value = _controller?.value;
    if (value?.hasError ?? false) {
      _errorMessage = value!.errorDescription ?? 'Webcam đã ngắt kết nối.';
      _initialized = false;
      _cameraEnabled = false;
      unawaited(_releaseCamera());
      notifyListeners();
    }
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onCameraChanged);
    await controller?.dispose();
  }

  Future<void> selectCamera(String name) async {
    if (_pending != null) await _pending;
    await _run(() async {
      await _releaseCamera();
      _selectedCamera = name;
      _cameraEnabled = true;
      await _initialize();
    });
  }

  Future<void> toggleCamera() async {
    if (_pending != null) return;
    await _run(() async {
      if (isCameraActive) {
        _cameraEnabled = false;
        await _releaseCamera();
      } else {
        _cameraEnabled = true;
        await _initialize();
      }
    });
  }

  Future<void> toggleMic() async {
    _deviceService.toggleMicrophoneMute();
    notifyListeners();
  }

  Future<void> switchCamera(String cameraName) async {
    await selectCamera(cameraName);
  }

  Future<void> switchMicrophone(String micLabel) async {
    _deviceService.switchMicrophone(micLabel);
    notifyListeners();
  }

  Future<void> shutdown() async {
    if (_pending != null) await _pending;
    await _run(() async {
      await _releaseCamera();
      _initialized = false;
      _cameraEnabled = true;
    });
  }

  Widget buildCameraPreview() {
    final controller = _controller;
    if (isCameraActive && controller != null && controller.value.isInitialized) {
      final size = controller.value.previewSize ?? const Size(640, 480);
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CameraPreview(controller),
          ),
        ),
      );
    }
    return ColoredBox(
      color: const Color(0xff12201a),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _errorMessage ??
                (isInitializing ? 'Đang mở webcam…' : 'Camera đã tắt'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
