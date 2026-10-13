import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'google_meet_auth_service.dart';
import 'local_service.dart';

class ExamApiException implements Exception {
  ExamApiException(this.message, {this.status = 0, this.details = const []});
  final String message;
  final int status;
  final List<dynamic> details;
  @override
  String toString() => message;
}

/// One backend session from the existing app login, never another login form.
class ExamApi {
  ExamApi({http.Client? client, String? base, GoogleMeetAuthService? auth})
    : client = client ?? http.Client(),
      base = base ?? LocalService().base,
      auth = auth ?? GoogleMeetAuthService();
  final http.Client client;
  final String base;
  final GoogleMeetAuthService auth;
  Future<http.Response> _withSession(Future<http.Response> Function() send) async => _check(await send());

  Map<String, String> get headers {
    final token = auth.appSessionToken;
    if (token == null || token.isEmpty) {
      throw ExamApiException(
        'Phiên hiện tại chưa được backend xác thực. Đăng nhập lại bằng màn hình đăng nhập của app.',
        status: 401,
      );
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<http.Response> _request(
    String path,
    String method,
    Object? data,
  ) async {
    return _withSession(() async {
      final request = http.Request(method, Uri.parse('$base/api/exams/$path'));
      request.headers.addAll(headers);
      if (data != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(data);
      }
      return http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 90)),
      );
    });
  }

  http.Response _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    Map<String, dynamic> body = {};
    try {
      body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    throw ExamApiException(
      body['message']?.toString() ??
          'Không hoàn tất yêu cầu (${response.statusCode}).',
      status: response.statusCode,
      details: body['details'] is List ? body['details'] as List : const [],
    );
  }

  Future<dynamic> get(String path) async =>
      jsonDecode(utf8.decode((await _request(path, 'GET', null)).bodyBytes));
  Future<dynamic> post(String path, [Object? data]) async =>
      jsonDecode(utf8.decode((await _request(path, 'POST', data)).bodyBytes));
  Future<dynamic> put(String path, Object data) async =>
      jsonDecode(utf8.decode((await _request(path, 'PUT', data)).bodyBytes));
  Future<Uint8List> bytes(String path) async =>
      (await _request(path, 'GET', null)).bodyBytes;
  Future<Uint8List> postBytes(String path, Object data) async =>
      (await _request(path, 'POST', data)).bodyBytes;
  Future<dynamic> upload(
    String path,
    Uint8List bytes,
    String filename, {
    Map<String, String> fields = const {},
  }) async {
    return _withSession(() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$base/api/exams/$path'),
      );
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 90)),
      );
      return response;
    }).then((response) => jsonDecode(utf8.decode(response.bodyBytes)));
  }

  void dispose() => client.close();
}
