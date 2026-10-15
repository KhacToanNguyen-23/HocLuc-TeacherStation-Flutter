import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import '../services/meet_automation_service.dart';

/// Uses the existing Meet controller/cookies; never creates a second session.
class GoogleMeetView extends StatelessWidget {
  const GoogleMeetView({super.key, required this.service});
  final MeetAutomationService service;
  @override
  Widget build(BuildContext context) {
    final controller = service.webviewController;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Phòng Meet trong ứng dụng cần HocLuc trên Windows và WebView2.',
          ),
        ),
      );
    }
    if (controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: service.errorMessage != null
              ? Text(service.errorMessage!)
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang mở phòng Meet…'),
                  ],
                ),
        ),
      );
    }
    return win.Webview(controller);
  }
}
