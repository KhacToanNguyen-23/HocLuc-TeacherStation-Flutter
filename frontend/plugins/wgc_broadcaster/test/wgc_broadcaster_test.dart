import 'package:flutter_test/flutter_test.dart';
import 'package:wgc_broadcaster/wgc_broadcaster.dart';
import 'package:wgc_broadcaster/wgc_broadcaster_platform_interface.dart';
import 'package:wgc_broadcaster/wgc_broadcaster_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWgcBroadcasterPlatform
    with MockPlatformInterfaceMixin
    implements WgcBroadcasterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final WgcBroadcasterPlatform initialPlatform = WgcBroadcasterPlatform.instance;

  test('$MethodChannelWgcBroadcaster is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWgcBroadcaster>());
  });

  test('getPlatformVersion', () async {
    MockWgcBroadcasterPlatform fakePlatform = MockWgcBroadcasterPlatform();
    WgcBroadcasterPlatform.instance = fakePlatform;

    expect(await WgcBroadcaster.getPlatformVersion(), '42');
  });
}
