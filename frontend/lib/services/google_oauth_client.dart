import 'dart:async';
import 'local_service.dart';
import 'url_opener.dart';

/// Opens Google's authorization page in the system browser. The backend owns
/// PKCE, the loopback callback and all provider tokens.
class GoogleOAuthClient {
  GoogleOAuthClient({
    LocalService? localService,
    Future<void> Function(String)? openUrl,
  }) : _local = localService ?? LocalService(),
       _ownsLocal = localService == null,
       _openUrl = openUrl ?? openExternalUrl;

  final LocalService _local;
  final bool _ownsLocal;
  final Future<void> Function(String) _openUrl;
  String? _flowId;
  bool _cancelled = false;

  Future<Map<String, dynamic>> connect({String? loginHint}) async {
    final start = await _local.post(
      'google/oauth/start',
      data: {'loginHint': ?loginHint},
    );
    if (start['success'] != true) {
      throw StateError(
        start['error']?.toString() ?? 'Không khởi tạo được kết nối Google.',
      );
    }
    _flowId = start['flowId'] as String;
    if (_cancelled) {
      await cancel();
      throw StateError('Đã hủy kết nối Google.');
    }
    final authorizationUrl = Uri.parse(start['authorizationUrl'] as String);
    if (authorizationUrl.scheme != 'https' ||
        authorizationUrl.host != 'accounts.google.com') {
      throw StateError('Đường dẫn cấp quyền Google không hợp lệ.');
    }
    await _openUrl(authorizationUrl.toString());
    final deadline = DateTime.now().add(
      Duration(seconds: (start['expiresIn'] as num?)?.toInt() ?? 300),
    );
    while (!_cancelled && DateTime.now().isBefore(deadline)) {
      final status = await _local.post(
        'google/oauth/status',
        data: {'flowId': _flowId},
      );
      if (_cancelled) break;
      if (status['status'] == 'CONNECTED' && status['success'] == true) {
        _flowId =
            null; // Closing the dialog after success must not cancel the grant.
        return status;
      }
      if (status['success'] != true) {
        throw StateError(
          status['error']?.toString() ?? 'Chưa hoàn tất cấp quyền Google.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError(
      _cancelled
          ? 'Đã hủy kết nối Google.'
          : 'Kết nối Google đã hết thời gian chờ.',
    );
  }

  Future<void> cancel() async {
    _cancelled = true;
    final flowId = _flowId;
    _flowId = null;
    if (flowId != null) {
      try {
        await _local.post('google/oauth/cancel', data: {'flowId': flowId});
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await cancel();
    if (_ownsLocal) _local.client.close();
  }
}
