import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'wgc_broadcaster_method_channel.dart';

abstract class WgcBroadcasterPlatform extends PlatformInterface {
  WgcBroadcasterPlatform() : super(token: _token);

  static final Object _token = Object();
  static WgcBroadcasterPlatform _instance = MethodChannelWgcBroadcaster();

  static WgcBroadcasterPlatform get instance => _instance;

  static set instance(WgcBroadcasterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<bool> startBroadcast() {
    throw UnimplementedError('startBroadcast() has not been implemented.');
  }

  Future<bool> stopBroadcast() {
    throw UnimplementedError('stopBroadcast() has not been implemented.');
  }

  Future<bool> isBroadcasting() {
    throw UnimplementedError('isBroadcasting() has not been implemented.');
  }
}
