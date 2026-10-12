import 'package:flutter/material.dart';
import 'media_device_service.dart';

class TeacherMediaService extends ChangeNotifier {
  static final TeacherMediaService _instance = TeacherMediaService._internal();
  factory TeacherMediaService() => _instance;
  TeacherMediaService._internal() {
    _deviceService.addListener(_onDeviceServiceChanged);
  }

  final MediaDeviceService _deviceService = MediaDeviceService();
  bool _isInitialized = false;

  void _onDeviceServiceChanged() {
    notifyListeners();
  }

  bool get isCameraActive =>
      _deviceService.isCameraActive && !_deviceService.isCameraMuted;

  bool get isMicActive =>
      _deviceService.isMicActive && !_deviceService.isMicMuted;

  bool get isInitialized => _isInitialized;

  double get audioLevel => _deviceService.currentAudioLevel;

  String? get errorMessage => null;

  Future<void> initMedia() async {
    if (!_isInitialized) {
      await _deviceService.init();
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleCamera() async {
    _deviceService.toggleCameraMute();
    notifyListeners();
  }

  Future<void> toggleMic() async {
    _deviceService.toggleMicrophoneMute();
    notifyListeners();
  }

  Widget buildCameraPreview() {
    final active = isCameraActive;
    return Container(
      color: const Color(0xff12201a),
      child: Center(
        child: active
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0x33d4e8a6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x55d4e8a6),
                        width: 1.5,
                      ),
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
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 36,
                    color: Colors.white38,
                  ),
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
}
