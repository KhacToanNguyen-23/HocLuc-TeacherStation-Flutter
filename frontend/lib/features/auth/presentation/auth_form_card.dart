import 'dart:async';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/auth/services/google_meet_auth_service.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';
import 'package:teaching_companion/features/auth/services/google_connection_flow.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';
import 'google_webview_login_dialog.dart';

part 'auth_form_views.dart';

/// Reusable Authentication Form Card handling Password Login, OTP Signup,
/// Google Single Sign-On and development-only quick login.
class AuthFormCard extends StatefulWidget {
  const AuthFormCard({
    super.key,
    this.initialTab = 0,
    this.localService,
    this.authService,
    this.onSuccess,
    this.showCloseButton = false,
    this.onClose,
  });

  final int initialTab;
  final LocalService? localService;
  final GoogleMeetAuthService? authService;
  final VoidCallback? onSuccess;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  State<AuthFormCard> createState() => _AuthFormCardState();
}

class _AuthFormCardState extends State<AuthFormCard> {
  static const _devLoginEnabled = bool.fromEnvironment('HLS_DEV_LOGIN');
  late final LocalService _localService;
  late final GoogleMeetAuthService _authService;
  bool _ownsLocalService = false;

  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _acceptedTerms = true;
  String? _errorMessage;
  String? _infoMessage;
  int _otpCooldown = 0;
  Timer? _cooldownTimer;

  // Login controllers
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  // Signup controllers
  final _signupTargetController = TextEditingController();
  final _signupOtpController = TextEditingController();
  final _signupPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isSignUpMode = widget.initialTab == 1;
    if (widget.localService != null) {
      _localService = widget.localService!;
      _ownsLocalService = false;
    } else {
      _localService = LocalService();
      _ownsLocalService = true;
    }
    _authService = widget.authService ?? GoogleMeetAuthService();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    _signupTargetController.dispose();
    _signupOtpController.dispose();
    _signupPasswordController.dispose();
    if (_ownsLocalService) {
      _localService.dispose();
    }
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    setState(() => _otpCooldown = seconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _otpCooldown = 0);
      } else {
        if (mounted) setState(() => _otpCooldown--);
      }
    });
  }

  Future<void> _handlePasswordLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập Email hoặc Số điện thoại');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mật khẩu');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final res = await _localService.login(
        identifier: identifier,
        password: password,
      );

      if (res['success'] == true) {
        final token = res['token'] as String? ?? 'jwt-token';
        final user = (res['user'] as Map<String, dynamic>?) ?? {};
        final displayName = (user['name'] as String?) ?? 'Giáo viên';
        final email = user['email'] as String?;
        final phone = user['phone'] as String?;

        _authService.signInWithOtpSession(
          token: token,
          name: displayName,
          email: email,
          phone: phone,
        );
        widget.onSuccess?.call();
      } else {
        setState(
          () =>
              _errorMessage = res['message'] as String? ?? 'Đăng nhập thất bại',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi kết nối máy chủ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDevLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final response = await _localService.devLogin();
      if (response['success'] != true) {
        setState(
          () => _errorMessage =
              response['message'] as String? ?? 'Đăng nhập dev thất bại',
        );
        return;
      }
      final user = (response['user'] as Map<String, dynamic>?) ?? {};
      _authService.signInWithOtpSession(
        token: response['token'] as String? ?? '',
        name: user['name'] as String? ?? 'Giáo viên Dev',
        email: user['email'] as String?,
        phone: user['phone'] as String?,
      );
      widget.onSuccess?.call();
    } catch (e) {
      setState(() => _errorMessage = 'Không thể đăng nhập dev: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendSignupOtp() async {
    final target = _signupTargetController.text.trim();
    if (target.isEmpty) {
      setState(
        () =>
            _errorMessage = 'Vui lòng nhập Email hoặc Số điện thoại để nhận mã',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final res = await _localService.sendOtp(target: target, type: 'signup');

      if (res['success'] == true) {
        _startCooldown((res['cooldown'] as num?)?.toInt() ?? 60);
        setState(() {
          _infoMessage =
              res['message'] as String? ?? 'Đã gửi mã xác thực thành công';
        });
      } else {
        setState(
          () => _errorMessage =
              res['message'] as String? ?? 'Không thể gửi mã xác thực',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi kết nối máy chủ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifySignupOtp() async {
    final target = _signupTargetController.text.trim();
    final otp = _signupOtpController.text.trim();
    final password = _signupPasswordController.text.trim();

    if (target.isEmpty || otp.isEmpty) {
      setState(
        () => _errorMessage = 'Vui lòng nhập đầy đủ thông tin và mã OTP',
      );
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu phải từ 6 ký tự trở lên');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _errorMessage = 'Vui lòng đồng ý với Điều khoản sử dụng');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final res = await _localService.verifyOtp(
        target: target,
        otp: otp,
        type: 'signup',
      );

      if (res['success'] == true) {
        final token = res['token'] as String? ?? 'registered-token';
        final user = (res['user'] as Map<String, dynamic>?) ?? {};
        final displayName = (user['name'] as String?) ?? 'Giáo viên mới';
        final isPhone = !target.contains('@');

        _authService.signInWithOtpSession(
          token: token,
          name: displayName,
          email: isPhone ? null : target,
          phone: isPhone ? target : null,
        );
        widget.onSuccess?.call();
      } else {
        setState(
          () => _errorMessage =
              res['message'] as String? ??
              'Mã xác thực không đúng hoặc đã hết hạn',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi đăng ký: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(
        () => _errorMessage =
            'Vui lòng nhập Email hoặc SĐT để khôi phục mật khẩu',
      );
      return;
    }

    setState(() {
      _infoMessage = 'Đã gửi hướng dẫn khôi phục mật khẩu đến $identifier';
      _errorMessage = null;
    });
  }

  Future<void> _handleGoogleSignInAction() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = 'Đang mở cửa sổ đăng nhập Google...';
    });
    GoogleWorkspaceApi? api;
    try {
      final rememberedEmail = await _authService.lastGoogleConnectionEmail();
      api = GoogleWorkspaceApi(email: rememberedEmail);
      if (!mounted) return;
      final email = await GoogleConnectionFlow.connect(
        api,
        context: context,
        isActive: () => mounted,
      );
      if (!mounted) return;
      if (rememberedEmail.isNotEmpty &&
          rememberedEmail.toLowerCase() != email.toLowerCase()) {
        await TeachingLauncher.requireIdleForAccountChange();
        if (!mounted) return;
      }
      await _authService.signInWithGoogleConnection(email);
      if (mounted) widget.onSuccess?.call();
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Bad state: ', '');
      // Fallback: Nếu Backend chưa cấu hình Google Cloud OAuth Client ID, mở trực tiếp WebView2 đăng nhập Google:
      if (errorMsg.contains('chưa được cấu hình kết nối Google') ||
          errorMsg.contains('GOOGLE_NOT_CONFIGURED')) {
        debugPrint(
          '[AuthFormCard] Google OAuth not configured on backend. Falling back to direct WebView2 Google Sign-In.',
        );
        if (!mounted) return;
        setState(() {
          _infoMessage = 'Đang mở cửa sổ đăng nhập Google qua WebView2...';
        });
        final email = await GoogleWebviewLoginDialog.show(
          context,
          authService: _authService,
        );
        if (email != null && email.isNotEmpty && mounted) {
          widget.onSuccess?.call();
          return;
        }
      }
      if (mounted) setState(() => _errorMessage = errorMsg);
    } finally {
      api?.close();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _infoMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.showCloseButton)
          Positioned(
            top: 14,
            right: 14,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              tooltip: 'Đóng',
              onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banners thông báo
                if (_errorMessage != null) ...[
                  _buildBanner(
                    icon: Icons.error_outline_rounded,
                    color: AppColors.error,
                    bgColor: AppColors.errorSurface,
                    borderColor: AppColors.error,
                    text: _errorMessage!,
                  ),
                  const SizedBox(height: 12),
                ],

                if (_infoMessage != null) ...[
                  _buildBanner(
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    bgColor: AppColors.successSurface,
                    borderColor: AppColors.border,
                    text: _infoMessage!,
                  ),
                  const SizedBox(height: 12),
                ],

                // Form tương ứng
                if (!_isSignUpMode)
                  _buildPasswordLoginForm()
                else
                  _buildSignupOtpForm(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


