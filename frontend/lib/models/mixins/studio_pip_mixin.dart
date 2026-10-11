import 'package:flutter/material.dart';

/// Mixin quản lý trạng thái Floating Webcam PIP và Drawer trong Studio
mixin StudioPipMixin on ChangeNotifier {
  bool showCameraPip = false;
  bool isCameraEnabled = true;
  bool pipMinimized = false;
  Offset pipPosition = const Offset(16, 16);
  bool showQuestionsDrawer = false;

  void toggleCameraPip() {
    showCameraPip = !showCameraPip;
    notifyListeners();
  }

  void toggleCameraEnabled() {
    isCameraEnabled = !isCameraEnabled;
    notifyListeners();
  }

  void togglePipMinimized() {
    pipMinimized = !pipMinimized;
    notifyListeners();
  }

  void setPipPosition(Offset pos) {
    pipPosition = pos;
    notifyListeners();
  }

  void toggleQuestionsDrawer() {
    showQuestionsDrawer = !showQuestionsDrawer;
    notifyListeners();
  }

  void setQuestionsDrawer(bool open) {
    if (showQuestionsDrawer != open) {
      showQuestionsDrawer = open;
      notifyListeners();
    }
  }

  // --- Semantic Aliases (Khay tài liệu giảng dạy) ---
  bool get showDocumentsDrawer => showQuestionsDrawer;
  set showDocumentsDrawer(bool value) => showQuestionsDrawer = value;
  void toggleDocumentsDrawer() => toggleQuestionsDrawer();
  void setDocumentsDrawer(bool open) => setQuestionsDrawer(open);
}
