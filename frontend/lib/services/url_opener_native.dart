import 'dart:io';
import 'package:flutter/foundation.dart';

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
    debugPrint('[UrlOpenerNative] Failed to open external URL "$url": $e');
    rethrow;
  }
}
