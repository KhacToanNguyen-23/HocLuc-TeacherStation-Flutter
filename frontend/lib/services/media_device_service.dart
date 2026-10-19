import 'package:teaching_companion/utils/frontend_logger.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_windows/camera_windows.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

enum MediaDeviceKind { videoInput, audioInput }

class MediaDeviceInfo {
  const MediaDeviceInfo({
    required this.id,
    required this.label,
    required this.kind,
  });

  final String id;
  final String label;
  final MediaDeviceKind kind;

  @override
  String toString() => 'MediaDeviceInfo($id, $label, $kind)';
}

/// Central service for detecting and controlling physical Webcams & Microphones,
/// streaming audio PCM amplitude levels, and managing mute states.
class MediaDeviceService extends ChangeNotifier {
  static final MediaDeviceService _instance = MediaDeviceService._internal();
  factory MediaDeviceService() => _instance;
  MediaDeviceService._internal();

  final List<MediaDeviceInfo> _cameras = [];
  final List<MediaDeviceInfo> _microphones = [];

  MediaDeviceInfo? _selectedCamera;
  MediaDeviceInfo? _selectedMicrophone;

  int? _activeCameraId;
  AudioRecorder? _audioRecorder;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  bool _isCameraActive = false;
  bool _isMicActive = false;
  bool _isCameraMuted = false;
  bool _isMicMuted = false;
  bool _isInitialized = false;

  double _currentAudioLevel = 0.0;
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();

  // Getters
  List<MediaDeviceInfo> get cameras => List.unmodifiable(_cameras);
  List<MediaDeviceInfo> get microphones => List.unmodifiable(_microphones);
  MediaDeviceInfo? get selectedCamera => _selectedCamera;
  MediaDeviceInfo? get selectedMicrophone => _selectedMicrophone;
  int? get activeCameraId => _activeCameraId;

  bool get isCameraActive => _isCameraActive;
  bool get isMicActive => _isMicActive;
  bool get isCameraMuted => _isCameraMuted;
  bool get isMicMuted => _isMicMuted;
  bool get isInitialized => _isInitialized;
  double get currentAudioLevel => _currentAudioLevel;

  Stream<double> get audioLevelStream => _audioLevelController.stream;

  /// Initialize hardware media devices. Accepts mock parameters for testing.
  Future<void> init({
    bool initializeCamera = true,
    List<MediaDeviceInfo>? mockCameras,
    List<MediaDeviceInfo>? mockMicrophones,
  }) async {
    _cameras.clear();
    _microphones.clear();

    if (mockCameras != null || mockMicrophones != null) {
      // Testing / Mock mode
      if (mockCameras != null) _cameras.addAll(mockCameras);
      if (mockMicrophones != null) _microphones.addAll(mockMicrophones);

      if (_cameras.isNotEmpty) {
        _selectedCamera = _cameras.first;
        _isCameraActive = true;
      }
      if (_microphones.isNotEmpty) {
        _selectedMicrophone = _microphones.first;
        _isMicActive = true;
      }
      _isInitialized = true;
      notifyListeners();
      return;
    }

    // Real Hardware Detection on Windows
    await _initPhysicalHardware(initializeCamera: initializeCamera);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _initPhysicalHardware({required bool initializeCamera}) async {
    // Register Windows Camera platform plugin if running on Windows desktop
    if (!kIsWeb && Platform.isWindows) {
      try {
        CameraWindows.registerWith();
      } catch (e) {
        FrontendLogger.write('[MediaDeviceService] CameraWindows register: $e');
      }
    }

    // 1. Physical Webcam Detection & Initialization
    try {
      final available = await CameraPlatform.instance.availableCameras();
      if (available.isNotEmpty) {
        _cameras.clear();
        for (final cam in available) {
          _cameras.add(
            MediaDeviceInfo(
              id: cam.name,
              label: cam.name,
              kind: MediaDeviceKind.videoInput,
            ),
          );
        }
        _selectedCamera = _cameras.first;
        // The lobby owns its webcam through TeacherMediaService. It only needs
        // device discovery and microphone capture from this service.
        if (initializeCamera) {
          final firstCam = available.first;
          final id = await CameraPlatform.instance.createCameraWithSettings(
            firstCam,
            const MediaSettings(resolutionPreset: ResolutionPreset.medium),
          );
          await CameraPlatform.instance.initializeCamera(id);
          _activeCameraId = id;
          _isCameraActive = true;
        }
        notifyListeners();
      }
    } catch (e) {
      FrontendLogger.write(
        '[MediaDeviceService] Physical Camera init error: $e',
      );
    }

    // 2. Physical Microphone Detection & Audio Recording
    try {
      final recorder = _audioRecorder ??= AudioRecorder();
      if (await recorder.hasPermission()) {
        final devices = await recorder.listInputDevices();
        if (devices.isNotEmpty) {
          _microphones.clear();
          for (final mic in devices) {
            _microphones.add(
              MediaDeviceInfo(
                id: mic.id,
                label: mic.label,
                kind: MediaDeviceKind.audioInput,
              ),
            );
          }
          _selectedMicrophone = _microphones.first;
        }

        // Listen to live microphone amplitude (RMS dBFS)
        _amplitudeSubscription?.cancel();
        _amplitudeSubscription = recorder
            .onAmplitudeChanged(const Duration(milliseconds: 60))
            .listen((amp) {
              if (_isMicMuted || !_isMicActive) return;
              // amp.current ranges between -160 dBFS to 0 dBFS. Human voice is usually -50 to -5.
              final normalized = ((amp.current + 45.0) / 45.0).clamp(0.0, 1.0);
              simulateAudioLevel(normalized);
            });

        // Start stream to capture microphone input
        final stream = await recorder.startStream(
          const RecordConfig(encoder: AudioEncoder.pcm16bits),
        );
        stream.listen((bytes) {
          feedAudioPcm(Uint8List.fromList(bytes));
        });
        _isMicActive = true;
      }
    } catch (e) {
      FrontendLogger.write('[MediaDeviceService] Physical Mic init error: $e');
    }

    // Fallbacks if hardware detection returned empty
    if (_cameras.isEmpty) {
      _cameras.add(
        const MediaDeviceInfo(
          id: 'default_camera',
          label: 'Camera Mặc định',
          kind: MediaDeviceKind.videoInput,
        ),
      );
      _selectedCamera = _cameras.first;
      _isCameraActive = true;
    }
    if (_microphones.isEmpty) {
      _microphones.add(
        const MediaDeviceInfo(
          id: 'default_mic',
          label: 'Microphone Mặc định',
          kind: MediaDeviceKind.audioInput,
        ),
      );
      _selectedMicrophone = _microphones.first;
      _isMicActive = true;
    }

    notifyListeners();
  }

  void selectCamera(String id) {
    final found = _cameras.firstWhere(
      (c) => c.id == id,
      orElse: () => _selectedCamera ?? _cameras.first,
    );
    _selectedCamera = found;
    _isCameraActive = true;
    notifyListeners();
  }

  void selectMicrophone(String id) {
    final found = _microphones.firstWhere(
      (m) => m.id == id,
      orElse: () => _selectedMicrophone ?? _microphones.first,
    );
    _selectedMicrophone = found;
    _isMicActive = true;
    notifyListeners();
  }

  void switchMicrophone(String micLabel) {
    final found = _microphones.firstWhere(
      (m) => m.label == micLabel || m.id == micLabel,
      orElse: () => _microphones.isNotEmpty
          ? _microphones.first
          : const MediaDeviceInfo(
              id: 'default_mic',
              label: 'Microphone Mặc định',
              kind: MediaDeviceKind.audioInput,
            ),
    );
    _selectedMicrophone = found;
    _isMicActive = true;
    notifyListeners();
  }

  void toggleCameraMute() {
    _isCameraMuted = !_isCameraMuted;
    notifyListeners();
  }

  void toggleMicrophoneMute() {
    _isMicMuted = !_isMicMuted;
    if (_isMicMuted) {
      _currentAudioLevel = 0.0;
      _audioLevelController.add(0.0);
    }
    notifyListeners();
  }

  void setCameraMuted(bool muted) {
    if (_isCameraMuted != muted) {
      _isCameraMuted = muted;
      notifyListeners();
    }
  }

  void setMicrophoneMuted(bool muted) {
    if (_isMicMuted != muted) {
      _isMicMuted = muted;
      if (_isMicMuted) {
        _currentAudioLevel = 0.0;
        _audioLevelController.add(0.0);
      }
      notifyListeners();
    }
  }

  Future<void> switchCamera(String cameraName) async {
    final target = _cameras.firstWhere(
      (c) => c.label == cameraName || c.id == cameraName,
      orElse: () => _cameras.isNotEmpty
          ? _cameras.first
          : const MediaDeviceInfo(
              id: 'default',
              label: 'Default',
              kind: MediaDeviceKind.videoInput,
            ),
    );
    _selectedCamera = target;

    if (!kIsWeb && Platform.isWindows && _activeCameraId != null) {
      try {
        await CameraPlatform.instance.dispose(_activeCameraId!);
        _activeCameraId = null;
        final available = await CameraPlatform.instance.availableCameras();
        final match = available.firstWhere(
          (c) => c.name == target.id,
          orElse: () => available.first,
        );
        final id = await CameraPlatform.instance.createCameraWithSettings(
          match,
          const MediaSettings(resolutionPreset: ResolutionPreset.medium),
        );
        await CameraPlatform.instance.initializeCamera(id);
        _activeCameraId = id;
        _isCameraActive = true;
      } catch (e) {
        FrontendLogger.write('[MediaDeviceService] switchCamera error: $e');
      }
    }
    notifyListeners();
  }

  /// Calculates normalized [0.0, 1.0] RMS volume level from 16-bit PCM little-endian byte array
  static double calculateRmsLevel(Uint8List pcm16Bytes) {
    if (pcm16Bytes.length < 2) return 0.0;

    final sampleCount = pcm16Bytes.length ~/ 2;
    double sumSquares = 0.0;
    final byteData = ByteData.sublistView(pcm16Bytes);

    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      sumSquares += sample * sample;
    }

    final rms = math.sqrt(sumSquares / sampleCount);
    if (rms < 5.0) return 0.0;

    // Expand dynamic range so normal voice scales naturally to 20-75% on VU meter
    final linear = (rms / 32767.0).clamp(0.0, 1.0);
    final boosted = math.pow(linear, 0.45).toDouble().clamp(0.0, 1.0);
    return boosted;
  }

  /// Ingest raw PCM samples and publish updated RMS level to stream
  void feedAudioPcm(Uint8List pcm16Bytes) {
    if (_isMicMuted || !_isMicActive) {
      _currentAudioLevel = 0.0;
      _audioLevelController.add(0.0);
      notifyListeners();
      return;
    }

    final level = calculateRmsLevel(pcm16Bytes);
    _currentAudioLevel = level;
    _audioLevelController.add(level);
    notifyListeners();
  }

  /// Simulate audio amplitude level for tests and synthetic demonstrations
  void simulateAudioLevel(double level) {
    if (_isMicMuted || !_isMicActive) {
      _currentAudioLevel = 0.0;
      _audioLevelController.add(0.0);
      return;
    }

    _currentAudioLevel = level.clamp(0.0, 1.0);
    _audioLevelController.add(_currentAudioLevel);
    notifyListeners();
  }

  /// Builds the visual preview widget for the active camera
  Widget buildCameraWidget() {
    if (_isCameraMuted) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, size: 40, color: Colors.white38),
              SizedBox(height: 8),
              Text(
                'Camera đã tắt',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeCameraId != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CameraPlatform.instance.buildPreview(_activeCameraId!),
          ),
        ),
      );
    }

    // Default placeholder if hardware webcam is initializing or in headless tests
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0x33d4e8a6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x55d4e8a6), width: 1.5),
            ),
            child: const Center(
              child: Text(
                'GV',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffd4e8a6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Giáo viên giảng dạy (Live)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xffa0b3a5),
            ),
          ),
        ],
      ),
    );
  }

  @visibleForTesting
  void resetForTesting() {
    _cameras.clear();
    _microphones.clear();
    _selectedCamera = null;
    _selectedMicrophone = null;
    _activeCameraId = null;
    _amplitudeSubscription?.cancel();
    final rec = _audioRecorder;
    _audioRecorder = null;
    rec?.dispose().catchError((_) {});
    _isCameraActive = false;
    _isMicActive = false;
    _isCameraMuted = false;
    _isMicMuted = false;
    _isInitialized = false;
    _currentAudioLevel = 0.0;
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    final rec = _audioRecorder;
    _audioRecorder = null;
    rec?.dispose().catchError((_) {});
    if (_activeCameraId != null) {
      try {
        CameraPlatform.instance.dispose(_activeCameraId!);
      } catch (_) {}
    }
    _audioLevelController.close();
    super.dispose();
  }
}
