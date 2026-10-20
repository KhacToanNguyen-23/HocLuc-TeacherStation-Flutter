import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:teaching_companion/core/network/local_service.dart';

class GoogleWorkspaceFailure extends StateError {
  GoogleWorkspaceFailure(this.code, String message, {this.status = 0})
    : super(message);
  final String code;
  final int status;
  bool get needsConsent => const {
    'RECONNECT_GOOGLE',
    'GOOGLE_401',
    'SCOPE_MISSING',
    'REFRESH_MISSING',
  }.contains(code);
  bool get temporary =>
      const {
        'GOOGLE_NETWORK',
        'GOOGLE_TEMPORARY',
        'GOOGLE_RATE_LIMIT',
      }.contains(code) ||
      status >= 500 && code != 'GOOGLE_CLIENT_CONFIG';
}

/// Local provider bridge. Google credentials never leave the companion backend.
class GoogleWorkspaceApi {
  GoogleWorkspaceApi({required this.email, http.Client? client, String? base})
    : _local = LocalService(client: client, base: base);

  final String email;
  final LocalService _local;
  void close() => _local.client.close();

  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? body,
    bool post = false,
    String? method,
    bool retryLocalSession = true,
  }) async {
    if (_local.companionToken == null) await _local.connect();
    final uri = Uri.parse('${_local.base}/api/integrations/google/$path');
    final headers = {
      'X-Companion-Token': _local.companionToken!,
      'X-Google-Teacher-Email': email,
      'Content-Type': 'application/json',
    };
    late http.Response response;
    try {
      if (method == null) {
        response =
            await (post
                    ? _local.client.post(
                        uri,
                        headers: headers,
                        body: jsonEncode(body ?? {}),
                      )
                    : _local.client.get(uri, headers: headers))
                .timeout(const Duration(minutes: 4));
      } else {
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) request.body = jsonEncode(body);
        final streamed = await _local.client
            .send(request)
            .timeout(const Duration(minutes: 4));
        response = await http.Response.fromStream(
          streamed,
        ).timeout(const Duration(minutes: 4));
      }
    } on TimeoutException {
      throw GoogleWorkspaceFailure(
        'GOOGLE_NETWORK',
        'Kết nối quá lâu. Kiểm tra mạng rồi thử lại; chưa cần cấp quyền lại.',
      );
    } on http.ClientException {
      throw GoogleWorkspaceFailure(
        'GOOGLE_NETWORK',
        'Không kết nối được dịch vụ. Kiểm tra mạng và thử lại.',
      );
    }
    Map<String, dynamic> data;
    try {
      data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw StateError('Dịch vụ chưa trả kết quả hợp lệ. Tải lại để kiểm tra.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 &&
          retryLocalSession &&
          data['error'] == 'Local session required') {
        await _local.connect();
        return call(
          path,
          body: body,
          post: post,
          method: method,
          retryLocalSession: false,
        );
      }
      throw GoogleWorkspaceFailure(
        data['code'] as String? ?? 'REQUEST_FAILED',
        data['message'] as String? ??
            'Không hoàn tất thao tác (${response.statusCode}).',
        status: response.statusCode,
      );
    }
    return data;
  }

  static String requestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static List<String> parseEmails(String text) {
    final values = text
        .split(RegExp(r'[\s,;]+'))
        .where((e) => e.isNotEmpty)
        .map((e) => e.toLowerCase())
        .toSet()
        .toList();
    if (values.length > 50) {
      throw const FormatException('Mỗi lần mời tối đa 50 email.');
    }
    if (values.any(
      (e) =>
          e.length > 320 || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e),
    )) {
      throw const FormatException(
        'Có email chưa hợp lệ. Kiểm tra lại danh sách.',
      );
    }
    return values;
  }
}

