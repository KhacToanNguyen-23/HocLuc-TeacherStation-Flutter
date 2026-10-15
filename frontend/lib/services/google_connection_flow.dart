import 'google_workspace_api.dart';
import 'url_opener.dart';

/// OAuth stays in the system browser; only the verified identity returns to UI.
class GoogleConnectionFlow {
  static Future<String> connect(
    GoogleWorkspaceApi api, {
    required bool Function() isActive,
    bool forceConsent = false,
  }) async {
    final flow = await api.call('connect', post: true, body: {'email': api.email, 'forceConsent': forceConsent});
    await openExternalUrl(flow['authorizationUrl'] as String);
    while (isActive() && DateTime.now().millisecondsSinceEpoch < (flow['expiresAt'] as num)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!isActive()) break;
      final result = await api.call('poll', post: true, body: {
        'state': flow['state'], 'pollToken': flow['pollToken'],
      });
      if (result['status'] == 'COMPLETE') return result['email'] as String;
    }
    throw StateError('Phiên kết nối đã kết thúc. Vui lòng thử lại.');
  }
}
