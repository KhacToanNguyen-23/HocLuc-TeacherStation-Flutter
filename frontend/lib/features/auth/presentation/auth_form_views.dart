// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of 'auth_form_card.dart';

extension AuthFormViews on _AuthFormCardState {
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
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerText(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildPasswordLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _identifierController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            hintText: 'Email hoặc số điện thoại',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _isLoading ? null : _handlePasswordLogin(),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            hintText: 'Mật khẩu',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
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
                color: AppColors.primary,
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Đăng nhập',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        if (_AuthFormCardState._devLoginEnabled) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleDevLogin,
            icon: const Icon(Icons.developer_mode_rounded, size: 18),
            label: const Text('Đăng nhập nhanh · môi trường dev'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
            ),
          ),
        ],
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
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildDividerText('Hoặc đăng nhập bằng'),
        const SizedBox(height: 12),
        Center(child: _buildGoogleCircleButton()),
      ],
    );
  }

  Widget _buildGoogleCircleButton() {
    return AppPressable(
      tooltip: 'Đăng nhập bằng Google',
      onTap: _isLoading ? null : _handleGoogleSignInAction,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: AppColors.inputBorder, width: 1.2),
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
              fontFamily: 'Manrope',
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupTargetController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: const Text(
                '+84',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            hintText: 'Email hoặc số điện thoại',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupOtpController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.shield_outlined,
              size: 18,
              color: AppColors.textMuted,
            ),
            hintText: 'Nhập mã xác thực',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            suffixIcon: TextButton(
              onPressed: (_otpCooldown > 0 || _isLoading)
                  ? null
                  : _handleSendSignupOtp,
              child: Text(
                _otpCooldown > 0 ? '$_otpCooldown s' : 'Gửi mã',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _otpCooldown > 0
                      ? AppColors.textMuted
                      : AppColors.primary,
                ),
              ),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupPasswordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _isLoading ? null : _handleVerifySignupOtp(),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            hintText: 'Nhập mật khẩu',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
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
                activeColor: AppColors.primary,
                onChanged: (val) =>
                    setState(() => _acceptedTerms = val ?? false),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tôi đồng ý với Điều khoản & Chính sách bảo mật',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifySignupOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
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
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
