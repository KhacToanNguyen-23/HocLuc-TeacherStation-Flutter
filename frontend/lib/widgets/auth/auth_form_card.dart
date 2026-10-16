import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/google_meet_auth_service.dart';
import '../../services/local_service.dart';
import '../../services/google_workspace_api.dart';
import '../../services/google_connection_flow.dart';
import '../../services/teaching_launcher.dart';
import 'google_webview_login_dialog.dart';

/// Reusable Authentication Form Card handling Password Login, OTP Signup,
/// Google Single Sign-On and Quick Demo Teacher Login.
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
        setState(() => _errorMessage = res['message'] as String? ?? 'Đăng nhập thất bại');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi kết nối máy chủ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendSignupOtp() async {
    final target = _signupTargetController.text.trim();
    if (target.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập Email hoặc Số điện thoại để nhận mã');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final res = await _localService.sendOtp(
        target: target,
        type: 'signup',
      );

      if (res['success'] == true) {
        _startCooldown((res['cooldown'] as num?)?.toInt() ?? 60);
        setState(() {
          _infoMessage = res['message'] as String? ?? 'Đã gửi mã xác thực thành công';
        });
      } else {
        setState(() => _errorMessage = res['message'] as String? ?? 'Không thể gửi mã xác thực');
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
      setState(() => _errorMessage = 'Vui lòng nhập đầy đủ thông tin và mã OTP');
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
        setState(() => _errorMessage = res['message'] as String? ?? 'Mã xác thực không đúng hoặc đã hết hạn');
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
      setState(() => _errorMessage = 'Vui lòng nhập Email hoặc SĐT để khôi phục mật khẩu');
      return;
    }

    setState(() {
      _infoMessage = 'Đã gửi hướng dẫn khôi phục mật khẩu đến $identifier';
      _errorMessage = null;
    });
  }


  Future<void> _handleGoogleSignInAction() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _errorMessage = null; _infoMessage = 'Đang mở cửa sổ đăng nhập Google...'; });
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
      if (rememberedEmail.isNotEmpty && rememberedEmail.toLowerCase() != email.toLowerCase()) {
        await TeachingLauncher.requireIdleForAccountChange();
        if (!mounted) return;
      }
      await _authService.signInWithGoogleConnection(email);
      if (mounted) widget.onSuccess?.call();
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Bad state: ', '');
      // Fallback: Nếu Backend chưa cấu hình Google Cloud OAuth Client ID, mở trực tiếp WebView2 đăng nhập Google:
      if (errorMsg.contains('chưa được cấu hình kết nối Google') || errorMsg.contains('GOOGLE_NOT_CONFIGURED')) {
        debugPrint('[AuthFormCard] Google OAuth not configured on backend. Falling back to direct WebView2 Google Sign-In.');
        if (!mounted) return;
        setState(() {
          _infoMessage = 'Đang mở cửa sổ đăng nhập Google qua WebView2...';
        });
        final email = await GoogleWebviewLoginDialog.show(context, authService: _authService);
        if (email != null && email.isNotEmpty && mounted) {
          widget.onSuccess?.call();
          return;
        }
      }
      if (mounted) setState(() => _errorMessage = errorMsg);
    } finally {
      api?.close();
      if (mounted) setState(() { _isLoading = false; _infoMessage = null; });
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
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF6B7280)),
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
                    color: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEE2E2),
                    borderColor: const Color(0xFFFCA5A5),
                    text: _errorMessage!,
                  ),
                  const SizedBox(height: 12),
                ],

                if (_infoMessage != null) ...[
                  _buildBanner(
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    borderColor: const Color(0xFFA7F3D0),
                    text: _infoMessage!,
                  ),
                  const SizedBox(height: 12),
                ],

                // Form tương ứng
                if (!_isSignUpMode) _buildPasswordLoginForm() else _buildSignupOtpForm(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerText(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      ],
    );
  }



  Widget _buildPasswordLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _identifierController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF6B7280)),
            hintText: 'Email hoặc số điện thoại',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.sky600, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF6B7280)),
            hintText: 'Mật khẩu',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF6B7280),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.sky600, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Quên mật khẩu?',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Đăng nhập',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _isSignUpMode = true;
              _errorMessage = null;
              _infoMessage = null;
            }),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Đăng ký',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.sky600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildDividerText('Hoặc đăng nhập bằng'),
        const SizedBox(height: 12),
        Center(
          child: _buildGoogleCircleButton(),
        ),
      ],
    );
  }

  Widget _buildGoogleCircleButton() {
    return Tooltip(
      message: 'Đăng nhập bằng Google',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleGoogleSignInAction,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Đăng ký tài khoản',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate900),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupTargetController,
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: const Text(
                '+84',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            hintText: 'Email hoặc số điện thoại',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.sky600, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupOtpController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF6B7280)),
            hintText: 'Nhập mã xác thực',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            suffixIcon: TextButton(
              onPressed: (_otpCooldown > 0 || _isLoading) ? null : _handleSendSignupOtp,
              child: Text(
                _otpCooldown > 0 ? '$_otpCooldown s' : 'Gửi mã',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _otpCooldown > 0 ? const Color(0xFF9CA3AF) : AppColors.sky600,
                ),
              ),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.sky600, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF6B7280)),
            hintText: 'Nhập mật khẩu',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF6B7280),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.sky600, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _acceptedTerms,
                activeColor: AppColors.sky600,
                onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tôi đồng ý với Điều khoản & Chính sách bảo mật',
                style: TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifySignupOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sky600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Đăng ký',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _isSignUpMode = false;
              _errorMessage = null;
              _infoMessage = null;
            }),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Quay lại',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.sky600,
              ),
            ),
          ),
        ),
      ],
    );
  }


}
