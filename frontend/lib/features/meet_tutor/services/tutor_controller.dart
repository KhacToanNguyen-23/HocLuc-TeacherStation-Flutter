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
    this.detailedSend,
    this.prepareObservation,
    this.cancelSend,
    this.stopObservation,
    this.preparationError,
    this.sendInterval = const Duration(seconds: 5),
  });
  final TutorGateway gateway;
  final Future<TutorContext> Function(String) context;
  final int Function() contextRevision;
  final Future<bool> Function(String) send;
  final Future<bool> Function(String, bool Function())? guardedSend;
  final Future<MeetTutorDelivery> Function(String, bool Function())?
  detailedSend;
  final Future<bool> Function()? prepareObservation;
  final VoidCallback? cancelSend;
  final VoidCallback? stopObservation;
  final String? Function()? preparationError;
  String? activationError;
  final Duration sendInterval;
  TutorConfig? config;
  bool enabled = false;
  bool starting = false;
  bool busy = false;
  bool _disposed = false;
  bool _joined = false;
  String? _room;
  int _generation = 0;
  Completer<void> _cancelled = Completer<void>();
  final _seen = <String>{};
  final _queue = Queue<_TutorJob>();
  final _reviews = <TutorReview>[];
  List<TutorReview> get reviews => List.unmodifiable(_reviews);
  int get queued => _queue.length;
  int sentCount = 0;
  String status = 'Trợ giảng đang tắt.';
  DateTime? _lastSend;

  void configure(TutorConfig value) {
    config = value;
    _invalidate('Trợ giảng đang tắt. Bật để nhận câu hỏi mới.');
  }

  void setEnabled(bool value) {
    if (value && config == null) return;
    _invalidate(value ? 'Đang theo dõi câu hỏi mới.' : 'Đã tạm dừng.');
    if (value && prepareObservation != null) {
      starting = true;
      status = 'Đang tự mở chat Meet và chờ lịch sử tải xong…';
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
    starting = false;
    enabled = ready && _joined;
    status = enabled
        ? 'Đang theo dõi câu hỏi mới.'
        : (preparationError?.call() ??
              'Chưa bật được AI. Kiểm tra kết nối phòng Meet rồi thử lại.');
    activationError = enabled ? null : status;
    notifyListeners();
  }

  void contextChanged() {
    if (enabled || busy) cancelSend?.call();
  }

  void _invalidate(String message) {
    _generation++;
    if (!_cancelled.isCompleted) _cancelled.complete();
    _cancelled = Completer<void>();
    if (gateway is CancellableTutorGateway) {
      (gateway as CancellableTutorGateway).cancelPending();
    }
    cancelSend?.call();
    stopObservation?.call();
    activationError = null;
    enabled = false;
    starting = false;
    _queue.clear();
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
      if (question.isEmpty) continue;
      final aiPending = _queue.where((job) => job.notice == null).length;
      if (question.length > 1500) {
        if (_queue.any(
          (job) => job.notice != null && job.message.text.length > 1500,
        )) {
          continue;
        }
        _queue.add(
          _TutorJob(
            message,
            contextRevision(),
            notice:
                'Câu hỏi quá dài. Em vui lòng chia thành các câu hỏi ngắn hơn.',
          ),
        );
      } else if (aiPending >= 20) {
        if (_queue.any(
          (job) => job.notice != null && job.message.text.length <= 1500,
        )) {
          continue;
        }
        _queue.add(
          _TutorJob(
            message,
            contextRevision(),
            notice:
                'Hệ thống đang bận nên các câu hỏi mới vượt hàng đợi chưa được xử lý. Các em vui lòng hỏi lại sau.',
          ),
        );
      } else {
        _queue.add(_TutorJob(message, contextRevision()));
      }
    }
    // Bound the session's bookkeeping; old DOM history remains baseline-only.
    if (_seen.length > 4000) {
      final current = messages.map((m) => m.id).toSet();
      _seen.removeWhere((id) => !current.contains(id));
    }
    if (!busy && enabled && _queue.isNotEmpty) unawaited(_drain());
  }

  void _review(MeetChatMessage message, String reason) {
    _reviews.insert(0, TutorReview(message.sender, message.text, reason));
    if (_reviews.length > 50) _reviews.removeLast();
  }

  void dismissReview(TutorReview review) {
    _reviews.remove(review);
    notifyListeners();
  }

  static const invalidReply =
      'AI chưa tạo được câu trả lời hợp lệ cho câu hỏi này. Em vui lòng diễn đạt lại hoặc hỏi lại sau.';
  static const apiFailureReply =
      'Hệ thống AI đang gặp lỗi nên chưa thể trả lời câu hỏi này. Em vui lòng hỏi lại sau.';
  static const changedReply =
      'Nội dung bài giảng vừa thay đổi nên câu trả lời đang xử lý đã được hủy. Em vui lòng hỏi lại theo nội dung hiện tại.';

  bool _sessionCurrent(int generation) =>
      !_disposed && enabled && _joined && generation == _generation;

  Future<void> _deliver(
    MeetChatMessage question,
    String body,
    int generation, {
    int? revision,
    bool allowRecovery = true,
    bool broadcast = false,
  }) async {
    final previous = _lastSend;
    if (previous != null) {
      final remaining = sendInterval - DateTime.now().difference(previous);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }
    if (!_sessionCurrent(generation)) return;
    var dispatchRevision = contextRevision();
    if (revision != null && revision != dispatchRevision) {
      body = changedReply;
      revision = null;
    }
    final cleanSender = question.sender.replaceAll(RegExp(r'[\r\n]'), ' ');
    final sender = cleanSender.substring(0, cleanSender.length.clamp(0, 80));
    bool valid() =>
        _sessionCurrent(generation) &&
        (revision == null || dispatchRevision == contextRevision());
    _lastSend = DateTime.now();
    final text = broadcast
        ? '[Trợ giảng AI] Thông báo chung: $body'
        : '[Trợ giảng AI] @$sender: $body';
    MeetTutorDelivery outcome;
    try {
      if (detailedSend != null) {
        outcome = await detailedSend!(text, valid);
      } else {
        final confirmed = guardedSend == null
            ? await send(text)
            : await guardedSend!(text, valid);
        outcome = confirmed
            ? MeetTutorDelivery.confirmed
            : MeetTutorDelivery.unconfirmed;
      }
    } catch (_) {
      outcome = MeetTutorDelivery.unconfirmed;
    }
    if (!_sessionCurrent(generation)) return;
    if (outcome == MeetTutorDelivery.notDispatched &&
        allowRecovery &&
        revision != null &&
        dispatchRevision != contextRevision()) {
      await _deliver(question, changedReply, generation, allowRecovery: false);
      return;
    }
    if (outcome == MeetTutorDelivery.confirmed) {
      sentCount++;
    } else {
      // Delivery is ambiguous: do not send another message and risk duplicates.
      _review(
        question,
        'Meet chưa xác nhận gửi; kiểm tra chat trước khi gửi lại.',
      );
    }
  }

  Future<T> _untilCancelled<T>(Future<T> task, Future<void> cancelled) =>
      Future.any([
        task,
        cancelled.then<T>((_) => throw const _TutorCancelled()),
      ]);

  Future<void> _drain() async {
    final drainGeneration = _generation;
    final cancelled = _cancelled.future;
    busy = true;
    notifyListeners();
    try {
      while (_sessionCurrent(drainGeneration) && _queue.isNotEmpty) {
        final job = _queue.removeFirst();
        final question = job.message;
        final generation = drainGeneration;
        final revision = job.revision;
        try {
          if (job.notice != null) {
            await _deliver(question, job.notice!, generation, broadcast: true);
            continue;
          }
          if (revision != contextRevision()) {
            await _deliver(question, changedReply, generation);
            continue;
          }
          status = 'Đang xử lý câu hỏi…';
          notifyListeners();
          final lesson = await _untilCancelled(
            context(question.text).timeout(const Duration(seconds: 15)),
            cancelled,
          );
          if (!_sessionCurrent(generation)) continue;
          if (revision != contextRevision() || lesson.revision != revision) {
            await _deliver(question, changedReply, generation);
            continue;
          }
          final result = await _untilCancelled(
            gateway.answer(config!, question.text, lesson),
            cancelled,
          );
          if (!_sessionCurrent(generation)) continue;
          if (revision != contextRevision()) {
            await _deliver(question, changedReply, generation);
            continue;
          }
          if (result.confidence == TutorConfidence.outOfScope) {
            await _deliver(
              question,
              'Không nằm trong nội dung bài học',
              generation,
              revision: revision,
            );
          } else if (!result.canAutoSend(lesson.sources)) {
            final response = result.reason == 'provider_unavailable'
                ? apiFailureReply
                : invalidReply;
            await _deliver(question, response, generation, revision: revision);
          } else {
            final labels = lesson.sources
                .where((s) => result.evidence.containsKey(s.id))
                .map((s) => s.label)
                .join('; ');
            final warning = result.confidence == TutorConfidence.tentative
                ? 'Chưa chắc chắn — câu trả lời dự kiến.\n'
                : '';
            final sourceLine = labels.isEmpty
                ? 'Chưa có nguồn bài học xác nhận.'
                : 'Nguồn: $labels';
            await _deliver(
              question,
              '$warning${result.answer}\n$sourceLine',
              generation,
              revision: revision,
            );
          }
        } catch (_) {
          if (_sessionCurrent(generation)) {
            await _deliver(question, apiFailureReply, generation);
          }
        }
      }
    } finally {
      busy = false;
      if (!_disposed) {
        status = enabled
            ? 'Đang theo dõi • đã gửi $sentCount • chưa xác nhận ${_reviews.length}'
            : status;
        notifyListeners();
        if (enabled && _joined && _queue.isNotEmpty && !busy) {
          unawaited(_drain());
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    if (!_cancelled.isCompleted) _cancelled.complete();
    if (gateway is CancellableTutorGateway) {
      (gateway as CancellableTutorGateway).cancelPending();
    }
    cancelSend?.call();
    stopObservation?.call();
    config = null;
    _queue.clear();
    super.dispose();
  }
}

class _TutorJob {
  const _TutorJob(this.message, this.revision, {this.notice});
  final MeetChatMessage message;
  final int revision;
  final String? notice;
}

class _TutorCancelled implements Exception {
  const _TutorCancelled();
}
