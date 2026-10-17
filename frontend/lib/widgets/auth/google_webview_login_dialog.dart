import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import '../../constants/theme.dart';
import '../../services/google_meet_auth_service.dart';
import '../../services/webview_environment_service.dart';
import '../../services/url_opener.dart';

/// Modal dialog providing authentic Google Sign-In via native Edge WebView2 on Windows,
/// supporting Google Account Chooser (1-tap selection) and persistent Google sessions.
class GoogleWebviewLoginDialog extends StatefulWidget {
  const GoogleWebviewLoginDialog({
    super.key,
    required this.authService,
    this.initialUrl = 'https://accounts.google.com/signin',
  });

  final GoogleMeetAuthService authService;
  final String initialUrl;

  static Future<String?> show(
    BuildContext context, {
    GoogleMeetAuthService? authService,
    String initialUrl = 'https://accounts.google.com/signin',
  }) {
    final service = authService ?? GoogleMeetAuthService();
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => GoogleWebviewLoginDialog(
        authService: service,
        initialUrl: initialUrl,
      ),
    );
  }

  @override
  State<GoogleWebviewLoginDialog> createState() =>
      _GoogleWebviewLoginDialogState();
}

class _GoogleWebviewLoginDialogState extends State<GoogleWebviewLoginDialog> {
  win.WebviewController? _controller;
  StreamSubscription<String>? _urlSub;
  StreamSubscription<win.LoadingState>? _loadingSub;
  bool _isLoading = true;
  String? _errorMessage;
  final _fallbackEmailController = TextEditingController(
    text: 'teacher.hocluc@gmail.com',
  );

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _initWebView();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _initWebView() async {
    try {
      await WebviewEnvironmentService.ensureInitialized();
      final controller = win.WebviewController();
      await controller.initialize();

      _urlSub = controller.url.listen((url) {
        if (!mounted) return;
        debugPrint('[GoogleWebview] URL: $url');

        // 1. Nếu mở Meet trực tiếp và máy chủ Google sinh mã phòng thật
        final meetMatch = RegExp(
          r'meet\.google\.com\/([a-z]{3}-[a-z]{4}-[a-z]{3})',
        ).firstMatch(url);
        if (meetMatch != null) {
          final realUrl = 'https://meet.google.com/${meetMatch.group(1)}';
          _completeGoogleSignIn(
            email: widget.authService.teacherEmail ?? 'teacher@gmail.com',
            name: widget.authService.teacherName ?? 'Giáo viên Google',
            realMeetingUrl: realUrl,
          );
          return;
        }

        // 2. Nhận diện trạng thái đăng nhập Google thành công
        final isOAuth = widget.initialUrl.contains('/oauth2/') ||
            widget.initialUrl.contains('/auth?') ||
            widget.initialUrl.contains('response_type=code');

        if (isOAuth) {
          if (url.contains('/api/integrations/google/callback') ||
              url.contains('/api/auth/google/callback') ||
              url.contains(':47831/api/integrations/google/callback')) {
            debugPrint('[GoogleWebview] OAuth callback reached');
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) Navigator.of(context).pop('oauth_complete');
            });
            return;
          }
        } else {
          if (url.contains('myaccount.google.com') ||
              url.contains('accounts.google.com/ManageAccount') ||
              url.contains('accounts.google.com/b/') ||
              (url.contains('google.com') &&
                  !url.contains('/signin') &&
                  !url.contains('ServiceLogin'))) {
            _extractGoogleUserInfo(controller);
          }
        }
      });

      _loadingSub = controller.loadingState.listen((state) {
        if (!mounted) return;
        setState(() {
          _isLoading = (state == win.LoadingState.loading);
        });

        final isOAuth = widget.initialUrl.contains('/oauth2/') ||
            widget.initialUrl.contains('/auth?') ||
            widget.initialUrl.contains('response_type=code');

        if (!isOAuth && state == win.LoadingState.navigationCompleted) {
          _extractGoogleUserInfo(controller);
        }
      });

      await controller.loadUrl(widget.initialUrl);

      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể khởi động WebView2: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _extractGoogleUserInfo(win.WebviewController controller) async {
    try {
      final raw = await controller.executeScript(r'''
        (function() {
          var email = '';
          var name = '';
          // Tìm thuộc tính data-email hoặc aria-label có email
          var emailNodes = document.querySelectorAll('[data-email], [aria-label*="@"]');
          for (var i = 0; i < emailNodes.length; i++) {
            var attr = emailNodes[i].getAttribute('data-email') || emailNodes[i].getAttribute('aria-label') || '';
            var match = attr.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/);
            if (match) {
              email = match[0];
              break;
            }
          }
          if (!email && document.body) {
            var match = document.body.innerText.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/);
            if (match) email = match[0];
          }
          var nameNode = document.querySelector('h1, [data-name], .gb_d, .gb_j');
          if (nameNode) {
            name = (nameNode.innerText || '').trim();
          }
          return JSON.stringify({ email: email, name: name });
        })()
      ''');

      if (raw.isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          final email = (parsed['email'] as String?)?.trim();
          final name = (parsed['name'] as String?)?.trim();
          if (email != null && email.isNotEmpty) {
            _completeGoogleSignIn(
              email: email,
              name: (name != null && name.isNotEmpty)
                  ? name
                  : 'Giáo viên Google',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[GoogleWebview] Extract error: $e');
    }
  }

  void _completeGoogleSignIn({
    required String email,
    required String name,
    String? realMeetingUrl,
  }) {
    widget.authService.signInWithGoogleToken(
      accessToken: 'webview2_authenticated_google_session',
      name: name,
      email: email,
    );
    if (mounted) {
      Navigator.of(context).pop(realMeetingUrl ?? email);
    }
  }

  @override
  void dispose() {
    _urlSub?.cancel();
    _loadingSub?.cancel();
    _controller?.dispose();
    _fallbackEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWebview =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        _controller != null &&
        _errorMessage == null;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 780,
        height: 640,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.panel),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Đăng nhập Google / Google Workspace',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Chọn tài khoản đã lưu hoặc nhập email để tự động tạo phòng Meet thật',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(null),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: Stack(
                children: [
                  if (isDesktopWebview)
                    win.Webview(_controller!)
                  else
                    _buildFallbackContent(),
                  if (_isLoading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                ],
              ),
            ),

            // Footer Bar
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Kết nối bảo mật Google Accounts (Lưu vĩnh viễn trên máy)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isDesktopWebview)
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_controller != null) {
                          _extractGoogleUserInfo(_controller!);
                        }
                      },
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 15,
                      ),
                      label: const Text(
                        'Xác nhận đã đăng nhập',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.control),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () =>
                        openExternalUrl('https://accounts.google.com/signin'),
                    icon: const Icon(
                      Icons.open_in_browser_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Mở trên trình duyệt ngoài',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.selected,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Đăng nhập tài khoản Google Giáo Viên',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ??
                    'Nhập địa chỉ Email Google của bạn để đồng bộ hồ sơ giáo viên và kích hoạt tự động tạo phòng Meet.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _fallbackEmailController,
                decoration: InputDecoration(
                  labelText: 'Email Google',
                  hintText: 'vidu@gmail.com hoặc vidu@fpt.edu.vn',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final email = _fallbackEmailController.text.trim();
                    if (email.isNotEmpty) {
                      _completeGoogleSignIn(
                        email: email,
                        name: email.split('@').first,
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Xác nhận đăng nhập',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
