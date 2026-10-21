import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/classroom_meet/services/google_meet_auth_service.dart';
import 'features/classroom_meet/services/webview_environment_service.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';
import 'features/classroom_meet/presentation/meet_admission_shell.dart';
import 'features/classroom_meet/services/meet_automation_service.dart';
import 'features/classroom_meet/presentation/meet_webview.dart';
import 'features/studio_board/presentation/screens/audience_screen.dart';
import 'core/network/local_service.dart';
import 'features/exams/services/exam_api.dart';

export 'core/theme/theme.dart';
export 'features/studio_board/presentation/screens/studio_screen.dart';
export 'features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.contains('--audience')) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'HocLuc Audience',
        theme: AppTheme.light(),
        home: const AudienceScreen(),
      ),
    );
    return;
  }
  await WebviewEnvironmentService.ensureInitialized();
  await GoogleMeetAuthService().init();
  LocalService.appSessionProvider = ({required bool forceRefresh}) async {
    final api = ExamApi();
    try {
      await api.ensureSession(
        rejectedToken: forceRefresh ? api.auth.appSessionToken : null,
      );
      return api.auth.appSessionToken;
    } finally {
      api.client.close();
    }
  };
  runApp(const CompanionApp());
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = GoogleMeetAuthService();

    return MaterialApp(
      navigatorKey: MeetPermissionPrompt.navigatorKey,
      title: 'HocLucStation',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Theme(
        data: AppTheme.light(
          reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
        ),
        child: MeetAdmissionShell(
          service: MeetAutomationService(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      theme: AppTheme.light(),
      home: ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          if (!authService.isSignedIn) {
            return const LoginScreen();
          }
          return const ClassroomDashboardScreen();
        },
      ),
    );
  }
}
