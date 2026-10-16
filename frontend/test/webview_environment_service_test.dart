import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/webview_environment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(WebviewEnvironmentService.resetForTesting);
  tearDown(WebviewEnvironmentService.resetForTesting);

  group('WebviewEnvironmentService Tests', () {
    test('defaultUserDataPath generates valid Windows profile path', () {
      final path = WebviewEnvironmentService.defaultUserDataPath;
      if (!kIsWeb && Platform.isWindows) {
        expect(path, contains('HocLucTeacherStation'));
        expect(path, contains('EdgeProfile'));
      } else {
        expect(path, isNotNull);
      }
    });

    test('normal teaching uses real media devices', () {
      final args = WebviewEnvironmentService.chromiumAdditionalArguments;
      expect(WebviewEnvironmentService.useTestMedia, isFalse);
      expect(args, isNot(contains('--use-fake-ui-for-media-stream')));
      expect(args, isNot(contains('--use-fake-device-for-media-stream')));
      expect(args, contains('--enable-usermedia-screen-capturing'));
    });

    test(
      'unsupported platforms do not claim a native profile is ready',
      () async {
        await WebviewEnvironmentService.ensureInitialized();
        expect(WebviewEnvironmentService.isInitialized, isFalse);
      },
    );

    testWidgets(
      'native environment survives hot restart without claiming its profile',
      (tester) async {
        const channel = MethodChannel('io.jns.webview.win');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw PlatformException(code: 'environment_already_initialized');
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await WebviewEnvironmentService.ensureInitialized();
        expect(WebviewEnvironmentService.isInitialized, isTrue);
        expect(WebviewEnvironmentService.resolvedUserDataPath, isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'native failure is retryable and concurrent callers share initialization',
      (tester) async {
        const channel = MethodChannel('io.jns.webview.win');
        var calls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls++;
              if (calls == 1) {
                throw PlatformException(code: 'runtime_unavailable');
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final path = '${Directory.systemTemp.path}/hocluc-webview-test';
        await expectLater(
          WebviewEnvironmentService.ensureInitialized(customPath: path),
          throwsA(isA<PlatformException>()),
        );
        expect(WebviewEnvironmentService.isInitialized, isFalse);
        expect(WebviewEnvironmentService.resolvedUserDataPath, isNull);
        await Future.wait([
          WebviewEnvironmentService.ensureInitialized(customPath: path),
          WebviewEnvironmentService.ensureInitialized(customPath: path),
        ]);
        expect(calls, 2);
        expect(WebviewEnvironmentService.isInitialized, isTrue);
        expect(WebviewEnvironmentService.resolvedUserDataPath, path);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  });
}
