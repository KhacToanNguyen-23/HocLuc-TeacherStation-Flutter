import 'package:flutter/material.dart';
export '../theme/app_color_theme.dart';

/// Bảng màu và Design Tokens chuẩn của Teaching Station (Học Lực · Mộc)
/// Áp dụng phong cách Nordic Sky & Slate Blue (Xanh Dương Dịu Mắt EdTech).
class AppColors {
  AppColors._();

  // === Nordic Slate Scale ===
  /// Deep slate brand color - tiêu đề, header, hero base
  static const Color slate900 = Color(0xFF0F172A);
  /// Surface slate - panel, card tối
  static const Color slate800 = Color(0xFF1E293B);
  /// Mid slate - icon, text thứ cấp
  static const Color slate700 = Color(0xFF334155);
  /// Muted slate - phụ đề, placeholder, caption
  static const Color slate500 = Color(0xFF64748B);
  /// Border slate - viền thẻ, divider, input border
  static const Color slate200 = Color(0xFFE2E8F0);
  /// Nordic Mist - nền canvas toàn ứng dụng (dịu mắt)
  static const Color slate50 = Color(0xFFF8FAFC);

  // === Nordic Sky Scale ===
  /// Sky dark hover - hover CTA
  static const Color sky700 = Color(0xFF0369A1);
  /// Nordic Sky - CTA chính (Begin), active states
  static const Color sky600 = Color(0xFF0284C7);
  /// Sky vivid - nút tương tác thứ cấp
  static const Color sky500 = Color(0xFF0EA5E9);
  /// Sky highlight - badge text, accent icon
  static const Color sky400 = Color(0xFF38BDF8);
  /// Sky surface - nền badge, hover highlight container
  static const Color sky100 = Color(0xFFE0F2FE);
  /// Sky tint - nền minh họa rỗng, container phụ
  static const Color sky50 = Color(0xFFF0F9FF);

  // === Semantic Accents ===
  /// Amber - lịch hẹn (Schedule), deadline
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber100 = Color(0xFFFEF3C7);

  /// Emerald - trạng thái online, thành công
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald100 = Color(0xFFD1FAE5);

  /// Rose - đăng xuất, hủy bỏ, lỗi
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose100 = Color(0xFFFFE4E6);

  // === Backward-compatible Facade (Zero Regression) ===
  static const Color pine = slate900;
  static const Color lime = sky600;
  static const Color paper = slate50;
  static const Color muted = slate500;
  static const Color line = slate200;
}
