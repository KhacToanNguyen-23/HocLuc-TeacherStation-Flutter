import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/google_meet_auth_service.dart';
import '../services/local_service.dart';
import '../widgets/auth/auth_hero_panel.dart';

/// Full-page dedicated 50/50 Split Login & Registration screen for teachers.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialTab = 0,
    this.localService,
    this.authService,
  });

  final int initialTab;
  final LocalService? localService;
  final GoogleMeetAuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
        setState(() => _errorMessage = res['message'] as String? ?? 'Gửi mã thất bại');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi kết nối: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final target = _signupTargetController.text.trim();
    final otp = _signupOtpController.text.trim();
    final password = _signupPasswordController.text.trim();

    if (target.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập Email hoặc Số điện thoại');
      return;
    }
    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mã xác thực OTP');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _errorMessage = 'Vui lòng đồng ý với Điều khoản & Chính sách');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final res = await _localService.register(
        target: target,
        otp: otp,
        password: password,
      );

      if (res['success'] == true) {
        final token = res['token'] as String? ?? 'jwt-token';
        final user = (res['user'] as Map<String, dynamic>?) ?? {};
        final displayName = (user['name'] as String?) ?? 'Thầy Cô';
        final email = user['email'] as String?;
        final phone = user['phone'] as String?;

        _authService.signInWithOtpSession(
          token: token,
          name: displayName,
          email: email,
          phone: phone,
        );
      } else {
        setState(() => _errorMessage = res['message'] as String? ?? 'Đăng ký thất bại');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi kết nối: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDemoQuickLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _localService.loginDemoAccount();
      if (res['success'] == true) {
        final token = res['token'] as String? ?? 'demo-token';
        final user = (res['user'] as Map<String, dynamic>?) ?? {};
        final name = (user['name'] as String?) ?? 'Giáo viên Demo';
        final email = (user['email'] as String?) ?? 'khactoan2233@gmail.com';
        final phone = user['phone'] as String?;

        _authService.signInWithOtpSession(
          token: token,
          name: name,
          email: email,
          phone: phone,
        );
      } else {
        setState(() => _errorMessage = res['message'] as String? ?? 'Đăng nhập demo thất bại');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi kết nối máy chủ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoogleQuickSignIn() {
    _authService.quickSignIn(
      name: 'Thầy Giáo (Google)',
      email: 'giaovien.hocluc@edu.vn',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 740;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: isCompact ? 420 : 860,
              height: isCompact ? 650 : 570,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE1E5DB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: isCompact
                  ? _buildFormSide(context)
                  : Row(
                      children: [
                        const Expanded(
                          flex: 5,
                          child: AuthHeroPanel(),
                        ),
                        Expanded(
                          flex: 6,
                          child: _buildFormSide(context),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
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

            // Chuyển đổi giữa Login và Signup
            if (!_isSignUpMode) ...[
              _buildLoginForm(),
            ] else ...[
              _buildSignupForm(),
            ],

            const SizedBox(height: 18),

            // Divider hoặc
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'hoặc',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
              ],
            ),
            const SizedBox(height: 14),

            // Hàng nằm ngang: Logo Google và Nút Đăng nhập nhanh
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1 cái Icon Google tròn gọn gàng
                Tooltip(
                  message: 'Tiếp tục với Google',
                  child: InkWell(
                    onTap: _isLoading ? null : _handleGoogleQuickSignIn,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.g_mobiledata_rounded,
                          size: 32,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Nút Đăng nhập nhanh nằm ngang với Google
                _buildPinnedDemoCard(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Form Đăng nhập bằng Mật khẩu (Viền vuông, không OTP)
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ô 1: SĐT hoặc Email
        TextField(
          controller: _identifierController,
          decoration: InputDecoration(
            hintText: 'Email hoặc số điện thoại',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF6B7280)),
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

        // Ô 2: Mật khẩu
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Mật khẩu',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF6B7280)),
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
        const SizedBox(height: 16),

        // Nút Đăng nhập to rõ
        ElevatedButton(
          onPressed: _isLoading ? null : _handlePasswordLogin,
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
                  'Đăng nhập',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 8),

        // Dưới nút: Đúng 1 chữ nhỏ "Đăng ký"
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
      ],
    );
  }

  /// Form Đăng ký (Chuẩn theo ảnh mẫu Signup A New Account)
  Widget _buildSignupForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Text(
            'Đăng ký tài khoản',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Ô 1: +84 | Email or phone number
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

        // Ô 2: Enter verification code | Send code
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

        // Ô 3: Enter password | eye icon
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

        // Checkbox: Đồng ý điều khoản
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

        // Nút Đăng ký
        ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
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

        // Dưới nút: Đúng 1 chữ nhỏ "Quay lại"
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

  static Widget _buildBanner({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedDemoCard() {
    return Tooltip(
      message: 'Đăng nhập nhanh',
      child: InkWell(
        onTap: _isLoading ? null : _handleDemoQuickLogin,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.bolt_rounded,
              size: 24,
              color: AppColors.sky600,
            ),
          ),
        ),
      ),
    );
  }
}
