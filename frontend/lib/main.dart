import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_cubit.dart';
import 'features/auth/services/google_meet_auth_service.dart';
import 'features/classroom_meet/services/webview_environment_service.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';
import 'features/classroom_meet/presentation/meet_admission_shell.dart';
import 'features/classroom_meet/services/meet_automation_service.dart';
import 'features/classroom_meet/presentation/meet_webview.dart';

export 'core/theme/theme.dart';
export 'features/studio_board/presentation/screens/studio_screen.dart';
export 'features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();
  await WebviewEnvironmentService.ensureInitialized();
  await GoogleMeetAuthService().init();
  runApp(const CompanionApp());
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) => AuthCubit()..checkAuthStatus(),
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, current) {
          final wasAuth = prev is Authenticated;
          final isAuth = current is Authenticated;
          return wasAuth != isAuth;
        },
        listener: (context, state) {
          final nav = MeetPermissionPrompt.navigatorKey.currentState;
          if (nav == null) return;
          if (state is Authenticated) {
            nav.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const ClassroomDashboardScreen(),
              ),
              (route) => false,
            );
          } else if (state is Unauthenticated || state is AuthFailure) {
            nav.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        child: MaterialApp(
          navigatorKey: MeetPermissionPrompt.navigatorKey,
          title: 'HocLucStation',
          debugShowCheckedModeBanner: false,
          builder: (context, child) => Theme(
            data: AppTheme.light(
              reduceMotion:
                  MediaQuery.maybeOf(context)?.disableAnimations ?? false,
            ),
            child: MeetAdmissionShell(
              service: MeetAutomationService(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          theme: AppTheme.light(),
          home: BlocBuilder<AuthCubit, AuthState>(
            buildWhen: (prev, current) => false,
            builder: (context, state) {
              if (state is Authenticated) {
                return const ClassroomDashboardScreen();
              }
              return const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}
