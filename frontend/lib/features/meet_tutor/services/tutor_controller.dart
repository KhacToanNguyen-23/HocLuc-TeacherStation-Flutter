import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../classroom_meet/domain/models/meet_events.dart';
import '../domain/models/tutor_models.dart';
import 'tutor_gateway.dart';

class TutorController extends ChangeNotifier {
  TutorController({
    required this.gateway,
    required this.context,
    required this.contextRevision,
    required this.send,
    this.guardedSend,
    this.prepareObservation,
    this.cancelSend,
    this.sendInterval = const Duration(seconds: 5),
  });
  final TutorGateway gateway;
  final Future<TutorContext> Function(String) context;
  final int Function() contextRevision;
  final Future<bool> Function(String) send;
  final Future<bool> Function(String, bool Function())? guardedSend;
  final Future<bool> Function()? prepareObservation;
  final VoidCallback? cancelSend;
  final Duration sendInterval;
  TutorConfig? config;
  bool enabled = false;
  bool busy = false;
  bool _disposed = false;
  bool _joined = false;
  String? _room;
  int _generation = 0;
  final _seen = <String>{};
  final _questions = <String>{};
  final _queue = Queue<_TutorJob>();
  final _reviews = <TutorReview>[];
  List<TutorReview> get reviews => List.unmodifiable(_reviews);
  int get queued => _queue.length;
  int sentCount = 0;
  String status = 'Chưa cấu hình AI';
  DateTime? _lastSend;

  void configure(TutorConfig value) {
    config = value;
    _invalidate('Đã đổi AI; bật trợ giảng để nhận câu hỏi mới.');
  }

  void setEnabled(bool value) {
    if (value && config == null) return;
    _invalidate(value ? 'Đang theo dõi câu hỏi mới.' : 'Đã tạm dừng.');
    if (value && prepareObservation != null) {
      status = 'Đang lấy mốc chat hiện tại…';
      notifyListeners();
      unawaited(_prepare(_generation));
      return;
    }
    enabled = value;
    notifyListeners();
  }

  Future<void> _prepare(int generation) async {
    bool ready;
    try {
      ready = await prepareObservation!();
    } catch (_) {
      ready = false;
    }
    if (_disposed || generation != _generation) return;
    enabled = ready && _joined;
    status = enabled
        ? 'Đang theo dõi câu hỏi mới.'
        : 'Hãy mở chat Meet, chờ tin nhắn tải xong rồi bật lại trợ giảng.';
    notifyListeners();
  }

  void contextChanged() => cancelSend?.call();

  void _invalidate(String message) {
    _generation++;
    cancelSend?.call();
    enabled = false;
    _queue.clear();
    _questions.clear();
    status = message;
    if (!_disposed) notifyListeners();
  }

  void syncMeeting(String? room, bool joined, List<MeetChatMessage> messages) {
    if (_room != room || (_joined && !joined)) {
      _room = room;
      _seen.clear();
      _reviews.clear();
      sentCount = 0;
      _invalidate('Phòng Meet thay đổi; bật lại trợ giảng khi sẵn sàng.');
      _seen.addAll(messages.map((m) => m.id));
    }
    _joined = joined;
    for (final message in messages) {
      if (!_seen.add(message.id)) continue;
      if (!enabled ||
          !joined ||
          !message.isTutorEligible ||
          message.isSelf ||
          message.text.contains('[Trợ giảng AI]')) {
        continue;
      }
      final question = message.text.trim();
      if (!_isQuestion(question)) continue;
      final key =
          '${contextRevision()}:${question.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
      if (!_questions.add(key)) continue;
      if (_queue.length >= 20) {
        _review(message, 'Nhiều câu hỏi đang chờ; giáo viên hỗ trợ câu này.');
      } else {
        _queue.add(_TutorJob(message, contextRevision()));
      }
    }
    // Bound the session's bookkeeping; old DOM history remains baseline-only.
    if (_seen.length > 4000) {
      final current = messages.map((m) => m.id).toSet();
      _seen.removeWhere((id) => !current.contains(id));
    }
    if (_questions.length > 2000) _questions.clear();
    if (!busy && enabled && _queue.isNotEmpty) unawaited(_drain());
  }

  bool _isQuestion(String text) =>
      text.length >= 3 &&
      text.length <= 1500 &&
      (text.contains('?') ||
          RegExp(
            r'(là gì|tại sao|vì sao|thế nào|như nào|giải thích|bao nhiêu|how |what |why |when |where |which |đúng không|chưa hiểu)',
            caseSensitive: false,
          ).hasMatch(text));

  bool _valid(int generation, int revision) =>
      !_disposed &&
      enabled &&
      _joined &&
      generation == _generation &&
      revision == contextRevision();

  void _review(MeetChatMessage message, String reason) {
    _reviews.insert(0, TutorReview(message.sender, message.text, reason));
    if (_reviews.length > 50) _reviews.removeLast();
  }

  void dismissReview(TutorReview review) {
    _reviews.remove(review);
    notifyListeners();
  }

  Future<void> _drain() async {
    busy = true;
    notifyListeners();
    try {
      while (!_disposed && enabled && _joined && _queue.isNotEmpty) {
        final job = _queue.removeFirst();
        final question = job.message;
        final generation = _generation;
        final revision = job.revision;
        final provider = config!;
        try {
          if (revision != contextRevision()) {
            _review(
              question,
              'Trang bài học đã đổi trong lúc câu hỏi chờ xử lý.',
            );
            continue;
          }
          status = 'Đang tìm căn cứ trong bài học…';
          notifyListeners();
          final lesson = await context(question.text);
          if (!_valid(generation, revision) || lesson.revision != revision) {
            if (!_disposed && generation == _generation) {
              _review(question, 'Bài học hoặc cấu hình đã thay đổi.');
            }
            continue;
          }
          final result = await gateway.answer(provider, question.text, lesson);
          if (!_valid(generation, revision)) {
            if (!_disposed && generation == _generation) {
              _review(question, 'Ngữ cảnh thay đổi trong lúc AI xử lý.');
            }
            continue;
          }
          if (!result.canAutoSend(lesson.sources)) {
            _review(
              question,
              result.reason.isEmpty
                  ? 'AI chưa tạo được phản hồi hợp lệ; không có tin đang chờ duyệt.'
                  : result.reason,
            );
            continue;
          }
          final previous = _lastSend;
          if (previous != null) {
            final remaining =
                sendInterval - DateTime.now().difference(previous);
            if (remaining > Duration.zero) {
              await Future<void>.delayed(remaining);
            }
          }
          if (!_valid(generation, revision)) {
            if (!_disposed && generation == _generation) {
              _review(question, 'Đã dừng hoặc đổi nội dung trước khi gửi.');
            }
            continue;
          }
          final labels = lesson.sources
              .where((s) => result.evidence.containsKey(s.id))
              .map((s) => s.label)
              .join('; ');
          final cleanSender = question.sender.replaceAll(
            RegExp(r'[\r\n]'),
            ' ',
          );
          final sender = cleanSender.substring(
            0,
            cleanSender.length.clamp(0, 80),
          );
          _lastSend = DateTime.now();
          final tentative = result.confidence == TutorConfidence.tentative;
          final warning = tentative
              ? 'Chưa chắc chắn — câu trả lời dự kiến.\n'
              : '';
          final sourceLine = labels.isEmpty
              ? 'Chưa có nguồn bài học xác nhận.'
              : 'Nguồn: $labels';
          final text =
              '[Trợ giảng AI] @$sender: $warning${result.answer}\n$sourceLine';
          final confirmed = guardedSend == null
              ? await send(text)
              : await guardedSend!(text, () => _valid(generation, revision));
          if (_disposed) return;
          if (generation != _generation) continue;
          if (confirmed) {
            sentCount++;
          } else {
            _review(
              question,
              'Meet chưa xác nhận gửi; kiểm tra chat trước khi gửi lại.',
            );
          }
        } catch (_) {
          if (!_disposed && generation == _generation) {
            _review(
              question,
              'Không xử lý được câu hỏi. Kiểm tra API hoặc tài liệu.',
            );
          }
        }
      }
    } finally {
      busy = false;
      if (!_disposed) {
        status = enabled
            ? 'Đang theo dõi • đã gửi $sentCount • sự cố ${_reviews.length}'
            : status;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    cancelSend?.call();
    config = null;
    _queue.clear();
    super.dispose();
  }
}

class _TutorJob {
  const _TutorJob(this.message, this.revision);
  final MeetChatMessage message;
  final int revision;
}
