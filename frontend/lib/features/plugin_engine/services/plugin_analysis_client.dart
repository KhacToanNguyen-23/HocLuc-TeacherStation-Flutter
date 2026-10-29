import 'dart:convert';

import 'package:http/http.dart' as http;

/// Calls a plugin-owned text analysis API through its loopback sidecar port.
/// The host treats analysis fields and annotation styles as opaque data.
class PluginAnalysisClient {
  PluginAnalysisClient({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> analyze({
    required int port,
    required String text,
    required String requestId,
    required String selectionToken,
  }) async {
    final response = await _client
        .post(
          Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: port,
            path: '/api/analyze',
          ),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'schemaVersion': 1,
            'requestId': requestId,
            'selectionToken': selectionToken,
            'source': {
              'kind': 'text',
              'text': text,
              'offsetUnit': 'unicodeCodePoint',
            },
          }),
        )
        .timeout(const Duration(seconds: 10));

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid analysis response.');
    }
    final result = Map<String, dynamic>.from(decoded);
    if (response.statusCode != 200 || result['status'] != 'complete') {
      throw StateError(
        'Plugin analysis failed (${result['error'] ?? result['status']}).',
      );
    }
    if (result['schemaVersion'] != 1 ||
        result['requestId'] != requestId ||
        result['selectionToken'] != selectionToken ||
        result['offsetUnit'] != 'unicodeCodePoint') {
      throw const FormatException(
        'Analysis response does not match the request.',
      );
    }
    final spans = result['spans'];
    final sourceRunes = text.runes.toList(growable: false);
    final sourceLength = sourceRunes.length;
    if (spans is! List) {
      throw const FormatException('Analysis spans are missing.');
    }
    for (final rawSpan in spans) {
      if (rawSpan is! Map) {
        throw const FormatException('Invalid analysis span.');
      }
      final span = Map<String, dynamic>.from(rawSpan);
      final start = span['start'];
      final end = span['end'];
      if (start is! int ||
          end is! int ||
          start < 0 ||
          end <= start ||
          end > sourceLength) {
        throw const FormatException(
          'Analysis span is outside the selected text.',
        );
      }
      final spanText = span['text'];
      final expectedText = String.fromCharCodes(
        sourceRunes.sublist(start, end),
      );
      if (spanText is! String || spanText != expectedText) {
        throw const FormatException(
          'Analysis span text does not match its offsets.',
        );
      }
      if (span['style'] is! Map) {
        throw const FormatException('Analysis span style is missing.');
      }
    }
    return result;
  }

  void close() => _client.close();
}
