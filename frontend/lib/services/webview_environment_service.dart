import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart' as win;

/// Manages the shared, persistent Microsoft Edge WebView2 environment on Windows.
/// Reuses cookies while the Google session remains valid.
class WebviewEnvironmentService {
  static bool _initialized = false;
  static String? _resolvedUserDataPath;
  static Future<void>? _initializing;

  static bool get isInitialized => _initialized;
  static String? get resolvedUserDataPath => _resolvedUserDataPath;

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _resolvedUserDataPath = null;
    _initializing = null;
  }

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

  /// Synthetic devices are opt-in for automated testing, never normal teaching.
  static const bool useTestMedia = bool.fromEnvironment('HOC_LUC_TEST_MEDIA');
  static const String chromiumAdditionalArguments = useTestMedia
      ? '--use-fake-ui-for-media-stream --use-fake-device-for-media-stream --enable-usermedia-screen-capturing'
      : '--enable-usermedia-screen-capturing';

  /// Explicitly initializes the shared WebView2 environment before any WebviewController is created.
  static Future<void> ensureInitialized({String? customPath}) async {
    if (_initialized) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    return _initializing ??= _initialize(customPath).whenComplete(() {
      _initializing = null;
    });
  }

  static Future<void> _initialize(String? customPath) async {
    try {
      final path = customPath ?? defaultUserDataPath;
      if (path.isNotEmpty) {
        final dir = Directory(path);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
      }

      await win.WebviewController.initializeEnvironment(
        userDataPath: path,
        additionalArguments: chromiumAdditionalArguments,
      );
      _resolvedUserDataPath = path;
      _initialized = true;
      debugPrint(
        '[WebviewEnvironment] Successfully initialized with profile: $_resolvedUserDataPath',
      );
    } on PlatformException catch (e) {
      _resolvedUserDataPath = null;
      if (e.code == 'environment_already_initialized') {
        // Native state survives a Dart hot restart. Its profile is unknown.
        _initialized = true;
        return;
      }
      _initialized = false;
      rethrow;
    } catch (e) {
      _initialized = false;
      _resolvedUserDataPath = null;
      rethrow;
    }
  }
}
