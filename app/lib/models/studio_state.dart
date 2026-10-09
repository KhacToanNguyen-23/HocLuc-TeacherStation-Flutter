import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_service.dart';
import '../services/desktop_lifecycle.dart';

class BoardStroke {
  BoardStroke(this.color, this.width, this.points);
  final Color color;
  final double width;
  final List<Offset> points;
  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
  };
  static BoardStroke fromJson(Map<String, dynamic> json) => BoardStroke(
    Color((json['color'] as num).toInt()),
    (json['width'] as num).toDouble(),
    (json['points'] as List)
        .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList(),
  );
}

class StudioState extends ChangeNotifier {
  StudioState({LocalService? service}) : service = service ?? LocalService();
  final LocalService service;
  bool online = false, loading = true, saving = false, dirty = false;
  String? error;
  Map<String, dynamic> capabilities = {};
  List<Map<String, dynamic>> microphones = [];
  String title = 'Khảo sát hàm số bậc hai',
      subject = 'Toán học',
      notes = '',
      question = 'Với y = x² − 2x − 3, tọa độ đỉnh của parabol là gì?',
      endpoint = '',
      language = 'English',
      microphone = '',
      view = 'board',
      tool = 'pen';
  bool reveal = false, denoise = true;
  int page = 0, seconds = 0;
  Color ink = const Color(0xff244b40);
  List<List<BoardStroke>> pages = [[], [], []];
  Timer? _timer;
  String savedAt = '';
  int _revision = 0;
  List<BoardStroke> get strokes => pages[page];
  bool get timerRunning => _timer != null;

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

  void change(VoidCallback update, {bool persist = true}) {
    update();
    if (persist) {
      dirty = true;
      _revision++;
    }
    notifyListeners();
  }

  void setView(String next) => change(() => view = next, persist: false);
  void startStroke(Offset point) {
    if (tool == 'erase') {
      erase(point);
      return;
    }
    strokes.add(BoardStroke(ink, tool == 'highlight' ? 15 : 3, [point]));
    _revision++;
    dirty = true;
    notifyListeners();
  }

  void extendStroke(Offset point) {
    if (tool == 'erase') {
      erase(point);
      return;
    }
    if (strokes.isEmpty) return;
    strokes.last.points.add(point);
    _revision++;
    dirty = true;
    notifyListeners();
  }

  void erase(Offset point) {
    strokes.removeWhere(
      (stroke) => stroke.points.any((p) => (p - point).distance < .025),
    );
    _revision++;
    dirty = true;
    notifyListeners();
  }

  void undo() {
    if (strokes.isNotEmpty) change(() => strokes.removeLast());
  }

  void clearPage() => change(() => strokes.clear());
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

  Future<bool> save() async {
    if (saving) return false;
    final revision = _revision;
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
      dirty = _revision != revision;
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
    _timer?.cancel();
    service.dispose();
    super.dispose();
  }
}
