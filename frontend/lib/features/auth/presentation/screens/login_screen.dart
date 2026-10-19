import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/auth/presentation/auth_form_card.dart';
import 'package:teaching_companion/features/auth/presentation/auth_hero_panel.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';

/// Full-page dedicated 50/50 Split Login & Registration screen for teachers.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.initialTab = 0,
    this.localService,
    this.authService,
  });

  final int initialTab;
  final LocalService? localService;
  final GoogleMeetAuthService? authService;

  void _onLoginSuccess(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ClassroomDashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAuth = authService ?? GoogleMeetAuthService();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 740;

    return ListenableBuilder(
      listenable: effectiveAuth,
      builder: (context, _) {
        if (effectiveAuth.isSignedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onLoginSuccess(context);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.paper,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Container(
                  width: isCompact ? 420 : 860,
                  height: isCompact ? 650 : 570,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: isCompact
                      ? AuthFormCard(
                          initialTab: initialTab,
                          localService: localService,
                          authService: effectiveAuth,
                          onSuccess: () => _onLoginSuccess(context),
                        )
                      : Row(
                          children: [
                            const Expanded(flex: 5, child: AuthHeroPanel()),
                            Expanded(
                              flex: 6,
                              child: AuthFormCard(
                                initialTab: initialTab,
                                localService: localService,
                                authService: effectiveAuth,
                                onSuccess: () => _onLoginSuccess(context),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

