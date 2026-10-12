import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'virtual_media_bridge.dart';

enum MediaDeviceKind {
  videoInput,
  audioInput,
}

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

  bool _isCameraActive = false;
  bool _isMicActive = false;
  bool _isCameraMuted = false;
  bool _isMicMuted = false;

  double _currentAudioLevel = 0.0;
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();

  // Getters
  List<MediaDeviceInfo> get cameras => List.unmodifiable(_cameras);
  List<MediaDeviceInfo> get microphones => List.unmodifiable(_microphones);
  MediaDeviceInfo? get selectedCamera => _selectedCamera;
  MediaDeviceInfo? get selectedMicrophone => _selectedMicrophone;

  bool get isCameraActive => _isCameraActive;
  bool get isMicActive => _isMicActive;
  bool get isCameraMuted => _isCameraMuted;
  bool get isMicMuted => _isMicMuted;
  double get currentAudioLevel => _currentAudioLevel;

  Stream<double> get audioLevelStream => _audioLevelController.stream;

  /// Initialize hardware media devices. Accepts mock parameters for testing.
  Future<void> init({
    List<MediaDeviceInfo>? mockCameras,
    List<MediaDeviceInfo>? mockMicrophones,
  }) async {
    _cameras.clear();
    _microphones.clear();

    if (mockCameras != null) {
      _cameras.addAll(mockCameras);
    } else {
      // Default fallback / discovery list on Windows
      _cameras.add(
        const MediaDeviceInfo(
          id: 'default_camera',
          label: 'Camera Mặc định',
          kind: MediaDeviceKind.videoInput,
        ),
      );
    }

    if (mockMicrophones != null) {
      _microphones.addAll(mockMicrophones);
    } else {
      _microphones.add(
        const MediaDeviceInfo(
          id: 'default_mic',
          label: 'Microphone Mặc định',
          kind: MediaDeviceKind.audioInput,
        ),
      );
    }

    if (_cameras.isNotEmpty) {
      _selectedCamera = _cameras.first;
      _isCameraActive = true;
    }
    if (_microphones.isNotEmpty) {
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
    // Normalize against full scale 32767
    final normalized = (rms / 32767.0).clamp(0.0, 1.0);
    return normalized;
  }

  /// Ingest raw PCM samples and publish updated RMS level to stream
  void feedAudioPcm(Uint8List pcm16Bytes) {
    if (_isMicMuted || !_isMicActive) {
      _currentAudioLevel = 0.0;
      _audioLevelController.add(0.0);
      return;
    }

    final level = calculateRmsLevel(pcm16Bytes);
    _currentAudioLevel = level;
    _audioLevelController.add(level);

    if (VirtualMediaBridge().isStreaming) {
      VirtualMediaBridge().sendAudioChunk(pcm16Bytes);
    }
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

  @visibleForTesting
  void resetForTesting() {
    _cameras.clear();
    _microphones.clear();
    _selectedCamera = null;
    _selectedMicrophone = null;
    _isCameraActive = false;
    _isMicActive = false;
    _isCameraMuted = false;
    _isMicMuted = false;
    _currentAudioLevel = 0.0;
  }

  @override
  void dispose() {
    _audioLevelController.close();
    super.dispose();
  }
}
