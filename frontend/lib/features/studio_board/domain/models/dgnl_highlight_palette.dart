import 'package:flutter/material.dart';
import 'studio_board_models.dart';

/// Bộ token màu ba thành phần đồng bộ chuẩn sư phạm (Three-Part Semantic Color Token):
/// 1. [fill]: Màu nền pastel dịu mắt, độ trong suốt thích ứng giúp chữ đen trên PDF sắc nét.
/// 2. [stroke]: Màu đường viền rõ nét, tương phản tốt trên nền trắng và giấy PDF.
/// 3. [foreground]: Màu chữ / icon tối màu, độ tương phản cao khi hiển thị trên nền fill sáng (WCAG AAA).
/// 4. [badgeDark]: Màu dạ quang / độ bão hòa cao dùng cho nhãn badge, chip trên nền Liquid Glass tối (#181825).
class DgnlSemanticColorToken {
  final Color fill;
  final Color stroke;
  final Color foreground;
  final Color badgeDark;
  final String fillHex;
  final String strokeHex;
  final String foregroundHex;

  const DgnlSemanticColorToken({
    required this.fill,
    required this.stroke,
    required this.foreground,
    required this.badgeDark,
    required this.fillHex,
    required this.strokeHex,
    required this.foregroundHex,
  });
}

/// Bảng màu chuẩn sư phạm đồng bộ cho toàn bộ hệ thống bóc tách ngữ liệu ĐGNL / CEFR,
/// áp dụng thống nhất từ màn hình scan overlay đến luồng ghi chú thích trực tiếp vào PDF.
class DgnlHighlightPalette {
  const DgnlHighlightPalette._();

  // --- HỆ THỐNG TOKEN MÀU 3 THÀNH PHẦN (THREE-PART COLOR TOKENS) ---

  /// Token màu Ngữ pháp (Grammar Patterns): Họ Xanh Dương (Blue)
  static const DgnlSemanticColorToken tokenGrammar = DgnlSemanticColorToken(
    fill: Color(0xFFDCE8FF),
    stroke: Color(0xFF4778C7),
    foreground: Color(0xFF244A82),
    badgeDark: Color(0xFF89B4FA),
    fillHex: '#DCE8FF',
    strokeHex: '#4778C7',
    foregroundHex: '#244A82',
  );

  /// Token màu Cụm từ cố định (Collocations): Họ Xanh Lục (Green)
  static const DgnlSemanticColorToken tokenCollocation = DgnlSemanticColorToken(
    fill: Color(0xFFCFF2DE),
    stroke: Color(0xFF3B9A70),
    foreground: Color(0xFF175C40),
    badgeDark: Color(0xFF86EFAC),
    fillHex: '#CFF2DE',
    strokeHex: '#3B9A70',
    foregroundHex: '#175C40',
  );

  /// Token màu CEFR A1 (Breakthrough): Xanh lá sáng
  static const DgnlSemanticColorToken tokenA1 = DgnlSemanticColorToken(
    fill: Color(0xFFDCFCE7),
    stroke: Color(0xFF16A34A),
    foreground: Color(0xFF14532D),
    badgeDark: Color(0xFF22C55E),
    fillHex: '#DCFCE7',
    strokeHex: '#16A34A',
    foregroundHex: '#14532D',
  );

  /// Token màu CEFR A2 (Waystage): Xanh ngọc / Teal
  static const DgnlSemanticColorToken tokenA2 = DgnlSemanticColorToken(
    fill: Color(0xFFCCFBF1),
    stroke: Color(0xFF0D9488),
    foreground: Color(0xFF115E59),
    badgeDark: Color(0xFF14B8A6),
    fillHex: '#CCFBF1',
    strokeHex: '#0D9488',
    foregroundHex: '#115E59',
  );

  /// Token màu CEFR B1 (Threshold): Xanh dương tươi
  static const DgnlSemanticColorToken tokenB1 = DgnlSemanticColorToken(
    fill: Color(0xFFDBEAFE),
    stroke: Color(0xFF2563EB),
    foreground: Color(0xFF1E40AF),
    badgeDark: Color(0xFF3B82F6),
    fillHex: '#DBEAFE',
    strokeHex: '#2563EB',
    foregroundHex: '#1E40AF',
  );

  /// Token màu CEFR B2 (Vantage): Vàng cam / Hổ phách (Amber)
  static const DgnlSemanticColorToken tokenB2 = DgnlSemanticColorToken(
    fill: Color(0xFFFFE2A8),
    stroke: Color(0xFFC88722),
    foreground: Color(0xFF754515),
    badgeDark: Color(0xFFF59E0B),
    fillHex: '#FFE2A8',
    strokeHex: '#C88722',
    foregroundHex: '#754515',
  );

  /// Token màu CEFR C1 (Effective Operational Proficiency): Cam đậm (Orange)
  static const DgnlSemanticColorToken tokenC1 = DgnlSemanticColorToken(
    fill: Color(0xFFFFEDD5),
    stroke: Color(0xFFEA580C),
    foreground: Color(0xFF9A3412),
    badgeDark: Color(0xFFF97316),
    fillHex: '#FFEDD5',
    strokeHex: '#EA580C',
    foregroundHex: '#9A3412',
  );

  /// Token màu CEFR C2 (Mastery): Tím hoa cà / Tử đinh hương (Purple)
  static const DgnlSemanticColorToken tokenC2 = DgnlSemanticColorToken(
    fill: Color(0xFFE9DEFF),
    stroke: Color(0xFF9165CC),
    foreground: Color(0xFF57347F),
    badgeDark: Color(0xFFA855F7),
    fillHex: '#E9DEFF',
    strokeHex: '#9165CC',
    foregroundHex: '#57347F',
  );

  /// Token màu Chưa phân loại / Trung tính (Unknown): Xám đá phiến (Slate)
  static const DgnlSemanticColorToken tokenUnknown = DgnlSemanticColorToken(
    fill: Color(0xFFF1F5F9),
    stroke: Color(0xFF64748B),
    foreground: Color(0xFF334155),
    badgeDark: Color(0xFF94A3B8),
    fillHex: '#F1F5F9',
    strokeHex: '#64748B',
    foregroundHex: '#334155',
  );

  /// Token tổng hợp chế độ Trọng tâm (Focused Mode A): Cyan
  static const DgnlSemanticColorToken tokenFocused = DgnlSemanticColorToken(
    fill: Color(0xFFE0F2FE),
    stroke: Color(0xFF0284C7),
    foreground: Color(0xFF0369A1),
    badgeDark: Color(0xFF89DCEB),
    fillHex: '#E0F2FE',
    strokeHex: '#0284C7',
    foregroundHex: '#0369A1',
  );

  /// Token tổng hợp Tất cả từ vựng (All Vocab Mode B): Mauve
  static const DgnlSemanticColorToken tokenAllVocab = DgnlSemanticColorToken(
    fill: Color(0xFFF3E8FF),
    stroke: Color(0xFF9333EA),
    foreground: Color(0xFF581C87),
    badgeDark: Color(0xFFCBA6F7),
    fillHex: '#F3E8FF',
    strokeHex: '#9333EA',
    foregroundHex: '#581C87',
  );

  // --- CÁC HẰNG SỐ MÀU TƯƠNG THÍCH NGƯỢC (BACKWARD COMPATIBILITY) ---

  /// Ngữ pháp (Grammar Patterns): Xanh Cyan neon
  static const Color grammar = Color(0xFF89B4FA);

  /// Cụm từ cố định (Collocations): Xanh lục pastel
  static const Color collocation = Color(0xFF86EFAC);

  /// Từ vựng CEFR A1 (Breakthrough): Xanh lá sáng
  static const Color a1 = Color(0xFF22C55E);

  /// Từ vựng CEFR A2 (Waystage): Xanh ngọc / Teal
  static const Color a2 = Color(0xFF14B8A6);

  /// Từ vựng CEFR B1 (Threshold): Xanh dương
  static const Color b1 = Color(0xFF3B82F6);

  /// Từ vựng CEFR B2 (Vantage): Vàng cam / Amber
  static const Color b2 = Color(0xFFF59E0B);

  /// Từ vựng CEFR C1 (Effective Operational Proficiency): Cam đậm
  static const Color c1 = Color(0xFFF97316);

  /// Từ vựng CEFR C2 (Mastery): Tím huỳnh quang
  static const Color c2 = Color(0xFFA855F7);

  /// Từ vựng chưa phân loại / Trung tính: Xám slate
  static const Color unknown = Color(0xFF94A3B8);

  // --- TRUY VẤN TOKEN THEO DANH MỤC & CẤP ĐỘ ---

  /// Trích xuất bộ token màu 3 thành phần theo [category] và [level].
  static DgnlSemanticColorToken tokenForCategory(String category, [String? level]) {
    final cat = category.trim().toLowerCase();
    if (cat == 'grammar') return tokenGrammar;
    if (cat == 'collocation') return tokenCollocation;
    if (cat == 'focused' || cat == 'focus') return tokenFocused;
    if (cat == 'vocabulary_all') return tokenAllVocab;
    return tokenForLevel(level);
  }

  /// Trích xuất bộ token màu 3 thành phần theo cấp độ CEFR [level].
  static DgnlSemanticColorToken tokenForLevel(String? level) {
    final lvl = (level ?? '').trim().toUpperCase();
    switch (lvl) {
      case 'A1':
        return tokenA1;
      case 'A2':
        return tokenA2;
      case 'B1':
        return tokenB1;
      case 'B2':
        return tokenB2;
      case 'C1':
        return tokenC1;
      case 'C2':
        return tokenC2;
      default:
        return tokenUnknown;
    }
  }

  /// Trích xuất bộ token màu 3 thành phần tương ứng với một đối tượng [PdfDgnlHighlightSpan].
  static DgnlSemanticColorToken tokenForSpan(PdfDgnlHighlightSpan span) {
    return tokenForCategory(span.category, span.level);
  }

  // --- CÁC HÀM GIẢI QUYẾT MÀU SẮC ĐỒNG BỘ ---

  /// Giải quyết mã màu chính xác từ [category] và [level].
  static Color resolveColor({required String category, String? level}) {
    final cat = category.trim().toLowerCase();
    if (cat == 'grammar') {
      return grammar;
    }
    if (cat == 'collocation') {
      return collocation;
    }

    final lvl = (level ?? '').trim().toUpperCase();
    switch (lvl) {
      case 'A1':
        return a1;
      case 'A2':
        return a2;
      case 'B1':
        return b1;
      case 'B2':
        return b2;
      case 'C1':
        return c1;
      case 'C2':
        return c2;
      default:
        return unknown;
    }
  }

  /// Trích xuất mã màu tương ứng với một đối tượng [PdfDgnlHighlightSpan].
  static Color resolveSpanColor(PdfDgnlHighlightSpan span) {
    return resolveColor(category: span.category, level: span.level);
  }

  /// Trả về mã màu HEX chuẩn cho từng cấp độ CEFR.
  static String colorHexForLevel(String? level) {
    final lvl = (level ?? '').trim().toUpperCase();
    switch (lvl) {
      case 'A1':
        return '#22C55E';
      case 'A2':
        return '#14B8A6';
      case 'B1':
        return '#3B82F6';
      case 'B2':
        return '#F59E0B';
      case 'C1':
        return '#F97316';
      case 'C2':
        return '#A855F7';
      default:
        return '#94A3B8';
    }
  }

  /// Trả về mã màu HEX chuẩn cho từng phân loại ngữ liệu.
  static String colorHexForCategory(String category, [String? level]) {
    final cat = category.trim().toLowerCase();
    if (cat == 'grammar') return '#89B4FA';
    if (cat == 'collocation') return '#86EFAC';
    return colorHexForLevel(level);
  }

  /// Độ mờ viền nét đứt cho cấu trúc ngữ pháp (Grammar dashed border opacity).
  static const double grammarBorderOpacity = 0.85;

  /// Độ mờ nền cho cấu trúc ngữ pháp (nếu có tô nền mỏng).
  static const double grammarFillOpacity = 0.06;

  /// Độ mờ nền thích ứng chuẩn sư phạm (Adaptive Highlight Opacity) cho từng phân loại ngữ liệu.
  /// Đảm bảo văn bản mực đen luôn sắc nét, không bị tối chữ hoặc đục màu khi ghi vào PDF.
  static double resolveOpacity({required String category, String? level}) {
    final cat = category.trim().toLowerCase();
    if (cat == 'grammar') {
      return grammarFillOpacity;
    }
    if (cat == 'collocation') {
      return 0.20;
    }
    final lvl = (level ?? '').trim().toUpperCase();
    switch (lvl) {
      case 'A1':
      case 'A2':
        return 0.18;
      case 'B1':
      case 'B2':
        return 0.22;
      case 'C1':
      case 'C2':
        return 0.25;
      default:
        return 0.12; // Unknown / Neutral
    }
  }

  /// Trích xuất độ mờ nền tương ứng với một đối tượng [PdfDgnlHighlightSpan].
  static double resolveSpanOpacity(PdfDgnlHighlightSpan span) {
    return resolveOpacity(category: span.category, level: span.level);
  }

  /// Định nghĩa kiểu vẽ (Rendering Style) hoàn chỉnh tách biệt khỏi tọa độ hình học (Geometry).
  /// Thống nhất thuộc tính tô nền (fill), viền (stroke), độ mờ (opacity) và kiểu nét (dashed/solid).
  static ({
    Color color,
    Color fillColor,
    Color strokeColor,
    Color foregroundColor,
    DgnlSemanticColorToken token,
    double fillOpacity,
    double borderOpacity,
    double borderWidth,
    bool isDashed,
    bool isHollow,
  }) resolveRenderingStyle({
    required PdfDgnlHighlightSpan span,
    required bool isNestedInCollocation,
    bool isNestedInGrammar = false,
  }) {
    final isGrammar = span.category.trim().toLowerCase() == 'grammar';
    final isColloc = span.category.trim().toLowerCase() == 'collocation';
    final color = resolveSpanColor(span);
    final token = tokenForSpan(span);

    if (isGrammar) {
      return (
        color: color,
        fillColor: token.fill,
        strokeColor: token.stroke,
        foregroundColor: token.foreground,
        token: token,
        fillOpacity: 0.0, // Grammar chỉ dùng viền nét đứt, nền trong suốt 100% để bảo toàn độ đọc
        borderOpacity: grammarBorderOpacity,
        borderWidth: 1.5,
        isDashed: true,
        isHollow: true,
      );
    }

    if (isColloc) {
      return (
        color: color,
        fillColor: token.fill,
        strokeColor: token.stroke,
        foregroundColor: token.foreground,
        token: token,
        fillOpacity: 0.20,
        borderOpacity: 0.70,
        borderWidth: 1.0,
        isDashed: false,
        isHollow: false,
      );
    }

    if (isNestedInCollocation) {
      // Từ vựng lồng trong Collocation: Dùng viền sắc nét, KHÔNG tô nền để tránh trộn màu làm đục chữ
      return (
        color: color,
        fillColor: token.fill,
        strokeColor: token.stroke,
        foregroundColor: token.foreground,
        token: token,
        fillOpacity: 0.0,
        borderOpacity: 0.85,
        borderWidth: 1.2,
        isDashed: false,
        isHollow: true,
      );
    }

    // Từ vựng độc lập hoặc từ vựng nằm trong cấu trúc ngữ pháp
    final fillOpacity = resolveOpacity(category: 'vocabulary', level: span.level);
    return (
      color: color,
      fillColor: token.fill,
      strokeColor: token.stroke,
      foregroundColor: token.foreground,
      token: token,
      fillOpacity: fillOpacity,
      borderOpacity: 0.70,
      borderWidth: 0.8,
      isDashed: false,
      isHollow: false,
    );
  }

  /// Phối hợp màu viền (stroke/accent) và màu nền bán trong suốt (background) cho giao diện overlay trên màn hình.
  static ({
    Color accent,
    Color background,
    Color stroke,
    Color foreground,
    DgnlSemanticColorToken token,
  }) resolveOverlayColors({
    required PdfDgnlHighlightSpan span,
    required bool isCurrentActive,
    required bool isNestedVocab,
  }) {
    final style = resolveRenderingStyle(
      span: span,
      isNestedInCollocation: isNestedVocab,
    );
    final accent = style.color;
    final token = style.token;
    final stroke = token.stroke;
    final foreground = token.foreground;
    final Color bg;

    if (style.isHollow) {
      bg = isCurrentActive
          ? accent.withValues(alpha: 0.12)
          : (style.fillOpacity > 0
              ? accent.withValues(alpha: style.fillOpacity)
              : Colors.transparent);
    } else {
      bg = isCurrentActive
          ? accent.withValues(
              alpha: (style.fillOpacity + 0.15).clamp(0.0, 0.45),
            )
          : accent.withValues(alpha: style.fillOpacity);
    }

    return (
      accent: accent,
      background: bg,
      stroke: stroke,
      foreground: foreground,
      token: token,
    );
  }

  /// Trích xuất bộ ba số nguyên RGB (0..255) cho thư viện đồ họa PDF (Syncfusion sf.PdfColor).
  static ({int r, int g, int b}) toRgb(Color color) {
    return (
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
    );
  }
}
