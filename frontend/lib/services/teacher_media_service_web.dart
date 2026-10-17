import 'package:teaching_companion/utils/frontend_logger.dart';
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class TeacherMediaService extends ChangeNotifier {
  static final TeacherMediaService _instance = TeacherMediaService._internal();
  factory TeacherMediaService() => _instance;
  TeacherMediaService._internal();

  static const String viewType = 'teacher-webcam-preview-view';
  static bool _viewRegistered = false;

  web.MediaStream? _stream;
  web.HTMLVideoElement? _videoElement;
  web.AudioContext? _audioContext;
  Timer? _audioTimer;

  bool _isCameraActive = true;
  bool _isMicActive = true;
  bool _isInitialized = false;
  double _audioLevel = 0.0;
  String? _errorMessage;

  bool get isCameraActive => _isCameraActive;
  bool get isMicActive => _isMicActive;
  bool get supportsAudio => true;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => false;
  double get audioLevel => _audioLevel;
  String? get errorMessage => _errorMessage;

  List<String> get availableCameras => const ['Webcam HD (Web Browser)'];
  List<String> get availableMicrophones => const ['Microphone (Web Browser)'];
  List<dynamic> get cameras => const [];
  String? get selectedCamera => null;

  Future<void> switchCamera(String cameraName) async {}
  Future<void> switchMicrophone(String micLabel) async {}
  Future<void> selectCamera(String name) async {}
  Future<void> shutdown() async {
    _audioTimer?.cancel();
    if (_stream != null) {
      for (final track in _stream!.getTracks().toDart) {
        track.stop();
      }
    }
    _stream = null;
    _videoElement?.srcObject = null;
    _isInitialized = false;
    notifyListeners();
  }

  Future<void> initMedia() async {
    if (_isInitialized && _stream != null) return;
    try {
      _errorMessage = null;
      final constraints = web.MediaStreamConstraints(
        video: true.toJS,
        audio: true.toJS,
      );

      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      _stream = stream;

      _videoElement =
          web.document.createElement('video') as web.HTMLVideoElement;
      _videoElement!
        ..srcObject = stream
        ..autoplay = true
        ..playsInline = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'
        ..style.backgroundColor = '#12201a';

      if (!_viewRegistered) {
        ui.platformViewRegistry.registerViewFactory(
          viewType,
          (_) => _videoElement!,
        );
        _viewRegistered = true;
      }

      _setupAudioAnalyser(stream);

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      FrontendLogger.write('[TeacherMediaService] initMedia error: $e');
      _errorMessage = e.toString();
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _setupAudioAnalyser(web.MediaStream stream) {
    try {
      _audioContext = web.AudioContext();
      final source = _audioContext!.createMediaStreamSource(stream);
      final analyser = _audioContext!.createAnalyser();
      analyser.fftSize = 32;
      source.connect(analyser);

      _audioTimer?.cancel();
      _audioTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!_isMicActive) {
          if (_audioLevel != 0.0) {
            _audioLevel = 0.0;
            notifyListeners();
          }
          return;
        }

        final buffer = Uint8List(analyser.frequencyBinCount);
        analyser.getByteFrequencyData(buffer.toJS);
        int sum = 0;
        for (int i = 0; i < buffer.length; i++) {
          sum += buffer[i];
        }
        final avg = sum / buffer.length / 255.0;
        _audioLevel = (avg * 1.8).clamp(0.0, 1.0);
        notifyListeners();
      });
    } catch (err) {
      FrontendLogger.write(
        '[TeacherMediaService] setupAudioAnalyser err: $err',
      );
    }
  }

  Future<void> toggleCamera() async {
    _isCameraActive = !_isCameraActive;
    if (_stream != null) {
      final videoTracks = _stream!.getVideoTracks().toDart;
      for (final track in videoTracks) {
        track.enabled = _isCameraActive;
      }
    }
    notifyListeners();
  }

  Future<void> toggleMic() async {
    _isMicActive = !_isMicActive;
    if (_stream != null) {
      final audioTracks = _stream!.getAudioTracks().toDart;
      for (final track in audioTracks) {
        track.enabled = _isMicActive;
      }
    }
    if (!_isMicActive) {
      _audioLevel = 0.0;
    }
    notifyListeners();
  }

  Widget buildCameraPreview() {
    if (!_isCameraActive) {
      return Container(
        color: const Color(0xff0d1511),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, size: 36, color: Colors.white38),
              SizedBox(height: 6),
              Text(
                'Camera đã tắt',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    if (_stream != null) {
      return const HtmlElementView(viewType: viewType);
    }

    return Container(
      color: const Color(0xff12201a),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x33d4e8a6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x55d4e8a6), width: 1.5),
              ),
              child: const Center(
                child: Text(
                  'GV',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffd4e8a6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Đang kết nối Webcam…',
              style: TextStyle(fontSize: 10, color: Color(0xffa0b3a5)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioTimer?.cancel();
    if (_stream != null) {
      final tracks = _stream!.getTracks().toDart;
      for (final t in tracks) {
        t.stop();
      }
    }
    _audioContext?.close();
    super.dispose();
  }
}
