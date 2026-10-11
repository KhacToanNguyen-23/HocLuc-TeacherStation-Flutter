import 'package:flutter/material.dart';
import 'constants/theme.dart';
import 'services/google_meet_auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/classroom_dashboard_screen.dart';

export 'constants/theme.dart';
export 'screens/studio_screen.dart';
export 'screens/classroom_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleMeetAuthService().init();
  runApp(const CompanionApp());
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = GoogleMeetAuthService();

    return MaterialApp(
      title: 'Mộc · Teaching Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Manrope',
        scaffoldBackgroundColor: AppColors.paper,
        extensions: [
          AppColorTheme.light(),
        ],
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.sky600,
          primary: AppColors.slate900,
          secondary: AppColors.sky600,
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 13, color: AppColors.slate900),
          bodySmall: TextStyle(fontSize: 11, color: AppColors.slate500),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.sky600, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sky600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          return authService.isSignedIn
              ? const ClassroomDashboardScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
