import 'package:flutter/foundation.dart';

/// Console logger for Flutter code. Keep messages short and avoid putting user
/// content, credentials, URLs, or service response bodies in log calls.
class FrontendLogger {
  FrontendLogger._();

  static final RegExp _modulePrefix = RegExp(r'^\[([^\]]+)\]\s*');
  static final RegExp _email = RegExp(r'\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b');
  static final RegExp _credential = RegExp(
    r"""(token|secret|password|authorization|otp)(["\s:=]+)([^\s,}"']+)""",
    caseSensitive: false,
  );
  static final RegExp _bearer = RegExp(
    r"""Bearer\s+[^\s,}"']+""",
    caseSensitive: false,
  );
  static final RegExp _url = RegExp(r'https?://[^\s]+', caseSensitive: false);

  static void write(Object? value) {
    final raw = value?.toString() ?? 'null';
    final moduleMatch = _modulePrefix.firstMatch(raw);
    final module = moduleMatch?.group(1) ?? 'frontend';
    var message = moduleMatch == null ? raw : raw.substring(moduleMatch.end);

    message = message
        .replaceAll(_bearer, 'Bearer [REDACTED]')
        .replaceAllMapped(
          _credential,
          (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
        )
        .replaceAll(_email, '[REDACTED_EMAIL]')
        .replaceAll(_url, '[URL]')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    if (message.length > 500) message = '${message.substring(0, 500)}...';

    final level = _levelFor(message);
    if (!kDebugMode && level < 900) return;

    final now = DateTime.now()
        .toIso8601String()
        .replaceFirst('T', ' ')
        .substring(0, 23);
    final line = '$now [${_levelName(level)}] [$module] $message';
    final color = !kIsWeb ? _ansiColor(level) : '';
    final reset = color.isEmpty ? '' : '\u001b[0m';
    debugPrint('$color$line$reset');
  }

  static int _levelFor(String message) {
    final normalized = message.toLowerCase();
    if (RegExp(r'\b(error|failed|exception|err)\b').hasMatch(normalized)) {
      return 1000;
    }
    if (RegExp(
      r'\b(retry|retrying|fallback|timeout|missing|warning)\b',
    ).hasMatch(normalized)) {
      return 900;
    }
    if (RegExp(
      r'\b(success(?:ful(?:ly)?)?|succeed(?:ed)?|started|stopping|stopped|updated|saved|deleted|extracted|completed)\b',
    ).hasMatch(normalized)) {
      return 800;
    }
    return 500;
  }

  static String _levelName(int level) => switch (level) {
    1000 => 'ERROR',
    900 => 'WARN',
    800 => 'INFO',
    _ => 'DEBUG',
  };

  static String _ansiColor(int level) => switch (level) {
    1000 => '\u001b[31m',
    900 => '\u001b[33m',
    800 => '\u001b[32m',
    _ => '\u001b[36m',
  };
}
