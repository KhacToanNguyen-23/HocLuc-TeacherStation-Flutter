import 'dart:async';
import 'wgc_broadcaster_platform_interface.dart';

class WgcBroadcaster {
  /// Khởi động luồng phát sóng (Capture bảng trắng và đẩy lên Virtual Camera).
  static Future<bool> startBroadcast() {
    return WgcBroadcasterPlatform.instance.startBroadcast();
  }

  /// Dừng phát sóng.
  static Future<bool> stopBroadcast() {
    return WgcBroadcasterPlatform.instance.stopBroadcast();
  }

  /// Kiểm tra trạng thái phát sóng.
  static Future<bool> isBroadcasting() {
    return WgcBroadcasterPlatform.instance.isBroadcasting();
  }

  /// Phiên bản platform (dành cho integration test).
  static Future<String?> getPlatformVersion() {
    return WgcBroadcasterPlatform.instance.getPlatformVersion();
  }
}
