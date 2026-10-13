import 'dart:async';
import 'package:flutter/services.dart';
import 'wgc_broadcaster_platform_interface.dart';

class WgcBroadcaster {
  /// Sends an RGBA presentation frame. Returns whether a receiver requested it.
  static Future<bool> sendFrame(int width, int height, Uint8List rgba) async {
    return await const MethodChannel('wgc_broadcaster').invokeMethod<bool>(
          'sendFrame',
          {'width': width, 'height': height, 'rgba': rgba},
        ) ??
        false;
  }

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
