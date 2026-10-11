import 'package:flutter/material.dart';
import '../../services/google_meet_auth_service.dart';

class GoogleSignInDialog extends StatefulWidget {
  const GoogleSignInDialog({super.key, required this.authService});

  final GoogleMeetAuthService authService;

  static Future<void> show(
    BuildContext context,
    GoogleMeetAuthService authService,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => GoogleSignInDialog(authService: authService),
    );
  }

  @override
  State<GoogleSignInDialog> createState() => _GoogleSignInDialogState();
}

class _GoogleSignInDialogState extends State<GoogleSignInDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.authService.teacherEmail ?? '',
    );
    _nameController = TextEditingController(
      text: widget.authService.teacherName ?? '',
    );
    _tokenController = TextEditingController(
      text: widget.authService.accessToken ?? '',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.account_circle, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text(
            'Tài khoản Google Giáo Viên',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đăng nhập tài khoản Google để phòng Google Meet được cấp tự động với quyền Host chính chủ của bạn:',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email trường / cá nhân',
                hintText: 'ví dụ: toan.nguyen@fpt.edu.vn',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên giáo viên hiển thị',
                hintText: 'ví dụ: Thầy Toàn',
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'OAuth Access Token (Tùy chọn)',
                hintText: 'Dán token Google Calendar API nếu có',
                prefixIcon: Icon(Icons.key_outlined, size: 18),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_tokenController.text.trim().isNotEmpty) {
              widget.authService.signInWithGoogleToken(
                accessToken: _tokenController.text.trim(),
                name: _nameController.text.trim().isNotEmpty
                    ? _nameController.text.trim()
                    : null,
                email: _emailController.text.trim().isNotEmpty
                    ? _emailController.text.trim()
                    : null,
              );
            } else {
              widget.authService.quickSignIn(
                name: _nameController.text.trim().isNotEmpty
                    ? _nameController.text.trim()
                    : null,
                email: _emailController.text.trim().isNotEmpty
                    ? _emailController.text.trim()
                    : null,
              );
            }
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: const Text('Lưu & Đăng nhập'),
        ),
      ],
    );
  }
}
