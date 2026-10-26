import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent preferences used by the classroom dashboard, Meet capture and board.
class ClassroomSettingsService extends ChangeNotifier {
  ClassroomSettingsService._();

  static final ClassroomSettingsService instance = ClassroomSettingsService._();

  static const _autoCameraKey = 'classroom.auto_camera';
  static const _noiseSuppressionKey = 'classroom.noise_suppression';
  static const _boardOptimizationKey = 'classroom.board_optimization';

  bool _autoCamera = true;
  bool _noiseSuppression = true;
  bool _boardOptimization = true;
  Future<void>? _loading;

  bool get autoCamera => _autoCamera;
  bool get noiseSuppression => _noiseSuppression;
  bool get boardOptimization => _boardOptimization;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _autoCamera = preferences.getBool(_autoCameraKey) ?? true;
    _noiseSuppression = preferences.getBool(_noiseSuppressionKey) ?? true;
    _boardOptimization = preferences.getBool(_boardOptimizationKey) ?? true;
    notifyListeners();
  }

  Future<void> setAutoCamera(bool value) async {
    await load();
    if (_autoCamera == value) return;
    _autoCamera = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoCameraKey, value);
  }

  Future<void> setNoiseSuppression(bool value) async {
    await load();
    if (_noiseSuppression == value) return;
    _noiseSuppression = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_noiseSuppressionKey, value);
  }

  Future<void> setBoardOptimization(bool value) async {
    await load();
    if (_boardOptimization == value) return;
    _boardOptimization = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_boardOptimizationKey, value);
  }
}
