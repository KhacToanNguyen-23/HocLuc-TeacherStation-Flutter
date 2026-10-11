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
  /// Mid dark slate - text thứ cấp, icon quan trọng
  static const Color slate700 = Color(0xFF334155);
  /// Mid slate - icon, text thứ cấp, nhãn thiết bị
  static const Color slate600 = Color(0xFF475569);
  /// Muted slate - phụ đề, placeholder, caption
  static const Color slate500 = Color(0xFF64748B);
  /// Light slate - border phụ, placeholder icon
  static const Color slate400 = Color(0xFF94A3B8);
  /// Slate divider - đường kẻ viền nhẹ
  static const Color slate300 = Color(0xFFCBD5E1);
  /// Border slate - viền thẻ, divider, input border
  static const Color slate200 = Color(0xFFE2E8F0);
  /// Light surface slate - container nền input, badge nền
  static const Color slate100 = Color(0xFFF1F5F9);
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

  // === Brand Blue Scale ===
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue50 = Color(0xFFEFF6FF);

  // === Semantic Accents ===
  /// Amber - lịch hẹn (Schedule), deadline
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber50 = Color(0xFFFFFBEB);

  /// Emerald - trạng thái online, thành công
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald50 = Color(0xFFECFDF5);

  /// Rose - đăng xuất, hủy bỏ, lỗi
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose50 = Color(0xFFFFF1F2);

  // === Backward-compatible Facade (Zero Regression) ===
  static const Color pine = slate900;
  static const Color lime = sky600;
  static const Color paper = slate50;
  static const Color muted = slate500;
  static const Color line = slate200;
}
