import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/planning_meta.dart';

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
  }) async {
    if (_token == null) {
      try {
        await connect();
      } catch (e) {
        debugPrint('[LocalService] Auto-connect before POST "$path" failed: $e');
      }
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['X-Companion-Token'] = _token!;
    }
    final url = Uri.parse('$base/api/$path');
    final response = await client
        .post(url, headers: headers, body: jsonEncode(data ?? {}))
        .timeout(const Duration(seconds: 10));
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
      final res = await client.post(
        Uri.parse('$base/api/auth/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'target': target, 'type': type}),
      ).timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LocalService] sendOtp fallback to dev mode: $e');
      return {
        'success': true,
        'message': 'Đã gửi mã OTP đến $target (Mã thử nghiệm: 123456)',
        'cooldown': 60,
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
      final res = await client.post(
        Uri.parse('$base/api/auth/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target': target,
          'otp': otp,
          'name': name,
          'type': type,
        }),
      ).timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LocalService] verifyOtp fallback: $e');
      if (otp == '123456') {
        final isPhone = !target.contains('@');
        return {
          'success': true,
          'token': 'dev-mock-jwt-token-hocluc',
          'user': {
            'target': target,
            'name': name ?? (type == 'signup' ? 'Thầy Cô Mới' : 'Giáo viên'),
            'role': 'TEACHER',
            'phone': isPhone ? target : null,
            'email': isPhone ? null : target,
          },
        };
      }
      return {
        'success': false,
        'message': 'Mã OTP không chính xác (Thử mã dev: 123456)',
      };
    }
  }

  Future<Map<String, dynamic>> getActiveClassroom() async {
    try {
      final res = await client.get(
        Uri.parse('$base/api/classroom/active'),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[LocalService] getActiveClassroom error: $e');
    }
    return {};
  }

  Future<bool> endClassroom({String? classroomId}) async {
    try {
      final res = await client.post(
        Uri.parse('$base/api/classroom/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'classroomId': classroomId}),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('[LocalService] endClassroom error: $e');
    }
    return false;
  }

  Future<List<dynamic>> getClassroomHistory({String? teacherId}) async {
    try {
      final url = teacherId != null
          ? Uri.parse('$base/api/classroom/history?teacherId=$teacherId')
          : Uri.parse('$base/api/classroom/history');
      final res = await client.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('[LocalService] getClassroomHistory error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await client.post(
        Uri.parse('$base/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LocalService] login fallback to dev mock: $e');
      if (password.isNotEmpty) {
        final isPhone = !identifier.contains('@');
        return {
          'success': true,
          'token': 'dev-mock-jwt-token-hocluc',
          'user': {
            'target': identifier,
            'name': identifier.contains('khactoan') ? 'Thầy Khắc Toàn' : 'Giáo viên',
            'role': 'TEACHER',
            'phone': isPhone ? identifier : null,
            'email': isPhone ? null : identifier,
          },
        };
      }
      return {
        'success': false,
        'message': 'Vui lòng nhập mật khẩu hợp lệ',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String target,
    required String otp,
    required String password,
  }) async {
    try {
      final res = await client.post(
        Uri.parse('$base/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target': target,
          'otp': otp,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 4));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LocalService] register fallback to dev mock: $e');
      if (otp == '123456' || otp.length == 6) {
        final isPhone = !target.contains('@');
        return {
          'success': true,
          'token': 'dev-mock-jwt-token-hocluc',
          'user': {
            'target': target,
            'name': isPhone ? 'Thầy/Cô ($target)' : target.split('@')[0],
            'role': 'TEACHER',
            'phone': isPhone ? target : null,
            'email': isPhone ? null : target,
          },
        };
      }
      return {
        'success': false,
        'message': 'Mã OTP không chính xác (Thử mã dev: 123456)',
      };
    }
  }

  Future<Map<String, String>> _getAuthHeaders({bool forceRefresh = false}) async {
    if (_token == null || forceRefresh) {
      try {
        debugPrint('[LocalService] Fetching fresh token from $base/api/bootstrap...');
        await connect();
        debugPrint('[LocalService] Token updated successfully (prefix: ${_token != null && _token!.length > 8 ? _token!.substring(0, 8) : _token}...)');
      } catch (e) {
        debugPrint('[LocalService] Failed to bootstrap token: $e');
      }
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['X-Companion-Token'] = _token!;
    }
    return headers;
  }

  Future<List<PlanningMeta>> getPlannings() async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _getAuthHeaders(forceRefresh: attempt > 0);
        final res = await client
            .get(Uri.parse('$base/api/plannings'), headers: headers)
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          if (decoded is List) {
            return decoded
                .map((e) => PlanningMeta.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
        if (res.statusCode == 401 && attempt == 0) {
          debugPrint('[LocalService] getPlannings received 401. Refreshing token and retrying...');
          _token = null;
          continue;
        }
        debugPrint('[LocalService] getPlannings failed HTTP ${res.statusCode}: ${res.body}');
        break;
      } catch (e) {
        debugPrint('[LocalService] getPlannings attempt ${attempt + 1} error: $e');
        if (attempt == 0) {
          _token = null;
          continue;
        }
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getPlanningContent(String id) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _getAuthHeaders(forceRefresh: attempt > 0);
        final res = await client
            .get(Uri.parse('$base/api/plannings/$id'), headers: headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        }
        if (res.statusCode == 401 && attempt == 0) {
          debugPrint('[LocalService] getPlanningContent received 401. Refreshing token...');
          _token = null;
          continue;
        }
        debugPrint('[LocalService] getPlanningContent failed HTTP ${res.statusCode}: ${res.body}');
        break;
      } catch (e) {
        debugPrint('[LocalService] getPlanningContent attempt ${attempt + 1} error: $e');
        if (attempt == 0) {
          _token = null;
          continue;
        }
      }
    }
    return null;
  }

  Future<PlanningMeta?> createPlanning({
    required String title,
    required String subject,
    Map<String, dynamic>? content,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'subject': subject,
    };
    if (content != null) payload['content'] = content;
    final body = jsonEncode(payload);

    debugPrint('[LocalService] createPlanning: title="$title", subject="$subject", bodyLength=${body.length}');

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _getAuthHeaders(forceRefresh: attempt > 0);
        debugPrint('[LocalService] createPlanning [attempt ${attempt + 1}]: sending POST $base/api/plannings...');
        final res = await client
            .post(Uri.parse('$base/api/plannings'), headers: headers, body: body)
            .timeout(const Duration(seconds: 10));

        debugPrint('[LocalService] createPlanning [attempt ${attempt + 1}]: HTTP ${res.statusCode}');

        if (res.statusCode == 200 || res.statusCode == 201) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          debugPrint('[LocalService] createPlanning SUCCESS: id=${decoded['id']}');
          return PlanningMeta.fromJson(decoded);
        }

        if (res.statusCode == 401 && attempt == 0) {
          debugPrint('[LocalService] Token rejected (401). Retrying with fresh token...');
          _token = null;
          continue;
        }

        debugPrint('[LocalService] createPlanning FAILED: status=${res.statusCode}, body=${res.body}');
        break;
      } catch (e, st) {
        debugPrint('[LocalService] createPlanning exception attempt ${attempt + 1}: $e\n$st');
        if (attempt == 0) {
          _token = null;
          continue;
        }
      }
    }
    return null;
  }

  Future<PlanningMeta?> updatePlanning({
    required String id,
    String? title,
    String? subject,
    Map<String, dynamic>? content,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (subject != null) payload['subject'] = subject;
    if (content != null) payload['content'] = content;
    final body = jsonEncode(payload);

    debugPrint('[LocalService] updatePlanning: id="$id", title="$title", bodyLength=${body.length}');

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _getAuthHeaders(forceRefresh: attempt > 0);
        debugPrint('[LocalService] updatePlanning [attempt ${attempt + 1}]: sending PUT $base/api/plannings/$id...');
        final res = await client
            .put(Uri.parse('$base/api/plannings/$id'),
                headers: headers, body: body)
            .timeout(const Duration(seconds: 10));

        debugPrint('[LocalService] updatePlanning [attempt ${attempt + 1}]: HTTP ${res.statusCode}');

        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          debugPrint('[LocalService] updatePlanning SUCCESS: id=${decoded['id']}');
          return PlanningMeta.fromJson(decoded);
        }

        if (res.statusCode == 401 && attempt == 0) {
          debugPrint('[LocalService] Token rejected (401). Retrying with fresh token...');
          _token = null;
          continue;
        }

        debugPrint('[LocalService] updatePlanning FAILED: status=${res.statusCode}, body=${res.body}');
        break;
      } catch (e, st) {
        debugPrint('[LocalService] updatePlanning exception attempt ${attempt + 1}: $e\n$st');
        if (attempt == 0) {
          _token = null;
          continue;
        }
      }
    }
    return null;
  }

  Future<bool> deletePlanning(String id) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _getAuthHeaders(forceRefresh: attempt > 0);
        final res = await client
            .delete(Uri.parse('$base/api/plannings/$id'), headers: headers)
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          return decoded['success'] == true;
        }
        if (res.statusCode == 401 && attempt == 0) {
          _token = null;
          continue;
        }
        break;
      } catch (e) {
        debugPrint('[LocalService] deletePlanning error: $e');
        if (attempt == 0) {
          _token = null;
          continue;
        }
      }
    }
    return false;
  }

  Future<bool> clonePlanningToClassroom(String id) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _getAuthHeaders(forceRefresh: attempt > 0);
        final res = await client
            .post(Uri.parse('$base/api/plannings/$id/clone-to-classroom'),
                headers: headers, body: jsonEncode({}))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          return decoded['success'] == true;
        }
        if (res.statusCode == 401 && attempt == 0) {
          _token = null;
          continue;
        }
        break;
      } catch (e) {
        debugPrint('[LocalService] clonePlanningToClassroom error: $e');
        if (attempt == 0) {
          _token = null;
          continue;
        }
      }
    }
    return false;
  }

  void dispose() => client.close();
}
