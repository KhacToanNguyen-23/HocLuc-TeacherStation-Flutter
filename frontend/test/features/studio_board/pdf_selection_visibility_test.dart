import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/theme/app_theme.dart';

void main() {
  test('PDF selection fill preserves dark glyphs against white paper', () {
    final fill = AppTheme.light().textSelectionTheme.selectionColor!;
    expect(fill.a, greaterThan(0));
    expect(fill.a, lessThan(0.4));
    // pdfrx paints this fill over the page, including its existing glyphs.
    final selectedInk = Color.alphaBlend(fill, Colors.black);
    final selectedPaper = Color.alphaBlend(fill, Colors.white);
    final contrast =
        (selectedPaper.computeLuminance() + 0.05) /
        (selectedInk.computeLuminance() + 0.05);
    expect(contrast, greaterThanOrEqualTo(4.5));
  });
}
