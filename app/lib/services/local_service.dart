import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocalService {
  LocalService({http.Client? client, String? base})
    : base =
          base ??
          (configuredBase.isNotEmpty
              ? configuredBase
              : kIsWeb
              ? Uri.base.origin
              : 'http://127.0.0.1:47831'),
      client = client ?? http.Client();
  static const configuredBase = String.fromEnvironment('COMPANION_SERVICE');
  final http.Client client;
  final String base;
  String? _token;
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

  void dispose() => client.close();
}
