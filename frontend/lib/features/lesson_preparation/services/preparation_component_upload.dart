import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/models/preparation_document.dart';
import 'preparation_api.dart';

/// A dedicated client lets cancellation close only this upload connection.
class PreparationComponentUpload {
  PreparationComponentUpload({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  bool _cancelled = false;

  Future<PreparationMap> send(
    PreparationApi api,
    PlatformFile file, {
    required void Function(int sent, int total) onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Cài gói thành phần lớn cần bản Windows để truyền file theo luồng.',
      );
    }
    final length = await file.length();
    if (length == null || length <= 0 || length > 8 * 1024 * 1024 * 1024) {
      throw StateError('Gói thành phần phải từ 1 byte đến 8 GB.');
    }
    final request = _ProgressMultipart(
      Uri.parse('${api.base}/api/preparation/components/install'),
      onProgress,
    );
    request.headers.addAll(await api.headers());
    request.files.add(
      http.MultipartFile(
        'file',
        file.readAsByteStream(),
        length,
        filename: file.name,
      ),
    );
    if (_cancelled) throw StateError('Đã hủy tải gói.');
    // Never retry this POST automatically: the installation may already exist.
    final response = api.check(
      await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(hours: 2)),
      ).timeout(const Duration(minutes: 2)),
    );
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  void cancel() {
    _cancelled = true;
    _client.close();
  }

  void close() => _client.close();
}

class _ProgressMultipart extends http.MultipartRequest {
  _ProgressMultipart(Uri uri, this.progress) : super('POST', uri);
  final void Function(int, int) progress;
  @override
  http.ByteStream finalize() {
    final stream = super.finalize();
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      stream.map((chunk) {
        sent += chunk.length;
        progress(sent, total);
        return chunk;
      }),
    );
  }
}
