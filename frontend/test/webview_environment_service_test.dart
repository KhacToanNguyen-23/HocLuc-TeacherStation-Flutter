import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/webview_environment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test(
      'chromiumAdditionalArguments contains fake-ui and fake-device flags',
      () {
        final args = WebviewEnvironmentService.chromiumAdditionalArguments;
        expect(args, contains('--use-fake-ui-for-media-stream'));
        expect(args, contains('--use-fake-device-for-media-stream'));
        expect(args, contains('--enable-usermedia-screen-capturing'));
      },
    );

    test('ensureInitialized handles execution gracefully', () async {
      // In flutter test runner (mock platform), ensureInitialized should complete safely
      await WebviewEnvironmentService.ensureInitialized();
      expect(WebviewEnvironmentService.isInitialized, isTrue);
    });
  });
}
