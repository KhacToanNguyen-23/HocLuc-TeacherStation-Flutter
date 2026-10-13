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
  Future<void>? _localSessionFuture;

  Future<void> _ensureLocalSession({String? rejectedToken}) async {
    if (!auth.hasLocalGoogleProfile) return;
    if (auth.appSessionToken != null &&
        auth.appSessionToken!.isNotEmpty &&
        (rejectedToken == null || auth.appSessionToken != rejectedToken)) {
      return;
    }
    if (_localSessionFuture != null) return _localSessionFuture;
    final pending = _createLocalSession();
    _localSessionFuture = pending;
    try {
      await pending;
    } finally {
      _localSessionFuture = null;
    }
  }

  Future<void> _createLocalSession() async {
    final revision = auth.profileRevision;
    final email = auth.teacherEmail!;
    final name = auth.teacherName;
    final bootstrap = _check(
      await client
          .get(Uri.parse('$base/api/bootstrap'))
          .timeout(const Duration(seconds: 10)),
    );
    final companion = jsonDecode(utf8.decode(bootstrap.bodyBytes)) as Map;
    final response = _check(
      await client
          .post(
            Uri.parse('$base/api/auth/google/webview-session'),
            headers: {
              'Content-Type': 'application/json',
              'X-Companion-Token': companion['token'] as String,
            },
            body: jsonEncode({'email': email, 'name': name}),
          )
          .timeout(const Duration(seconds: 10)),
    );
    final session = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final user = session['user'] as Map;
    if (!auth.hasLocalGoogleProfile || auth.profileRevision != revision) {
      throw ExamApiException('Phiên đăng nhập đã thay đổi.', status: 401);
    }
    await auth.attachLocalExamSession(
      token: session['token'] as String,
      teacherId: user['id'] as String,
    );
  }

  Future<http.Response> _withSession(
    Future<http.Response> Function() send,
  ) async {
    final revision = auth.profileRevision;
    await _ensureLocalSession();
    if (auth.profileRevision != revision) {
      throw ExamApiException('Phiên đăng nhập đã thay đổi.', status: 401);
    }
    final token = auth.appSessionToken;
    var response = await send();
    if (auth.profileRevision != revision) {
      throw ExamApiException('Phiên đăng nhập đã thay đổi.', status: 401);
    }
    if (response.statusCode == 401 &&
        auth.hasLocalGoogleProfile &&
        token != null) {
      await _ensureLocalSession(rejectedToken: token);
      response = await send();
    }
    return _check(response);
  }

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
