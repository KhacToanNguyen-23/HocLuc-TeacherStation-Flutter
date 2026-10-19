import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/meet_events.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';

/// Horizontal Student Gallery Strip located above the Blackboard canvas (Zoom style).
class StudioStudentStrip extends StatefulWidget {
  const StudioStudentStrip({
    super.key,
    required this.meetService,
    required this.onOpenStudentsDrawer,
  });

  final MeetAutomationService meetService;
  final VoidCallback onOpenStudentsDrawer;

  @override
  State<StudioStudentStrip> createState() => _StudioStudentStripState();
}

class _StudioStudentStripState extends State<StudioStudentStrip> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.meetService,
      builder: (context, _) {
        final participants = widget.meetService.participants;
        final hasStudents = participants.isNotEmpty;

        if (_isCollapsed) {
          // Sleek thin collapsed pill
          return Container(
            height: 24,
            margin: const EdgeInsets.fromLTRB(10, 2, 10, 2),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.overlaySurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.overlayBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 13,
                  color: AppColors.overlayAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Học sinh trực tuyến: ${participants.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.overlayAccent,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _isCollapsed = false),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          'Mở dải học sinh',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.overlayMuted,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: AppColors.overlayMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          height: 74,
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.overlaySurface,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: AppColors.overlayBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Header tag
              InkWell(
                onTap: widget.onOpenStudentsDrawer,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LỚP (${participants.length})',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.overlayAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chi tiết →',
                        style: TextStyle(
                          fontSize: 8.5,
                          color: AppColors.overlayMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(
                width: 14,
                thickness: 1,
                color: AppColors.overlayBorder,
              ),

              // Scrollable Cards of Participants
              Expanded(
                child: hasStudents
                    ? ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: participants.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final p = participants[index];
                          return _buildParticipantCard(p);
                        },
                      )
                    : const Center(
                        child: Text(
                          'Đang đợi học sinh tham gia qua Google Meet link...',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.overlayMuted,
                          ),
                        ),
                      ),
              ),

              const VerticalDivider(
                width: 14,
                thickness: 1,
                color: AppColors.overlayBorder,
              ),
              // Collapse button
              Tooltip(
                message: 'Thu gọn dải học sinh (mở rộng bảng)',
                child: InkWell(
                  onTap: () => setState(() => _isCollapsed = true),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: AppColors.overlayMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticipantCard(MeetParticipant p) {
    final initials = p.name.trim().isNotEmpty
        ? p.name.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'H';

    return Tooltip(
      message:
          '${p.name}\n${p.isMuted ? "Đã tắt mic" : "Đang bật mic"}${p.isHandRaised ? " • Đang giơ tay" : ""}',
      child: InkWell(
        onTap: () => widget.meetService.toggleMuteParticipant(p.id),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, milliseconds: 200),
          curve: AppMotion.stateCurve,
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: p.isSpeaking
                ? AppColors.overlaySelected
                : AppColors.overlayRaised,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: p.isSpeaking
                        ? AppColors.success
                        : AppColors.overlaySelected,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (p.isHandRaised)
                    Positioned(
                      right: -3,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xfff97316),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.front_hand_outlined,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),

              // Info & Mic/Cam Status
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: p.isSpeaking
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: p.isSpeaking
                            ? Colors.white
                            : AppColors.overlayText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          p.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          size: 11,
                          color: p.isMuted
                              ? AppColors.rose100
                              : AppColors.emerald100,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          p.isCameraOn
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          size: 11,
                          color: p.isCameraOn
                              ? AppColors.overlayMuted
                              : AppColors.rose100,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


