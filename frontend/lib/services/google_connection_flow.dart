import 'google_workspace_api.dart';
import 'url_opener.dart';

/// OAuth stays in the system browser; only the verified identity returns to UI.
class GoogleConnectionFlow {
  static Future<String> connect(
    GoogleWorkspaceApi api, {
    required bool Function() isActive,
    bool forceConsent = false,
    bool reuseExisting = false,
    Future<void> Function(String)? openBrowser,
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
    await (openBrowser ?? openExternalUrl)(flow['authorizationUrl'] as String);
    while (isActive() &&
        DateTime.now().millisecondsSinceEpoch < (flow['expiresAt'] as num)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!isActive()) break;
      late Map<String, dynamic> result;
      try {
        result = await api.call(
          'poll',
          post: true,
          body: {'state': flow['state'], 'pollToken': flow['pollToken']},
        );
      } on GoogleWorkspaceFailure catch (error) {
        // Google may omit a refresh token for an old grant that this install
        // no longer holds. Repair once; cancellation/network errors never loop.
        if (!forceConsent && isActive() && error.code == 'REFRESH_MISSING') {
          return connect(
            api,
            isActive: isActive,
            forceConsent: true,
            openBrowser: openBrowser,
          );
        }
        rethrow;
      }
      if (result['status'] == 'COMPLETE') return result['email'] as String;
    }
    throw StateError('Phiên kết nối đã kết thúc. Vui lòng thử lại.');
  }
}
