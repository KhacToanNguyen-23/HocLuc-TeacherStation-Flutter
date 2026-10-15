import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/meet_events.dart';
import '../../services/meet_automation_service.dart';

/// Right-side slideout panel for managing online students, Mute All, and raising hands.
class StudioStudentsDrawer extends StatefulWidget {
  const StudioStudentsDrawer({
    super.key,
    required this.meetService,
    required this.onClose,
  });

  final MeetAutomationService meetService;
  final VoidCallback onClose;

  @override
  State<StudioStudentsDrawer> createState() => _StudioStudentsDrawerState();
}

class _StudioStudentsDrawerState extends State<StudioStudentsDrawer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: ListenableBuilder(
        listenable: widget.meetService,
        builder: (context, _) {
          final participants = widget.meetService.participants;

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, size: 19, color: AppColors.sky600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Người tham gia (${participants.length + 1})',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
                      onPressed: widget.onClose,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // Host (Teacher) Row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.sky600,
                        child: Text('GV', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bạn (Chủ phòng)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate900),
                            ),
                            Text(
                              'Giáo viên giảng dạy',
                              style: TextStyle(fontSize: 10, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.mic_rounded, size: 16, color: AppColors.emerald600),
                    ],
                  ),
                ),
              ),

              const Divider(height: 16, color: AppColors.line),

              // Student List
              Expanded(
                child: participants.isEmpty
                    ? const Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_outlined, size: 36, color: AppColors.slate300),
                              SizedBox(height: 10),
                              Text(
                                'Đang đợi học sinh tham gia...',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Chia sẻ link lớp học để học sinh vào phòng',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10.5, color: AppColors.slate400),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: participants.length,
                        separatorBuilder: (_, _) => const Divider(height: 8, color: Color(0x11000000)),
                        itemBuilder: (context, index) {
                          final p = participants[index];
                          return _buildParticipantRow(p);
                        },
                      ),
              ),

              // Footer (Zoom Style: Mute All at bottom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: participants.isEmpty ? null : () => widget.meetService.muteAllParticipants(),
                        icon: const Icon(Icons.mic_off_rounded, size: 14),
                        label: const Text('Tắt tiếng tất cả', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rose600,
                          side: const BorderSide(color: Color(0xfffecaca)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildParticipantRow(MeetParticipant p) {
    final initials = p.name.trim().isNotEmpty
        ? p.name.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'H';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: p.isSpeaking ? AppColors.emerald600 : const Color(0xffe2e8f0),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: p.isSpeaking ? Colors.white : AppColors.slate700,
                  ),
                ),
              ),
              if (p.isHandRaised)
                Positioned(
                  right: -2,
                  top: -2,
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
          const SizedBox(width: 8),

          // Name and status subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: p.isSpeaking ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                Text(
                  p.isSpeaking
                      ? 'Đang phát biểu...'
                      : p.isHandRaised
                      ? 'Đang giơ tay'
                      : p.isMuted
                      ? 'Đã tắt tiếng'
                      : 'Micro sẵn sàng',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: p.isSpeaking
                        ? AppColors.emerald600
                        : p.isHandRaised
                        ? const Color(0xfff97316)
                        : AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),

          // Lower Hand Button if raised
          if (p.isHandRaised)
            IconButton(
              icon: const Icon(Icons.pan_tool_outlined, size: 14, color: Color(0xfff97316)),
              tooltip: 'Hạ tay',
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.meetService.lowerHandParticipant(p.id),
            ),

          // Mute / Unmute Button
          IconButton(
            icon: Icon(
              p.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              size: 16,
              color: p.isMuted ? AppColors.rose500 : AppColors.emerald600,
            ),
            tooltip: p.isMuted ? 'Mở mic cho học sinh' : 'Tắt mic học sinh',
            visualDensity: VisualDensity.compact,
            onPressed: () => widget.meetService.toggleMuteParticipant(p.id),
          ),

          // Kick / Remove from call Button
          IconButton(
            icon: const Icon(
              Icons.person_remove_outlined,
              size: 16,
              color: AppColors.rose500,
            ),
            tooltip: 'Mời học sinh ra khỏi phòng',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmRemoveParticipant(p),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveParticipant(MeetParticipant p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.rose600, size: 22),
            SizedBox(width: 8),
            Text('Mời ra khỏi phòng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn mời học sinh "${p.name}" ra khỏi lớp học Google Meet không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: AppColors.slate600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.meetService.removeParticipant(p.id, p.name);
            },
            child: const Text('Mời ra'),
          ),
        ],
      ),
    );
  }
}
