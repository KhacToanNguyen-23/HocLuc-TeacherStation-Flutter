import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:teaching_companion/features/auth/services/google_meet_auth_service.dart';
import 'exam_session_service.dart';
import 'package:teaching_companion/core/network/local_service.dart';

class ExamOAuthClient {
  ExamOAuthClient({http.Client? client, String? base})
    : client = client ?? http.Client(),
      base = base ?? LocalService().base;
  final http.Client client;
  final String base;
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await client
        .post(
          Uri.parse('$base/api/auth/google/$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 20));
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        body['message']?.toString() ?? 'Không kết nối được đăng nhập Google.',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> start() => _post('start', {});
  Future<Map<String, dynamic>> poll(Map<String, dynamic> flow) =>
      _post('poll', {'state': flow['state'], 'pollToken': flow['pollToken']});
  void accept(Map<String, dynamic> response, GoogleMeetAuthService auth) {
    if (response['status'] != 'COMPLETE' ||
        response['token'] is! String ||
        response['user'] is! Map) {
      throw StateError('Chưa có phiên Google được xác minh.');
    }
    final user = response['user'] as Map;
    auth.signInWithOtpSession(
      token: response['token'] as String,
      name: user['name'] as String,
      email: user['email'] as String,
    );
    final session = ExamSessionService();
    session.providerAccessToken = response['googleAccessToken'] as String;
    session.attachLocalExamSession(
      token: response['token'] as String,
      teacherId: user['id'] as String,
      role: user['role'] as String,
    );
  }

  void dispose() => client.close();
}

