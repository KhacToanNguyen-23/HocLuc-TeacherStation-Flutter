import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String stylesheet;

  setUpAll(() {
    stylesheet = File('assets/scripts/liquid-glass.css').readAsStringSync();
  });

  test('text-bearing glass content stays translucent like the reference', () {
    expect(stylesheet, isNot(contains('--glass-text-backing')));
    expect(
      stylesheet,
      contains('--glass-bg: rgb(24 38 32 / var(--glass-bg-opacity));'),
    );
    for (final selector in ['.liquid-pill-btn', '.liquid-card']) {
      expect(
        _ruleFor(stylesheet, selector),
        contains('background-color: var(--glass-bg);'),
      );
    }
    for (final selector in [
      '.liquid-card > .legend',
      '.liquid-card > .tokens-container',
      '.liquid-card > .grammar-alert',
    ]) {
      expect(
        _ruleFor(stylesheet, selector),
        isNot(contains('background-color:')),
        reason: '$selector must not add an opaque local text backplate.',
      );
    }
    expect(
      _ruleFor(stylesheet, '.liquid-card > .grammar-alert'),
      contains('border-color: currentColor;'),
    );
    for (final selector in ['.liquid-card', '.liquid-pill-btn']) {
      final rule = _ruleFor(stylesheet, selector);
      expect(rule, contains('border: 1px solid #0b2348;'));
      expect(rule, contains('outline: 1px solid #ffffff;'));
    }
  });

  test('glass presets expose the documented variable backdrop opacity', () {
    expect(
      _ruleFor(stylesheet, ":root[data-glass-preset='clear']"),
      contains('--glass-bg-opacity: 0.15;'),
    );
    expect(
      _ruleFor(stylesheet, ":root[data-glass-preset='frosted']"),
      contains('--glass-bg-opacity: 0.28;'),
    );
    expect(
      _ruleFor(stylesheet, ":root[data-glass-preset='solid']"),
      contains('--glass-bg-opacity: 0.85;'),
    );
  });

  test('glass panel boundary stays visible across the fixture palette', () {
    const darkEdge = '#0b2348';
    const lightEdge = '#ffffff';
    const fixtures = [
      '#14221d',
      '#ffffff',
      '#000000',
      '#d50000',
      '#1e40af',
      '#fbbf24',
    ];

    for (final fixture in fixtures) {
      expect(
        _contrastRatio(darkEdge, fixture) >= 3 ||
            _contrastRatio(lightEdge, fixture) >= 3,
        isTrue,
        reason: 'At least one panel edge must distinguish against $fixture.',
      );
    }
  });

  test(
    'glass hover motion is hover-only, focus-visible, and reduced-motion safe',
    () {
      expect(stylesheet, contains('@media (hover: hover)'));
      expect(stylesheet, contains('.liquid-pill-btn:focus-visible'));
      expect(stylesheet, contains('@media (prefers-reduced-motion: reduce)'));
    },
  );
}

String _ruleFor(String css, String selector) {
  final source = css.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  for (final match in RegExp(
    r'([^{}]+)\{([^}]*)\}',
    dotAll: true,
  ).allMatches(source)) {
    final selectors = match.group(1)!.split(',').map((value) => value.trim());
    if (selectors.contains(selector)) return match.group(2)!;
  }
  return '';
}

double _contrastRatio(String foreground, String background) {
  final foregroundLuminance = _relativeLuminance(foreground);
  final backgroundLuminance = _relativeLuminance(background);
  final brightest = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darkest = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (brightest + 0.05) / (darkest + 0.05);
}

double _relativeLuminance(String hex) {
  final channels = [1, 3, 5].map((index) {
    final channel = int.parse(hex.substring(index, index + 2), radix: 16) / 255;
    return channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  });
  final values = channels.toList(growable: false);
  return 0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2];
}
