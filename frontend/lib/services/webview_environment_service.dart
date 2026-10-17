import 'package:teaching_companion/utils/frontend_logger.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart' as win;

/// Manages the shared, persistent Microsoft Edge WebView2 environment on Windows.
/// Ensures Google account session, cookies, and permissions persist permanently.
class WebviewEnvironmentService {
  static bool _initialized = false;
  static String? _resolvedUserDataPath;

  static bool get isInitialized => _initialized;
  static String? get resolvedUserDataPath => _resolvedUserDataPath;

  /// Resolves the default persistent directory in %APPDATA%/HocLucTeacherStation/EdgeProfile.
  static String get defaultUserDataPath {
    if (!kIsWeb && Platform.isWindows) {
      final appData =
          Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'] ??
          r'C:\Users\Public';
      return '$appData\\HocLucTeacherStation\\EdgeProfile';
    }
    return '';
  }

  /// Chromium launch arguments ensuring bypass of permission prompts and isolation of physical camera devices.
  static const String chromiumAdditionalArguments =
      '--use-fake-ui-for-media-stream --use-fake-device-for-media-stream --enable-usermedia-screen-capturing';

  /// Explicitly initializes the shared WebView2 environment before any WebviewController is created.
  static Future<void> ensureInitialized({String? customPath}) async {
    if (_initialized) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      _initialized = true;
      return;
    }

    try {
      final path = customPath ?? defaultUserDataPath;
      if (path.isNotEmpty) {
        final dir = Directory(path);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        _resolvedUserDataPath = path;
      }

      await win.WebviewController.initializeEnvironment(
        userDataPath: _resolvedUserDataPath,
        additionalArguments: chromiumAdditionalArguments,
      );
      _initialized = true;
      FrontendLogger.write(
        '[WebviewEnvironment] Successfully initialized with profile: $_resolvedUserDataPath',
      );
    } on PlatformException catch (e) {
      // If already initialized by previous instance/runner, mark as initialized
      FrontendLogger.write(
        '[WebviewEnvironment] PlatformException during init (already initialized?): $e',
      );
      _initialized = true;
    } catch (e) {
      FrontendLogger.write('[WebviewEnvironment] Init error: $e');
      _initialized = true;
    }
  }
}
