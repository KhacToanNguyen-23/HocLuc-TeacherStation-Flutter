import '../meet_admission_button.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/auth/presentation/google_webview_login_dialog.dart';

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
        child: Divider(height: 1, color: AppColors.border),
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
              color: AppColors.selected,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'LOBBY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.onSelected,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Chuẩn bị phòng giảng dạy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        const MeetAdmissionButton(),
        ListenableBuilder(
          listenable: authService,
          builder: (context, _) {
            final isSignedIn = authService.isGoogleAuthenticated;
            final email = authService.teacherEmail ?? 'toan.nguyen@fpt.edu.vn';

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                onTap: () => GoogleWebviewLoginDialog.show(
                  context,
                  authService: authService,
                ),
                borderRadius: BorderRadius.circular(AppRadii.panel),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSignedIn
                        ? AppColors.successSurface
                        : AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                    border: Border.all(
                      color: isSignedIn ? AppColors.border : AppColors.warning,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSignedIn
                            ? Icons.check_circle_rounded
                            : Icons.account_circle_outlined,
                        size: 14,
                        color: isSignedIn
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSignedIn ? 'Google: $email' : 'Chưa liên kết Google',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSignedIn
                              ? AppColors.success
                              : AppColors.warning,
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


