import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';

/// Isolated Step 2: 6-digit OTP code verification & resend timer ticker.
class AuthOtpStepView extends StatefulWidget {
  const AuthOtpStepView({
    super.key,
    required this.target,
    required this.isSignup,
    required this.isLoading,
    this.initialCountdown = 60,
    required this.onVerify,
    required this.onResend,
    required this.onChangeTarget,
  });

  final String target;
  final bool isSignup;
  final bool isLoading;
  final int initialCountdown;
  final ValueChanged<String> onVerify;
  final Future<void> Function() onResend;
  final VoidCallback onChangeTarget;

  @override
  State<AuthOtpStepView> createState() => _AuthOtpStepViewState();
}

class _AuthOtpStepViewState extends State<AuthOtpStepView> {
  final _otpController = TextEditingController();
  Timer? _countdownTimer;
  late int _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = widget.initialCountdown;
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    if (_countdown <= 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _handleResend() async {
    await widget.onResend();
    if (mounted) {
      setState(() => _countdown = 60);
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Subtitle + Target info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập mã xác nhận 6 số',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Đã gửi đến: ${widget.target}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: widget.isLoading ? null : widget.onChangeTarget,
              icon: const Icon(Icons.edit_outlined, size: 13),
              label: const Text('Đổi số', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.pine,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 6-digit OTP Input field
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 12,
            color: AppColors.pine,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: const TextStyle(letterSpacing: 8, color: Color(0xFFD1D5DB)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.sky600, width: 2),
            ),
          ),
          onSubmitted: (code) {
            if (code.trim().length == 6 && !widget.isLoading) {
              widget.onVerify(code.trim());
            }
          },
        ),
        const SizedBox(height: 6),

        // Dev mode badge hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Text(
              '💡 Mã thử nghiệm môi trường phát triển: 123456',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Resend countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_countdown > 0) ...[
              Text(
                'Gửi lại mã sau ${_countdown}s',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ] else ...[
              InkWell(
                onTap: widget.isLoading ? null : _handleResend,
                child: const Text(
                  'Gửi lại mã OTP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pine,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // Verify button
        ElevatedButton(
          onPressed: widget.isLoading
              ? null
              : () => widget.onVerify(_otpController.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sky600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  widget.isSignup ? 'Xác nhận & Kích hoạt tài khoản' : 'Xác nhận & Đăng nhập',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
