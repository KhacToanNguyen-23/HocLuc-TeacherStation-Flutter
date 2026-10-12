import 'package:flutter/material.dart';
import '../../services/google_meet_auth_service.dart';
import '../../services/local_service.dart';
import 'auth_form_card.dart';
import 'auth_hero_panel.dart';

/// Flat-inspired 50/50 split authentication modal for teachers.
class FlatAuthModal extends StatelessWidget {
  const FlatAuthModal({
    super.key,
    this.initialTab = 0,
    this.localService,
    this.authService,
  });

  final int initialTab; // 0: Login, 1: Signup
  final LocalService? localService;
  final GoogleMeetAuthService? authService;

  static Future<bool?> show(
    BuildContext context, {
    int initialTab = 0,
    LocalService? localService,
    GoogleMeetAuthService? authService,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => FlatAuthModal(
        initialTab: initialTab,
        localService: localService,
        authService: authService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: 860,
          height: 570,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Branding Side
              const Expanded(
                flex: 5,
                child: AuthHeroPanel(),
              ),

              // Form Side
              Expanded(
                flex: 6,
                child: AuthFormCard(
                  initialTab: initialTab,
                  localService: localService,
                  authService: authService,
                  showCloseButton: true,
                  onClose: () => Navigator.of(context).pop(),
                  onSuccess: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
