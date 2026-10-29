import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_board_models.dart';

/// Helper tính toán độ chói tương đối (relative luminance) theo chuẩn W3C WCAG 2.1
double _calculateRelativeLuminance(Color color) {
  double transform(double channel) {
    if (channel <= 0.04045) {
      return channel / 12.92;
    } else {
      return ((channel + 0.055) / 1.055).clamp(0.0, 1.0) *
          ((channel + 0.055) / 1.055).clamp(0.0, 1.0);
    }
  }

  final r = transform(color.r);
  final g = transform(color.g);
  final b = transform(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Helper tính toán tỷ số tương phản (Contrast Ratio) giữa 2 màu theo chuẩn WCAG 2.1
double _calculateContrastRatio(Color color1, Color color2) {
  final l1 = _calculateRelativeLuminance(color1);
  final l2 = _calculateRelativeLuminance(color2);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Highlight Color Contrast & Three-Part Token Verification', () {
    test('verifies starting 4-color palette tokens match exact specification', () {
      // 1. Blue (Grammar)
      final blue = DgnlHighlightPalette.tokenGrammar;
      expect(blue.fill, const Color(0xFFDCE8FF));
      expect(blue.stroke, const Color(0xFF4778C7));
      expect(blue.foreground, const Color(0xFF244A82));
      expect(blue.badgeDark, const Color(0xFF89B4FA));
      expect(blue.fillHex, '#DCE8FF');
      expect(blue.strokeHex, '#4778C7');
      expect(blue.foregroundHex, '#244A82');

      // 2. Amber (B2)
      final amber = DgnlHighlightPalette.tokenB2;
      expect(amber.fill, const Color(0xFFFFE2A8));
      expect(amber.stroke, const Color(0xFFC88722));
      expect(amber.foreground, const Color(0xFF754515));
      expect(amber.badgeDark, const Color(0xFFF59E0B));
      expect(amber.fillHex, '#FFE2A8');
      expect(amber.strokeHex, '#C88722');
      expect(amber.foregroundHex, '#754515');

      // 3. Purple (C2)
      final purple = DgnlHighlightPalette.tokenC2;
      expect(purple.fill, const Color(0xFFE9DEFF));
      expect(purple.stroke, const Color(0xFF9165CC));
      expect(purple.foreground, const Color(0xFF57347F));
      expect(purple.badgeDark, const Color(0xFFA855F7));
      expect(purple.fillHex, '#E9DEFF');
      expect(purple.strokeHex, '#9165CC');
      expect(purple.foregroundHex, '#57347F');

      // 4. Green (Collocation)
      final green = DgnlHighlightPalette.tokenCollocation;
      expect(green.fill, const Color(0xFFCFF2DE));
      expect(green.stroke, const Color(0xFF3B9A70));
      expect(green.foreground, const Color(0xFF175C40));
      expect(green.badgeDark, const Color(0xFF86EFAC));
      expect(green.fillHex, '#CFF2DE');
      expect(green.strokeHex, '#3B9A70');
      expect(green.foregroundHex, '#175C40');
    });

    test('verifies WCAG contrast ratios on light background for three-part tokens', () {
      const white = Color(0xFFFFFFFF);
      final tokens = [
        DgnlHighlightPalette.tokenGrammar,
        DgnlHighlightPalette.tokenCollocation,
        DgnlHighlightPalette.tokenA1,
        DgnlHighlightPalette.tokenA2,
        DgnlHighlightPalette.tokenB1,
        DgnlHighlightPalette.tokenB2,
        DgnlHighlightPalette.tokenC1,
        DgnlHighlightPalette.tokenC2,
        DgnlHighlightPalette.tokenUnknown,
      ];

      for (final t in tokens) {
        // 1. Text foreground on pastel fill background must exceed WCAG AA (4.5:1)
        final fgOnFillContrast = _calculateContrastRatio(t.foreground, t.fill);
        expect(
          fgOnFillContrast,
          greaterThanOrEqualTo(4.5),
          reason: 'Foreground ${t.foregroundHex} on fill ${t.fillHex} must meet WCAG AA (>= 4.5:1)',
        );

        // 2. Stroke border on white paper must have distinct visibility (>= 2.5:1)
        final strokeOnWhiteContrast = _calculateContrastRatio(t.stroke, white);
        expect(
          strokeOnWhiteContrast,
          greaterThanOrEqualTo(2.5),
          reason: 'Stroke ${t.strokeHex} on white must be distinctly visible (>= 2.5:1)',
        );
      }
    });

    test('verifies badgeDark has high luminosity on dark Liquid Glass surface', () {
      const darkGlassSurface = Color(0xFF181825);
      final tokens = [
        DgnlHighlightPalette.tokenGrammar,
        DgnlHighlightPalette.tokenCollocation,
        DgnlHighlightPalette.tokenA1,
        DgnlHighlightPalette.tokenA2,
        DgnlHighlightPalette.tokenB1,
        DgnlHighlightPalette.tokenB2,
        DgnlHighlightPalette.tokenC1,
        DgnlHighlightPalette.tokenC2,
        DgnlHighlightPalette.tokenFocused,
        DgnlHighlightPalette.tokenAllVocab,
      ];

      for (final t in tokens) {
        final badgeContrast = _calculateContrastRatio(t.badgeDark, darkGlassSurface);
        expect(
          badgeContrast,
          greaterThanOrEqualTo(4.0),
          reason: 'Badge ${t.badgeDark} on dark glass #181825 must meet WCAG UI requirement (>= 4.0:1)',
        );
      }
    });

    test('verifies tokenForCategory, tokenForLevel, and tokenForSpan mappings', () {
      expect(DgnlHighlightPalette.tokenForCategory('grammar'), DgnlHighlightPalette.tokenGrammar);
      expect(DgnlHighlightPalette.tokenForCategory('collocation'), DgnlHighlightPalette.tokenCollocation);
      expect(DgnlHighlightPalette.tokenForCategory('focused'), DgnlHighlightPalette.tokenFocused);
      expect(DgnlHighlightPalette.tokenForCategory('vocabulary_all'), DgnlHighlightPalette.tokenAllVocab);

      expect(DgnlHighlightPalette.tokenForLevel('A1'), DgnlHighlightPalette.tokenA1);
      expect(DgnlHighlightPalette.tokenForLevel('A2'), DgnlHighlightPalette.tokenA2);
      expect(DgnlHighlightPalette.tokenForLevel('B1'), DgnlHighlightPalette.tokenB1);
      expect(DgnlHighlightPalette.tokenForLevel('B2'), DgnlHighlightPalette.tokenB2);
      expect(DgnlHighlightPalette.tokenForLevel('C1'), DgnlHighlightPalette.tokenC1);
      expect(DgnlHighlightPalette.tokenForLevel('C2'), DgnlHighlightPalette.tokenC2);
      expect(DgnlHighlightPalette.tokenForLevel('unknown'), DgnlHighlightPalette.tokenUnknown);
      expect(DgnlHighlightPalette.tokenForLevel(null), DgnlHighlightPalette.tokenUnknown);

      const spanB2 = PdfDgnlHighlightSpan(
        text: 'bitterness',
        category: 'vocabulary',
        level: 'B2',
        type: 'B2',
        note: 'Note',
        normalizedRects: [Rect.zero],
      );
      expect(DgnlHighlightPalette.tokenForSpan(spanB2), DgnlHighlightPalette.tokenB2);
    });

    test('resolveOverlayColors exposes stroke, foreground, and token properties', () {
      const span = PdfDgnlHighlightSpan(
        text: 'were placed',
        category: 'grammar',
        level: 'B2',
        type: 'Passive',
        note: 'Passive voice',
        normalizedRects: [Rect.zero],
      );

      final overlayColors = DgnlHighlightPalette.resolveOverlayColors(
        span: span,
        isCurrentActive: false,
        isNestedVocab: false,
      );

      expect(overlayColors.stroke, const Color(0xFF4778C7));
      expect(overlayColors.foreground, const Color(0xFF244A82));
      expect(overlayColors.accent, const Color(0xFF89B4FA));
      expect(overlayColors.token, DgnlHighlightPalette.tokenGrammar);
    });
  });
}
