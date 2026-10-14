import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/screens/classroom_lobby_screen.dart';
import 'package:teaching_companion/screens/studio_screen.dart';
import 'package:teaching_companion/services/google_meet_auth_service.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/services/teacher_media_service.dart';

void main() {
  group('ClassroomLobbyScreen Pre-flight Check tests', () {
    testWidgets('renders all Lobby components, checks hardware, and navigates to Studio', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authService = GoogleMeetAuthService();
      authService.signInWithDemoTeacher(
        name: 'Thầy Khắc Toàn',
        email: 'toan.nguyen@fpt.edu.vn',
      );

      final mediaService = TeacherMediaService();
      final meetService = MeetAutomationService();
      meetService.setMeetingUrl('https://meet.google.com/abc-defg-hij');

      await tester.pumpWidget(
        MaterialApp(
          home: ClassroomLobbyScreen(
            initialLessonTitle: 'Toán 12: Khảo sát hàm số',
            mediaService: mediaService,
            authService: authService,
            meetService: meetService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Top Bar & Google Account Status
      expect(find.text('LOBBY'), findsOneWidget);
      expect(find.text('Chuẩn bị phòng giảng dạy'), findsOneWidget);
      expect(find.text('Google: toan.nguyen@fpt.edu.vn'), findsOneWidget);

      // 2. Verify Hardware Section (Left)
      expect(find.text('Kiểm tra Thiết bị & Hình ảnh'), findsOneWidget);
      // Widget tests have no physical camera attached: camera is off by default
      expect(find.byTooltip('Bật Camera'), findsOneWidget);
      expect(find.byTooltip('Tắt Micro'), findsOneWidget);

      // Toggle Camera
      await tester.tap(find.byTooltip('Bật Camera'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bật Camera'), findsOneWidget);

      // Toggle Mic
      await tester.tap(find.byTooltip('Tắt Micro'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bật Micro'), findsOneWidget);

      // 3. Verify Lesson Info (Right)
      expect(find.text('Thông tin Buổi học'), findsOneWidget);
      expect(find.text('Toán 12: Khảo sát hàm số'), findsOneWidget);

      // 4. Verify Google Meet Card (Right)
      expect(find.text('Kênh Phát sóng Google Meet'), findsOneWidget);
      expect(find.text('https://meet.google.com/abc-defg-hij'), findsOneWidget);
      expect(find.text('Sao chép'), findsOneWidget);
      expect(find.text('Tạo link khác'), findsOneWidget);

      // Tap Copy button
      await tester.tap(find.text('Sao chép'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã sao chép link lớp học'), findsOneWidget);

      // 6. Test CTA Button: BẮT ĐẦU VÀO PHÒNG GIẢNG DẠY -> navigates to StudioScreen
      expect(find.text('BẮT ĐẦU VÀO PHÒNG GIẢNG DẠY'), findsOneWidget);
      await tester.tap(find.text('BẮT ĐẦU VÀO PHÒNG GIẢNG DẠY'));
      await tester.pumpAndSettle();

      // Verify that StudioScreen is now pushed and active
      expect(find.byType(StudioScreen), findsOneWidget);
      expect(find.byType(ClassroomLobbyScreen), findsNothing);
    });

    testWidgets('shows warning modal when attempting to enter studio without real Google Meet link', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authService = GoogleMeetAuthService();
      authService.signInWithDemoTeacher();

      final mediaService = TeacherMediaService();
      final meetService = MeetAutomationService();
      meetService.setMeetingUrl(''); // Empty link

      await tester.pumpWidget(
        MaterialApp(
          home: ClassroomLobbyScreen(
            mediaService: mediaService,
            authService: authService,
            meetService: meetService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that offline automated action buttons are shown
      expect(find.text('Tự động tạo phòng Meet'), findsOneWidget);
      expect(find.text('Dán link phòng có sẵn'), findsOneWidget);

      // Tap enter classroom button
      await tester.tap(find.text('BẮT ĐẦU VÀO PHÒNG GIẢNG DẠY'));
      await tester.pumpAndSettle();

      // Verify that warning dialog popped up
      expect(find.text('Chưa có link Google Meet'), findsOneWidget);
      expect(find.text('Vào dạy ngoại tuyến'), findsOneWidget);

      // Tap still proceed offline
      await tester.tap(find.text('Vào dạy ngoại tuyến'));
      await tester.pumpAndSettle();

      expect(find.byType(StudioScreen), findsOneWidget);
    });
  });
}
