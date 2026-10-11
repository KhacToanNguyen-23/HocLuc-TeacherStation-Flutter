import 'package:flutter/material.dart';

class TeacherMediaService extends ChangeNotifier {
  static final TeacherMediaService _instance = TeacherMediaService._internal();
  factory TeacherMediaService() => _instance;
  TeacherMediaService._internal();

  bool _isCameraActive = true;
  bool _isMicActive = true;
  bool _isInitialized = false;
  final double _audioLevel = 0.0;
  String? _errorMessage;

  bool get isCameraActive => _isCameraActive;
  bool get isMicActive => _isMicActive;
  bool get isInitialized => _isInitialized;
  double get audioLevel => _audioLevel;
  String? get errorMessage => _errorMessage;

  Future<void> initMedia() async {
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    _isCameraActive = !_isCameraActive;
    notifyListeners();
  }

  Future<void> toggleMic() async {
    _isMicActive = !_isMicActive;
    notifyListeners();
  }

  Widget buildCameraPreview() {
    return Container(
      color: const Color(0xff12201a),
      child: Center(
        child: _isCameraActive
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffd4e8a6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Giáo viên giảng dạy',
                    style: TextStyle(fontSize: 11, color: Color(0xffa0b3a5)),
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
                  SizedBox(height: 4),
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
