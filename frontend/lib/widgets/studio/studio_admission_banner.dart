import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/meet_automation_service.dart';

/// Floating toast banner alerting teacher when students knock to join the Google Meet room.
class StudioAdmissionBanner extends StatelessWidget {
  const StudioAdmissionBanner({
    super.key,
    required this.meetService,
  });

  final MeetAutomationService meetService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: meetService,
      builder: (context, _) {
        final count = meetService.pendingAdmitCount;
        if (count <= 0 || meetService.linkedTeacherEmail != null) return const SizedBox.shrink();

        return Positioned(
          top: 12,
          right: 20,
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sky600, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.sky600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Có $count học sinh xin vào lớp',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Yêu cầu tham gia từ Google Meet',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton(
                    onPressed: () => meetService.admitAllPending(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Cho vào tất cả',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      meetService.autoAdmitEnabled = !meetService.autoAdmitEnabled;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: meetService.autoAdmitEnabled
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: meetService.autoAdmitEnabled
                              ? const Color(0xFFFBBF24)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            meetService.autoAdmitEnabled
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            size: 13,
                            color: meetService.autoAdmitEnabled
                                ? const Color(0xFFFBBF24)
                                : AppColors.slate400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            meetService.autoAdmitEnabled ? 'Tự động: BẬT' : 'Tự động: TẮT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: meetService.autoAdmitEnabled
                                  ? const Color(0xFFFBBF24)
                                  : AppColors.slate300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
