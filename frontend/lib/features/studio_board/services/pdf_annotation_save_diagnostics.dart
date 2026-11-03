import 'package:teaching_companion/core/utils/frontend_logger.dart';

/// Lightweight stage diagnostics for PDF annotation persistence.
///
/// Events intentionally contain sizes, counts, and elapsed times only. They do
/// not include document paths, PDF contents, or annotation text.
abstract final class PdfAnnotationSaveDiagnostics {
  static int _sequence = 0;

  static String newOperationId([String prefix = 'save']) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';

  static void log(
    String operationId,
    String stage, {
    Duration? duration,
    Map<String, Object?> fields = const {},
  }) {
    final elapsed = duration == null
        ? null
        : (duration.inMicroseconds / 1000).toStringAsFixed(3);
    final details = <String>[
      if (elapsed != null) 'durationMs=$elapsed',
      for (final entry in fields.entries) '${entry.key}=${entry.value}',
    ];
    FrontendLogger.write(
      '[PDF_SAVE] [$operationId] stage=$stage'
      '${details.isEmpty ? '' : ' ${details.join(' ')}'}',
    );
  }
}
