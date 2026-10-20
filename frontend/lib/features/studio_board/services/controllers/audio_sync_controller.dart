import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/network/local_service.dart';
import '../../../classroom_meet/services/audio_translation_service.dart';
import '../../../classroom_meet/services/teacher_media_service.dart';

/// Single-responsibility controller managing Windows WASAPI microphone state,
/// audio translation runtime, and sync with TeacherMediaService.
class AudioSyncController extends ChangeNotifier {
  AudioSyncController({LocalService? service}) {
    _service = service ?? LocalService();
    audio = AudioTranslationService(
      service: LocalService(base: _service.base),
      manageRuntime: true,
    );
    try {
      TeacherMediaService().addListener(_syncAudioMute);
      _syncAudioMute();
    } catch (_) {
      // In test environments TeacherMediaService may not have native channels
    }
  }

  late final LocalService _service;
  late final AudioTranslationService audio;

  bool _isMicActive = false;
  bool get isMicActive => _isMicActive;

  String language = 'Tiếng Việt';
  String microphone = '';
  List<Map<String, dynamic>> microphones = [];

  void _syncAudioMute() {
    try {
      final micActive = TeacherMediaService().isMicActive;
      _isMicActive = micActive;
      final muted = !micActive;
      if (audio.muted != muted) {
        unawaited(audio.setMuted(muted));
      }
      notifyListeners();
    } catch (_) {}
  }

  void setMicActive(bool active) {
    _isMicActive = active;
    notifyListeners();
  }

  void setLanguage(String lang) {
    if (language != lang) {
      language = lang;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    try {
      TeacherMediaService().removeListener(_syncAudioMute);
    } catch (_) {}
    super.dispose();
  }
}

