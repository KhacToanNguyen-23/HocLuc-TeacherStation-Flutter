import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/google_meet_auth_service.dart';
import '../auth/google_oauth_connect_dialog.dart';

/// Top AppBar header for ClassroomLobbyScreen with Lobby tag and Google account pill.
class LobbyHeader extends StatelessWidget implements PreferredSizeWidget {
  const LobbyHeader({
    super.key,
    required this.authService,
    required this.onBack,
  });

  final GoogleMeetAuthService authService;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.slate200),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slate700),
        tooltip: 'Quay lại Trang chủ',
        onPressed: onBack,
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: const Text(
              'LOBBY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4338CA),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Chuẩn bị phòng giảng dạy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
            ),
          ),
        ],
      ),
      actions: [
        ListenableBuilder(
          listenable: authService,
          builder: (context, _) {
            final isSignedIn = authService.isGoogleAuthenticated;
            final email = authService.googleEmail ?? '';

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                onTap: () => GoogleOAuthConnectDialog.show(context, authService: authService),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSignedIn ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSignedIn ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSignedIn ? Icons.check_circle_rounded : Icons.account_circle_outlined,
                        size: 14,
                        color: isSignedIn ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSignedIn ? 'Google: $email' : 'Chưa liên kết Google',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSignedIn ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
