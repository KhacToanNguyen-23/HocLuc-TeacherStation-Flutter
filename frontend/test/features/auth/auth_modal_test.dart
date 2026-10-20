import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/auth/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/auth/presentation/flat_auth_modal.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GoogleMeetAuthService session tests', () {
    test('signInWithOtpSession updates credentials and notifies', () {
      final auth = GoogleMeetAuthService();
      auth.signOut();
      expect(auth.isSignedIn, isFalse);

      auth.signInWithOtpSession(
        token: 'test-otp-token',
        name: 'Cô Nguyễn Thị Hoa',
        phone: '+84912345678',
      );

      expect(auth.isSignedIn, isTrue);
      expect(auth.accessToken, 'test-otp-token');
      expect(auth.teacherName, 'Cô Nguyễn Thị Hoa');
      expect(auth.teacherPhone, '+84912345678');

      auth.signOut();
      expect(auth.isSignedIn, isFalse);
      expect(auth.accessToken, isNull);
      expect(auth.teacherName, isNull);
      expect(auth.teacherPhone, isNull);
    });
  });

  group('FlatAuthModal widget tests', () {
    testWidgets('renders Password Login and Verification Signup flow', (
      tester,
    ) async {
      // Set desktop screen size
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FlatAuthModal(initialTab: 0))),
      );

      // Verify hero panel renders SVG illustration exclusively with zero text
      expect(find.byType(SvgPicture), findsOneWidget);

      // 1. Verify Login form inputs (Viền vuông, Email/Phone + Password)
      expect(find.text('Email hoặc số điện thoại'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.byTooltip('Đăng nhập bằng Google'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);

      // 2. Click chữ nhỏ "Đăng ký" -> Chuyển sang form Đăng ký chuẩn ảnh mẫu
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký tài khoản'), findsOneWidget);
      expect(find.text('+84'), findsOneWidget);
      expect(find.text('Nhập mã xác thực'), findsOneWidget);
      expect(find.text('Gửi mã'), findsOneWidget);
      expect(find.text('Nhập mật khẩu'), findsOneWidget);
      expect(
        find.text('Tôi đồng ý với Điều khoản & Chính sách bảo mật'),
        findsOneWidget,
      );
      expect(find.text('Quay lại'), findsOneWidget); // Chữ nhỏ dưới nút signup

      // 3. Click chữ nhỏ "Quay lại" -> Trở về form Đăng nhập
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();

      expect(find.text('Email hoặc số điện thoại'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);

      // 4. Test session sign in
      final auth = GoogleMeetAuthService();
      auth.signOut();
      expect(auth.isSignedIn, isFalse);

      auth.signInWithOtpSession(
        token: 'test-token',
        name: 'Giáo viên Real',
        phone: '+84988888888',
      );
      expect(auth.isSignedIn, isTrue);
      expect(auth.teacherPhone, '+84988888888');
    });
  });
}

