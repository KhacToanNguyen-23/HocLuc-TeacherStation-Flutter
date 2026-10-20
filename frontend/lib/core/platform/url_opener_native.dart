import 'package:teaching_companion/core/utils/frontend_logger.dart';
import 'dart:io';

Future<void> openExternalUrl(String url) async {
  try {
    if (Platform.isWindows) {
      // Avoid cmd parsing OAuth query separators (&) as shell commands.
      final result = await Process.run('rundll32.exe', [
        'url.dll,FileProtocolHandler',
        url,
      ]);
      if (result.exitCode != 0) {
        throw StateError('Không mở được trình duyệt hệ thống.');
      }
    }
  } catch (e) {
    FrontendLogger.write(
      '[UrlOpenerNative] Failed to open external URL | cause=${e.runtimeType}',
    );
    rethrow;
  }
}
