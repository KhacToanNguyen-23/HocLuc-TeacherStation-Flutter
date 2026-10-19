import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import '../services/meet_automation_service.dart';
import '../constants/theme.dart';

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
            'Phòng Meet trong ứng dụng cần HocLucStation trên Windows và WebView2.',
          ),
        ),
      );
    }
    if (controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: service.errorMessage != null
              ? Text(
                  service.errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                )
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListenableBuilder(
            listenable: service,
            builder: (context, _) => Row(
              children: [
                Icon(
                  service.isScreenSharing
                      ? Icons.screen_share
                      : Icons.present_to_all,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service.isScreenSharing
                        ? 'Đang chia sẻ màn hình'
                        : 'Bấm Trình bày ngay trong Meet, chọn cửa sổ hoặc màn hình rồi bấm Chia sẻ.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: win.Webview(controller)),
      ],
    );
  }
}
