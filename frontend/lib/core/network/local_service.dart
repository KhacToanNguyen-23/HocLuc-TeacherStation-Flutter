import 'package:teaching_companion/core/utils/frontend_logger.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocalService {
  static const int defaultCompanionPort = 47831;
  static const configuredBase = String.fromEnvironment('COMPANION_SERVICE');

  LocalService({http.Client? client, String? base})
    : base =
          base ??
          (configuredBase.isNotEmpty
              ? configuredBase
              : kIsWeb
              ? (Uri.base.port == defaultCompanionPort
                    ? Uri.base.origin
                    : 'http://127.0.0.1:$defaultCompanionPort')
              : 'http://127.0.0.1:$defaultCompanionPort'),
      client = client ?? http.Client();

  final http.Client client;
  final String base;
  String? _token;
  String? get companionToken => _token;

  Future<void> connect() async {
    final response = await client
        .get(Uri.parse('$base/api/bootstrap'))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw StateError('Java service: ${response.statusCode}');
    }
    _token =
        (jsonDecode(response.body) as Map<String, dynamic>)['token'] as String;
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (_token == null) throw StateError('Chưa kết nối Java service');
    final headers = {
      'X-Companion-Token': _token!,
      'Content-Type': 'application/json',
    };
    final url = Uri.parse('$base/api/$path');
    final response = data == null
        ? await client
              .get(url, headers: headers)
              .timeout(const Duration(seconds: 8))
        : await client
              .put(url, headers: headers, body: jsonEncode(data))
              .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Java service: ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    bool retryLocalSession = true,
  }) async {
    if (_token == null) {
      try {
        await connect();
      } catch (e) {
        FrontendLogger.write(
          '[LocalService] Auto-connect before POST "$path" failed: $e',
        );
      }
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) {
      headers['X-Companion-Token'] = _token!;
    }
    final url = Uri.parse('$base/api/$path');
    final response = await client
        .post(url, headers: headers, body: jsonEncode(data ?? {}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401 && retryLocalSession) {
      final problem = jsonDecode(utf8.decode(response.bodyBytes));
      if (problem is Map && problem['error'] == 'Local session required') {
        await connect();
        return post(path, data: data, retryLocalSession: false);
      }
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      try {
        final problem = jsonDecode(utf8.decode(response.bodyBytes));
        if (problem is Map &&
            (problem['error'] is String || problem['message'] is String)) {
          throw StateError((problem['error'] ?? problem['message']) as String);
        }
      } on FormatException catch (_) {
        // Keep the HTTP status when the server returned a non-JSON body.
      }
      throw StateError('Java service: ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendOtp({
    required String target,
    required String type,
  }) async {
    try {
      final res = await client
          .post(
            Uri.parse('$base/api/auth/otp/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'target': target, 'type': type}),
          )
          .timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'message': 'Không kết nối được backend. Vui lòng thử lại.',
      };
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String target,
    required String otp,
    String? name,
    required String type,
  }) async {
    try {
      final res = await client
          .post(
            Uri.parse('$base/api/auth/otp/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'target': target,
              'otp': otp,
              'name': name,
              'type': type,
            }),
          )
          .timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'message': 'Không kết nối được backend. Vui lòng thử lại.',
      };
    }
  }

  Future<Map<String, dynamic>> getActiveClassroom({bool strict = false}) async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final headers = await getAuthHeaders(forceRefresh: attempt > 0);
        final response = await client
            .get(Uri.parse('$base/api/classroom/active'), headers: headers)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 401 && attempt == 0) continue;
        if (response.statusCode != 200) {
          throw StateError(
            'Không đọc được buổi học hiện tại (${response.statusCode}).',
          );
        }
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (e) {
      if (strict) rethrow;
      FrontendLogger.write('[LocalService] getActiveClassroom error: $e');
    }
    return {};
  }

  Future<bool> endClassroom({
    String? classroomId,
    Map<String, dynamic>? content,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (classroomId != null) data['classroomId'] = classroomId;
      if (content != null) data['content'] = content;
      final result = await post('classroom/end', data: data);
      return result['success'] == true;
    } catch (e) {
      FrontendLogger.write('[LocalService] endClassroom error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getClassroomContent(String classroomId) async {
    try {
      final url = Uri.parse('$base/api/classroom/$classroomId/content');
      final res = await client
          .get(url, headers: await getAuthHeaders())
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      FrontendLogger.write('[LocalService] getClassroomContent error: $e');
    }
    return null;
  }

  Future<List<dynamic>> getClassroomHistory({String? teacherId}) async {
    try {
      final url = teacherId != null
          ? Uri.parse('$base/api/classroom/history?teacherId=$teacherId')
          : Uri.parse('$base/api/classroom/history');
      final res = await client
          .get(url, headers: await getAuthHeaders())
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      FrontendLogger.write('[LocalService] getClassroomHistory error: $e');
    }
    return [];
  }

  Future<bool> deleteClassroomHistory(String id) async {
    try {
      final res = await client
          .delete(
            Uri.parse('$base/api/classroom/history/$id'),
            headers: await getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return data['success'] == true;
      }
    } catch (e) {
      FrontendLogger.write('[LocalService] deleteClassroomHistory error: $e');
    }
    return false;
  }

  Future<bool> clearAllClassroomHistory({String? teacherId}) async {
    try {
      final url = teacherId != null
          ? Uri.parse('$base/api/classroom/history?teacherId=$teacherId')
          : Uri.parse('$base/api/classroom/history');
      final res = await client
          .delete(url, headers: await getAuthHeaders())
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return data['success'] == true;
      }
    } catch (e) {
      FrontendLogger.write('[LocalService] clearAllClassroomHistory error: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await client
          .post(
            Uri.parse('$base/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'identifier': identifier, 'password': password}),
          )
          .timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'message': 'Không kết nối được backend. Vui lòng thử lại.',
      };
    }
  }

  Future<Map<String, dynamic>> devLogin() async {
    try {
      final res = await client
          .post(
            Uri.parse('$base/api/auth/dev-login'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'message':
            'Không kết nối được backend dev. Hãy chạy backend với profile dev.',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String target,
    required String otp,
    required String password,
  }) async {
    try {
      final res = await client
          .post(
            Uri.parse('$base/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'target': target,
              'otp': otp,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'message': 'Không kết nối được backend. Vui lòng thử lại.',
      };
    }
  }

  Future<Map<String, String>> getAuthHeaders({
    bool forceRefresh = false,
  }) async {
    if (_token == null || forceRefresh) {
      try {
        FrontendLogger.write('[LocalService] Refreshing local companion token');
        await connect();
        FrontendLogger.write(
          '[LocalService] Local companion token refreshed successfully',
        );
      } catch (e) {
        FrontendLogger.write('[LocalService] Failed to bootstrap token: $e');
      }
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) {
      headers['X-Companion-Token'] = _token!;
    }
    return headers;
  }

  void dispose() => client.close();
}
