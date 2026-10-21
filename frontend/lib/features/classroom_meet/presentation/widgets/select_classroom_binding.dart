part of '../dashboard/select_classroom_dialog.dart';

extension _ClassBinding on _SelectClassroomDialogState {
  String _getTargetClassName() {
    switch (_sourceType) {
      case _ClassSourceType.googleCourse:
        return _selectedGoogleCourse?['title'] as String? ?? 'Lớp Google Meet';
      case _ClassSourceType.presetClass:
        return 'Lớp $_selectedPreset';
      case _ClassSourceType.customClass:
        final text = _customClassController.text.trim();
        return text.isNotEmpty ? text : 'Lớp học';
    }
  }
}
