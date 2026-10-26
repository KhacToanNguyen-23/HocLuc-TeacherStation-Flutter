import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/main.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/join_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/schedule_classroom_dialog.dart';

void main() {
  group('Classroom Dashboard & Auth Gate tests', () {
    testWidgets(
      'CompanionApp switches between LoginScreen and ClassroomDashboardScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final auth = GoogleMeetAuthService();
        auth.signOut();

        await tester.pumpWidget(const CompanionApp());
        await tester.pumpAndSettle();

        // 1. Initial unauthenticated state: shows LoginScreen
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(ClassroomDashboardScreen), findsNothing);

        // 2. Perform sign in
        auth.signInWithOtpSession(token: 'test-token', name: 'Giáo viên');
        await tester.pumpAndSettle();

        // 3. Authenticated state: transitions to ClassroomDashboardScreen
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(ClassroomDashboardScreen), findsOneWidget);

        // Verify TopBar
        expect(find.text('HocLucStation'), findsOneWidget);
        expect(find.byType(CircleAvatar), findsOneWidget);

        // Verify 3 Action cards (single words)
        expect(find.text('Tham gia'), findsOneWidget);
        expect(find.text('Bắt đầu'), findsWidgets);
        expect(find.text('Lên lịch'), findsOneWidget);

        // Verify tabs and default tab 0 (Phòng học)
        expect(find.text('Phòng học'), findsWidgets);
        expect(find.text('Chưa có phòng học'), findsOneWidget);
        expect(find.text('Kế hoạch bài giảng'), findsOneWidget);
        expect(find.text('Lịch sử'), findsOneWidget);

        // Switch to History tab (tab 2)
        await tester.tap(find.text('Lịch sử'));
        await tester.pumpAndSettle();
        expect(find.text('Chưa có lịch sử'), findsOneWidget);

        // 4. Test Join dialog
        await tester.tap(find.text('Tham gia'));
        await tester.pumpAndSettle();
        expect(find.byType(JoinClassroomDialog), findsOneWidget);
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();

        // 5. Test Schedule dialog
        await tester.tap(find.text('Lên lịch'));
        await tester.pumpAndSettle();
        expect(find.byType(ScheduleClassroomDialog), findsOneWidget);
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();

        // 6. Test Avatar dropdown (Cài đặt & Đăng xuất)
        await tester.tap(find.byType(CircleAvatar));
        await tester.pumpAndSettle();

        expect(find.text('Cài đặt'), findsOneWidget);
        expect(find.text('Đăng xuất'), findsOneWidget);

        // Tap Logout from dropdown -> returns to LoginScreen
        await tester.tap(find.text('Đăng xuất'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(ClassroomDashboardScreen), findsNothing);
      },
    );

    testWidgets(
      'CompanionApp automatically redirects to LoginScreen when Auth session expires externally',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final auth = GoogleMeetAuthService();
        auth.signInWithDemoTeacher(name: 'Thầy Hưng', email: 'hung@hocluc.vn');

        await tester.pumpWidget(const CompanionApp());
        await tester.pumpAndSettle();

        expect(find.byType(ClassroomDashboardScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);

        // Simulate external auth loss / token expiration
        auth.signOut();
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(ClassroomDashboardScreen), findsNothing);
      },
    );
  });
}
