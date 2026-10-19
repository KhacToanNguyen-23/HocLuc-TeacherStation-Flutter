import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/google_meet_auth_service.dart';
import 'services/webview_environment_service.dart';
import 'screens/login_screen.dart';
import 'screens/classroom_dashboard_screen.dart';
import 'widgets/meet_admission_shell.dart';
import 'services/meet_automation_service.dart';

export 'constants/theme.dart';
export 'screens/studio_screen.dart';
export 'screens/classroom_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WebviewEnvironmentService.ensureInitialized();
  await GoogleMeetAuthService().init();
  runApp(const CompanionApp());
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = GoogleMeetAuthService();

    return MaterialApp(
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
