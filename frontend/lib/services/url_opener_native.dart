import 'dart:io';
import 'package:flutter/foundation.dart';

Future<void> openExternalUrl(String url) async {
  try {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    }
  } catch (e) {
    debugPrint('[UrlOpenerNative] Failed to open external URL "$url": $e');
  }
}
