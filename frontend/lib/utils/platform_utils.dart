import 'package:flutter/foundation.dart';

/// Centralized utility for multi-platform checks across Windows desktop and Web.
class PlatformUtils {
  const PlatformUtils._();

  /// True if running on Native Windows Desktop (supports WebView2 and Native Window features)
  static bool get isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// True if running on Web Browser
  static bool get isWeb => kIsWeb;

  /// True if running on Desktop (Windows, macOS, Linux)
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);
}
