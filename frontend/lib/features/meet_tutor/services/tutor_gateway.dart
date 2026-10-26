import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/network/local_service.dart';
import '../domain/models/tutor_models.dart';

abstract interface class TutorGateway {
  Future<void> test(TutorConfig config);
  Future<TutorResult> answer(
    TutorConfig config,
    String question,
    TutorContext context,
  );
}

abstract interface class CancellableTutorGateway {
  void cancelPending();
}

class CompanionTutorGateway implements TutorGateway, CancellableTutorGateway {
  CompanionTutorGateway(this.service);
  final LocalService service;
  Completer<void>? _activeAbort;

  @override
  void cancelPending() {
    final abort = _activeAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _activeAbort = null;
  }

  Future<Map<String, dynamic>> _post(
    String route,
    Map<String, dynamic> data,
  ) async {
    final abort = Completer<void>();
    _activeAbort = abort;
    Future<http.Response> request() async {
      final headers = await service.getAuthHeaders();
      if (abort.isCompleted) throw http.RequestAbortedException();
      final request =
          http.AbortableRequest(
              'POST',
              Uri.parse('${service.base}/api/tutor/$route'),
              abortTrigger: abort.future,
            )
            ..headers.addAll(headers)
            ..body = jsonEncode(data);
      return http.Response.fromStream(await service.client.send(request));
    }

    late http.Response response;
    try {
      response =
          await Future.any([
            request(),
            abort.future.then<http.Response>(
              (_) => throw http.RequestAbortedException(),
            ),
          ]).timeout(
            const Duration(seconds: 100),
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Tutor request timed out');
            },
          );
    } finally {
      if (identical(_activeAbort, abort)) _activeAbort = null;
    }
    if (response.statusCode != 200) {
      // Never display a provider's response body or request credentials.
      throw StateError(
        'Không gọi được AI (${response.statusCode}). Kiểm tra cấu hình và hạn mức.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<void> test(TutorConfig config) async {
    final result = await _post('test', {'config': config.toJson()});
    if (result['success'] != true) {
      throw StateError('AI chưa xác nhận kết nối.');
    }
  }

  @override
  Future<TutorResult> answer(
    TutorConfig config,
    String question,
    TutorContext context,
  ) async {
    final data = await _post('answer', {
      'config': config.toJson(),
      'question': question,
      'currentPage': context.currentPage,
      'lessonSubject': context.lessonSubject,
      'sources': context.sources.map((s) => s.toJson()).toList(),
    });
    final evidence = <String, String>{};
    if (data['status'] == 'out_of_scope') {
      return const TutorResult(
        answer: 'Không nằm trong nội dung bài học',
        evidence: {},
        confidence: TutorConfidence.outOfScope,
      );
    }
    final grounded =
        data['status'] == 'answered' &&
        (data['confidence'] == null || data['confidence'] == 'high');
    final tentative =
        data['status'] == 'tentative' && data['confidence'] == 'low';
    var validEnvelope = (grounded || tentative) && data['sources'] is List;
    if (validEnvelope) {
      for (final entry in data['sources'] as List) {
        if (entry is Map &&
            entry['id'] is String &&
            entry['quote'] is String &&
            !evidence.containsKey(entry['id'])) {
          evidence[entry['id'] as String] = entry['quote'] as String;
        } else {
          validEnvelope = false;
        }
      }
    }
    return TutorResult(
      answer: data['answer'] as String? ?? '',
      evidence: evidence,
      confidence: !validEnvelope
          ? TutorConfidence.unavailable
          : tentative
          ? TutorConfidence.tentative
          : TutorConfidence.grounded,
      reason: data['reason'] as String? ?? 'Chưa đủ căn cứ trong bài học.',
    );
  }
}
