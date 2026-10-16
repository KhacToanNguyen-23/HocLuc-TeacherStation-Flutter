import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/services/google_meet_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final auth = GoogleMeetAuthService();
  setUp(() async {
    await auth.signOut();
    SharedPreferences.setMockInitialValues({});
    await auth.init();
  });
  tearDown(() async {
    await auth.signOut();
  });

  test(
    'Google login survives reopening without a provider access token',
    () async {
      await auth.signInWithGoogleConnection('teacher@example.com');
      // Startup reloads persisted state; no OAuth/backend dependency is needed.
      await auth.init();
      expect(auth.isSignedIn, isTrue);
      expect(auth.authMethod, 'google_oauth');
      expect(auth.teacherEmail, 'teacher@example.com');
      expect(auth.accessToken, isNull);
    },
  );

  test(
    'logout remains logged out on reopening but retains account hint',
    () async {
      await auth.signInWithGoogleConnection('teacher@example.com');
      await auth.signOut();
      await auth.init();
      expect(auth.isSignedIn, isFalse);
      expect(auth.teacherEmail, isNull);
      expect(await auth.lastGoogleConnectionEmail(), 'teacher@example.com');
    },
  );

  test('rapid login logout login persists only the final account', () async {
    final first = auth.signInWithGoogleConnection('first@example.com');
    final logout = auth.signOut();
    final second = auth.signInWithGoogleConnection('second@example.com');
    await Future.wait([first, logout, second]);
    await auth.init();
    expect(auth.isSignedIn, isTrue);
    expect(auth.teacherEmail, 'second@example.com');
    expect(await auth.lastGoogleConnectionEmail(), 'second@example.com');
  });

  test(
    'startup clears stale in-memory user when no saved session exists',
    () async {
      await auth.signInWithGoogleConnection('teacher@example.com');
      SharedPreferences.setMockInitialValues({});
      await auth.init();
      expect(auth.isSignedIn, isFalse);
      expect(auth.teacherEmail, isNull);
      expect(auth.authMethod, isNull);
      expect(auth.teacherName, isNull);
    },
  );

  test('incomplete saved Google identity requires login', () async {
    SharedPreferences.setMockInitialValues({
      'auth_is_signed_in': true,
      'auth_method': 'google_oauth',
      'auth_name': 'Incomplete',
    });
    await auth.init();
    expect(auth.isSignedIn, isFalse);
    expect(auth.teacherName, isNull);
  });

  test('switching OTP to Google removes stale credentials from disk', () async {
    auth.signInWithOtpSession(token: 'old-token', name: 'Old', phone: '123');
    await auth.signInWithGoogleConnection('teacher@example.com');
    await auth.init();
    expect(auth.teacherPhone, isNull);
    expect(auth.accessToken, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('auth_token'), isFalse);
    expect(prefs.containsKey('auth_phone'), isFalse);
  });
}
