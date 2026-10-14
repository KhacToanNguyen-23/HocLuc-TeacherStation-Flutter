import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import '../../services/google_meet_auth_service.dart';
import '../../services/meet_automation_service.dart';
import '../../services/url_opener.dart';

/// Official Meet UI is the authority for admission and participant controls.
/// OAuth does not sign the teacher into this separate WebView browser session.
class GoogleMeetPanelDialog extends StatefulWidget {
  const GoogleMeetPanelDialog({super.key, required this.meetService, this.createRoom = false});
  final MeetAutomationService meetService;
  final bool createRoom;

  static Future<void> show(
    BuildContext context, {
    MeetAutomationService? meetService,
    bool createRoom = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => GoogleMeetPanelDialog(
        meetService: meetService ?? MeetAutomationService(),
        createRoom: createRoom,
      ),
    );
  }

  @override
  State<GoogleMeetPanelDialog> createState() => _GoogleMeetPanelDialogState();
}

class _GoogleMeetPanelDialogState extends State<GoogleMeetPanelDialog> {
  bool _loading = true;
  bool _startedCreation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.createRoom && !_startedCreation) {
        await widget.meetService.beginCookieRoomCreation();
        _startedCreation = true;
      } else if (!widget.meetService.isCreatingCookieRoom) {
        await widget.meetService.openMeetingPanel();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    // Keep the controller/page alive after an established room is hidden.
    // Cancelling a login before obtaining a room must not leave "creating" stuck.
    widget.meetService.cancelCookieRoomCreation();
    super.dispose();
  }

  Future<win.WebviewPermissionDecision> _permission(
    String url,
    win.WebviewPermissionKind kind,
    bool userInitiated,
  ) async {
    if (!mounted || Uri.tryParse(url)?.host != 'meet.google.com') {
      return win.WebviewPermissionDecision.deny;
    }
    if (kind != win.WebviewPermissionKind.camera &&
        kind != win.WebviewPermissionKind.microphone) {
      return win.WebviewPermissionDecision.none;
    }
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          kind == win.WebviewPermissionKind.camera
              ? 'Cho Google Meet dùng camera?'
              : 'Cho Google Meet dùng micro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Từ chối'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cho phép'),
          ),
        ],
      ),
    );
    return allowed == true
        ? win.WebviewPermissionDecision.allow
        : win.WebviewPermissionDecision.deny;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final service = widget.meetService;
    final email = service.accessType == 'OPEN' ? GoogleMeetAuthService().googleEmail : null;
    final controller = service.webviewController;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: (size.width - 32).clamp(0, 1180).toDouble(),
        height: (size.height - 32).clamp(0, 820).toDouble(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.video_call_outlined),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Google Meet',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mở cùng phòng trong trình duyệt',
                    onPressed: service.meetingUrl == null
                        ? null
                        : () async {
                            try {
                              await openExternalUrl(service.meetingUrl!);
                            } catch (e) {
                              if (mounted) {
                                setState(
                                  () => _error =
                                      'Không mở được trình duyệt. Hãy sao chép link phòng.',
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.open_in_new),
                  ),
                  IconButton(
                    tooltip: 'Đóng panel',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  email == null
                      ? 'Đăng nhập Google trong panel nếu cần và chọn Tham gia ngay. Sau đó dùng Meet để quản lý học sinh.'
                      : 'Đăng nhập trong panel bằng $email để quản lý phòng. Chọn Tham gia ngay khi sẵn sàng.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : controller != null
                  ? win.Webview(controller, permissionRequested: _permission)
                  : const Center(
                      child: Text('Chưa mở được panel Google Meet.'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
