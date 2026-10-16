
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'google_workspace_api.dart';
import 'url_opener.dart';
import '../widgets/auth/google_webview_login_dialog.dart';

/// Zero-click in-app OAuth flow via Edge WebView2 on Windows Desktop, with fallback to system browser.
class GoogleConnectionFlow {
  static Future<String> connect(
    GoogleWorkspaceApi api, {
    BuildContext? context,
    required bool Function() isActive,
    bool forceConsent = false,
  }) async {
    final flow = await api.call(
      'connect',
      post: true,
      body: {'email': api.email, 'forceConsent': forceConsent},
    );
    final authUrl = flow['authorizationUrl'] as String;

    // 1. In-app WebView2 Dialog on Windows Desktop (Zero external clicks)
    if (context != null && !kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      if (!context.mounted) throw StateError('Giao diện không còn khả dụng.');
      bool dialogClosed = false;
      final dialogFuture = GoogleWebviewLoginDialog.show(
        context,
        initialUrl: authUrl,
      ).then((val) {
        dialogClosed = true;
        return val;
      });

      // Poll until backend receives callback or dialog is dismissed
      while (isActive() && !dialogClosed && DateTime.now().millisecondsSinceEpoch < (flow['expiresAt'] as num)) {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        if (!isActive() || dialogClosed) break;
        try {
          final result = await api.call('poll', post: true, body: {
            'state': flow['state'],
            'pollToken': flow['pollToken'],
          });
          if (result['status'] == 'COMPLETE') {
            if (!dialogClosed && context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(result['email'] as String);
            }
            return result['email'] as String;
          }
        } catch (_) {}
      }

      await dialogFuture;

      // Final check: poll one more time in case dialog completed right as callback arrived
      try {
        final result = await api.call('poll', post: true, body: {
          'state': flow['state'],
          'pollToken': flow['pollToken'],
        });
        if (result['status'] == 'COMPLETE') {
          return result['email'] as String;
        }
      } catch (_) {}

      throw StateError('Phiên kết nối Google chưa hoàn tất hoặc đã bị đóng.');
    }

    // 2. Fallback to System Browser (Web or other platforms)
    await openExternalUrl(authUrl);
    while (isActive() && DateTime.now().millisecondsSinceEpoch < (flow['expiresAt'] as num)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!isActive()) break;
      final result = await api.call('poll', post: true, body: {
        'state': flow['state'],
        'pollToken': flow['pollToken'],
      });
      if (result['status'] == 'COMPLETE') return result['email'] as String;
    }
    throw StateError('Phiên kết nối đã kết thúc. Vui lòng thử lại.');
  }
}
