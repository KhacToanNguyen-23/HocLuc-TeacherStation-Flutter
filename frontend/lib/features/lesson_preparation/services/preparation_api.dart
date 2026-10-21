import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/exams/services/exam_api.dart';
import '../domain/models/preparation_document.dart';

class PreparationFailure implements Exception {
  PreparationFailure(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class PreparationApi {
  PreparationApi({http.Client? client, String? base, ExamApi? session})
    : client = client ?? http.Client(),
      base = base ?? LocalService().base,
      session = session ?? ExamApi();
  final http.Client client;
  final String base;
  final ExamApi session;
  LocalService? _companion;
  Future<void> refreshAuthentication() async {
    await session.ensureSession(rejectedToken: session.auth.appSessionToken);
    final companion = _companion ??= LocalService(base: base);
    await companion.connect();
  }

  Future<Map<String, String>> headers() async {
    await session.ensureSession();
    final companion = _companion ??= LocalService(base: base);
    if (companion.companionToken == null) await companion.connect();
    return {
      ...session.headers,
      'X-Companion-Token': companion.companionToken!,
      if (session.auth.teacherEmail != null)
        'X-Google-Teacher-Email': session.auth.teacherEmail!,
    };
  }

  Future<http.Response> request(String path, String method, [Object? data]) =>
      _request(path, method, data, retryAuth: true);

  Future<http.Response> _request(
    String path,
    String method,
    Object? data, {
    required bool retryAuth,
  }) async {
    final req = http.Request(method, Uri.parse('$base/api/preparation/$path'));
    req.headers.addAll(await headers());
    if (data != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(data);
    }
    final response = await http.Response.fromStream(
      await client.send(req).timeout(const Duration(minutes: 5)),
    ).timeout(const Duration(minutes: 5));
    if (response.statusCode == 401 &&
        retryAuth &&
        (method == 'GET' || method == 'PUT')) {
      await refreshAuthentication();
      return _request(path, method, data, retryAuth: false);
    }
    return check(response);
  }

  http.Response check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    String message = 'Không hoàn tất yêu cầu (${response.statusCode}).';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      message = body['message']?.toString() ?? message;
    } catch (_) {}
    throw PreparationFailure(message, response.statusCode);
  }

  Future<dynamic> get(String path) async =>
      jsonDecode(utf8.decode((await request(path, 'GET')).bodyBytes));
  Future<dynamic> post(String path, [Object? body]) async => jsonDecode(
    utf8.decode((await request(path, 'POST', body ?? {})).bodyBytes),
  );
  Future<dynamic> put(String path, Object body) async =>
      jsonDecode(utf8.decode((await request(path, 'PUT', body)).bodyBytes));
  Future<Uint8List> bytes(String id) async =>
      (await request('assets/${Uri.encodeComponent(id)}', 'GET')).bodyBytes;
  Future<http.StreamedResponse> assetStream(String id) =>
      _assetStream(id, true);
  Future<http.StreamedResponse> _assetStream(String id, bool retryAuth) async {
    final req = http.Request(
      'GET',
      Uri.parse('$base/api/preparation/assets/${Uri.encodeComponent(id)}'),
    );
    req.headers.addAll(await headers());
    final response = await client
        .send(req)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      await response.stream.drain<void>().timeout(const Duration(seconds: 10));
      if (response.statusCode == 401 && retryAuth) {
        await refreshAuthentication();
        return _assetStream(id, false);
      }
      throw PreparationFailure(
        'Không tải được file (${response.statusCode}).',
        response.statusCode,
      );
    }
    return response;
  }

  Future<PreparationMap> upload(String planId, PlatformFile file) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$base/api/preparation/plannings/$planId/sources'),
    );
    req.headers.addAll(await headers());
    final length = await file.length();
    if (length == null) throw StateError('Không đọc được kích thước file.');
    req.files.add(
      http.MultipartFile(
        'file',
        file.readAsByteStream(),
        length,
        filename: file.name,
      ),
    );
    final response = check(
      await http.Response.fromStream(
        await client.send(req).timeout(const Duration(minutes: 10)),
      ).timeout(const Duration(minutes: 10)),
    );
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  void dispose() {
    client.close();
    session.dispose();
    _companion?.client.close();
  }
}
