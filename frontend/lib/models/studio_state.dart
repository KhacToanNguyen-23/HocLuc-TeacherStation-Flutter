import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_service.dart';
import '../services/desktop_lifecycle.dart';
import 'board_stroke.dart';
import 'mixins/studio_canvas_mixin.dart';
import 'mixins/studio_stage_mixin.dart';
import 'mixins/studio_timer_mixin.dart';
import 'mixins/studio_pip_mixin.dart';

export 'board_stroke.dart';
export 'imported_document.dart';
export 'mixins/studio_canvas_mixin.dart';
export 'mixins/studio_stage_mixin.dart';
export 'mixins/studio_timer_mixin.dart';
export 'mixins/studio_pip_mixin.dart';

/// StudioState acts as the central Facade for all studio tools, canvas strokes,
/// document staging, timers, and local backend synchronization.
class StudioState extends ChangeNotifier
    with StudioCanvasMixin, StudioStageMixin, StudioTimerMixin, StudioPipMixin {
  StudioState({LocalService? service}) : service = service ?? LocalService();
  final LocalService service;

  // --- Backend Connectivity & Lesson Metadata ---
  bool online = false, loading = true, saving = false;
  String? error;
  Map<String, dynamic> capabilities = {};
  List<Map<String, dynamic>> microphones = [];
  String title = 'Không gian giảng dạy',
      subject = 'Chung',
      notes = '',
      question = 'Câu hỏi thảo luận cho cả lớp',
      endpoint = '',
      language = 'Tiếng Việt',
      microphone = '',
      view = 'board';
  bool reveal = false, denoise = true;
  String savedAt = '';

  void setView(String next) => change(() => view = next, persist: false);

  void change(VoidCallback update, {bool persist = true}) {
    update();
    if (persist) {
      dirty = true;
      revision++;
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await service.connect();
      final result = await Future.wait([
        service.request('capabilities'),
        service.request('devices'),
        service.request('lesson'),
        service.request('config'),
      ]);
      capabilities = result[0];
      microphones = (result[1]['microphones'] as List)
          .cast<Map<String, dynamic>>();
      final lesson = result[2], config = result[3];
      if (!dirty) {
        title = lesson['title'] as String? ?? title;
        subject = lesson['subject'] as String? ?? subject;
        notes = lesson['notes'] as String? ?? notes;
        question = lesson['question'] as String? ?? question;
        page = ((lesson['page'] as num?)?.toInt() ?? 0).clamp(0, 2);
        if (lesson['pages'] is List && (lesson['pages'] as List).length == 3) {
          pages = (lesson['pages'] as List)
              .map(
                (p) => (p as List)
                    .map((s) => BoardStroke.fromJson(s as Map<String, dynamic>))
                    .toList(),
              )
              .toList();
        }
        endpoint = config['endpoint'] as String? ?? '';
        language = config['language'] as String? ?? 'English';
        microphone = config['microphone'] as String? ?? '';
        if (microphone.isNotEmpty &&
            !microphones.any((m) => m['id'] == microphone)) {
          microphone = '';
        }
        denoise = config['denoise'] as bool? ?? true;
        dirty = false;
      }
      online = true;
    } catch (_) {
      online = false;
      error =
          'Chưa kết nối dịch vụ Java. Có thể thử giao diện; lưu bài cần dịch vụ chạy.';
    } finally {
      loading = false;
      notifyListeners();
      if (online) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => notifyDesktopReady(),
        );
      }
    }
  }

  Future<bool> save() async {
    if (saving) return false;
    final rev = revision;
    final lessonSnapshot = {
      'title': title,
      'subject': subject,
      'notes': notes,
      'question': question,
      'page': page,
      'pages': pages.map((p) => p.map((s) => s.toJson()).toList()).toList(),
    };
    final configSnapshot = {
      'endpoint': endpoint,
      'language': language,
      'microphone': microphone,
      'denoise': denoise,
    };
    saving = true;
    notifyListeners();
    try {
      await service.request('lesson', data: lessonSnapshot);
      await service.request('config', data: configSnapshot);
      dirty = revision != rev;
      final now = DateTime.now();
      savedAt =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      online = true;
      return true;
    } catch (_) {
      online = false;
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    cancelTimer();
    service.dispose();
    super.dispose();
  }
}
