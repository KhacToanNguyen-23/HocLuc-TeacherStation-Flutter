import 'dart:async';
import 'package:flutter/foundation.dart';

/// Mixin quản lý logic đồng hồ đếm ngược Countdown Timer cho buổi dạy
mixin StudioTimerMixin on ChangeNotifier {
  int seconds = 300;
  int timerInitialSeconds = 300;
  Timer? _timer;
  bool get timerRunning => _timer != null;

  void setTimerSeconds(int sec) {
    timerInitialSeconds = sec;
    seconds = sec;
    notifyListeners();
  }

  void addTimerMinute() {
    seconds += 60;
    notifyListeners();
  }

  void resetTimer([int? sec]) {
    _timer?.cancel();
    _timer = null;
    seconds = sec ?? timerInitialSeconds;
    notifyListeners();
  }

  void toggleTimer() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    } else {
      if (seconds == 0) seconds = 120;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (seconds > 0) seconds--;
        if (seconds == 0) {
          _timer?.cancel();
          _timer = null;
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
