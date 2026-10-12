import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/google_meet_auth_service.dart';
import '../services/local_service.dart';
import '../widgets/auth/auth_form_card.dart';
import '../widgets/auth/auth_hero_panel.dart';

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 740;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: isCompact ? 420 : 860,
              height: isCompact ? 650 : 570,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE1E5DB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: isCompact
                  ? AuthFormCard(
                      initialTab: initialTab,
                      localService: localService,
                      authService: authService,
                    )
                  : Row(
                      children: [
                        const Expanded(
                          flex: 5,
                          child: AuthHeroPanel(),
                        ),
                        Expanded(
                          flex: 6,
                          child: AuthFormCard(
                            initialTab: initialTab,
                            localService: localService,
                            authService: authService,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
