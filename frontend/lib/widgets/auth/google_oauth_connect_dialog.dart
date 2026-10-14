import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/google_meet_auth_service.dart';
import '../../services/google_oauth_client.dart';

class GoogleOAuthConnectDialog extends StatefulWidget {
  const GoogleOAuthConnectDialog({super.key, required this.authService});
  final GoogleMeetAuthService authService;

  static Future<bool?> show(
    BuildContext context, {
    GoogleMeetAuthService? authService,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => GoogleOAuthConnectDialog(
        authService: authService ?? GoogleMeetAuthService(),
      ),
    );
  }

  @override
  State<GoogleOAuthConnectDialog> createState() =>
      _GoogleOAuthConnectDialogState();
}

class _GoogleOAuthConnectDialogState extends State<GoogleOAuthConnectDialog> {
  GoogleOAuthClient? _client;
  bool _waiting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    await _client?.dispose();
    if (!mounted) return;
    final client = GoogleOAuthClient();
    _client = client;
    setState(() {
      _waiting = true;
      _error = null;
    });
    try {
      final result = await client.connect(
        loginHint:
            widget.authService.googleEmail ?? widget.authService.teacherEmail,
      );
      if (!mounted) return;
      final user = result['user'] as Map<String, dynamic>;
      widget.authService.connectGoogleSession(
        sessionId: result['sessionId'] as String,
        name: user['name'] as String?,
        email: user['email'] as String?,
        avatar: user['avatar'] as String?,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _waiting = false;
          _error = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_client?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kết nối Google Meet'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn tài khoản Google của giáo viên trong trình duyệt và cho phép tạo phòng Meet. Sau khi hoàn tất, quay lại app.',
              ),
              const SizedBox(height: 16),
              if (_waiting)
                const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text('Đang chờ bạn cấp quyền Google…')),
                  ],
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        if (!_waiting)
          FilledButton(onPressed: _connect, child: const Text('Thử lại')),
      ],
    );
  }
}
