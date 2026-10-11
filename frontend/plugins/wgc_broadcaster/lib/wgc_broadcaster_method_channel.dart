import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'wgc_broadcaster_platform_interface.dart';

/// An implementation of [WgcBroadcasterPlatform] that uses method channels.
class MethodChannelWgcBroadcaster extends WgcBroadcasterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wgc_broadcaster');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> startBroadcast() async {
    final bool? result = await methodChannel.invokeMethod('startBroadcast');
    return result ?? false;
  }

  @override
  Future<bool> stopBroadcast() async {
    final bool? result = await methodChannel.invokeMethod('stopBroadcast');
    return result ?? false;
  }

  @override
  Future<bool> isBroadcasting() async {
    final bool? result = await methodChannel.invokeMethod('isBroadcasting');
    return result ?? false;
  }
}
