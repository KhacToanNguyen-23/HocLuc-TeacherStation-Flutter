import 'google_workspace_api.dart';
import 'url_opener.dart';

/// OAuth stays in the system browser; only the verified identity returns to UI.
class GoogleConnectionFlow {
  static Future<String> connect(
    GoogleWorkspaceApi api, {
    required bool Function() isActive,
    bool forceConsent = false,
    bool reuseExisting = false,
  }) async {
    if (reuseExisting && !forceConsent && api.email.isNotEmpty) {
      final status = await api.call('status');
      if (status['connected'] == true &&
          status['email'] is String &&
          (status['email'] as String).isNotEmpty) {
        return status['email'] as String;
      }
      if ({
        'TEMPORARY_ERROR',
        'CONFIG_ERROR',
        'NOT_CONFIGURED',
      }.contains(status['state'])) {
        throw StateError(
          'Chưa kiểm tra được kết nối Google. Vui lòng thử lại hoặc kiểm tra cấu hình ứng dụng.',
        );
      }
    }
    final flow = await api.call(
      'connect',
      post: true,
      body: {'email': api.email, 'forceConsent': forceConsent},
    );
    await openExternalUrl(flow['authorizationUrl'] as String);
    while (isActive() &&
        DateTime.now().millisecondsSinceEpoch < (flow['expiresAt'] as num)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!isActive()) break;
      final result = await api.call(
        'poll',
        post: true,
        body: {'state': flow['state'], 'pollToken': flow['pollToken']},
      );
      if (result['status'] == 'COMPLETE') return result['email'] as String;
    }
    throw StateError('Phiên kết nối đã kết thúc. Vui lòng thử lại.');
  }
}
