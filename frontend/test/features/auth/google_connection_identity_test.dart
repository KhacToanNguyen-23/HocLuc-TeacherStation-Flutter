import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';

void main() {
  test(
    'OAuth identity persists without copying provider tokens or stale profile',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'old-webview-marker',
        'auth_avatar': 'old-avatar',
        'auth_phone': 'old-phone',
      });
      final auth = GoogleMeetAuthService();
      await auth.signInWithGoogleConnection('selected@example.com');
      expect(auth.teacherEmail, 'selected@example.com');
      expect(auth.isGoogleAuthenticated, true);
      expect(auth.accessToken, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_avatar'), isNull);
      expect(prefs.getString('auth_phone'), isNull);
      await auth.init();
      expect(auth.teacherEmail, 'selected@example.com');
      expect(auth.authMethod, 'google_oauth');
      auth.signOut();
      expect(await auth.lastGoogleConnectionEmail(), 'selected@example.com');
    },
  );
}

