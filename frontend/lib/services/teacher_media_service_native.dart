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
      !_deviceService.isCameraMuted &&
      (_deviceService.isCameraActive || !_deviceService.isInitialized);

  bool get isMicActive =>
      !_deviceService.isMicMuted &&
      (_deviceService.isMicActive || !_deviceService.isInitialized);

  bool get isInitialized => _isInitialized;

  double get audioLevel => _deviceService.currentAudioLevel;

  String? get errorMessage => null;

  MediaDeviceService get deviceService => _deviceService;

  List<String> get availableCameras =>
      _deviceService.cameras.map((c) => c.label).toList();

  List<String> get availableMicrophones =>
      _deviceService.microphones.map((m) => m.label).toList();

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

  Future<void> switchCamera(String cameraName) async {
    await _deviceService.switchCamera(cameraName);
    notifyListeners();
  }

  Future<void> switchMicrophone(String micLabel) async {
    _deviceService.switchMicrophone(micLabel);
    notifyListeners();
  }

  Widget buildCameraPreview() {
    return _deviceService.buildCameraWidget();
  }
}
