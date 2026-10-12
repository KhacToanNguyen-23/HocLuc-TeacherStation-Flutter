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
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          final filtered = participants.where((p) {
            if (_filter.isEmpty) return true;
            return p.name.toLowerCase().contains(_filter.toLowerCase());
          }).toList();

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, size: 18, color: AppColors.sky600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Học sinh trong lớp (${participants.length})',
                        style: const TextStyle(
                          fontSize: 13,
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

              // Search Box
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _filter = val.trim()),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm học sinh...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppColors.slate400),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.slate400),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: AppColors.slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                  ),
                ),
              ),

              // Quick Actions: Mute All
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.meetService.muteAllParticipants(),
                        icon: const Icon(Icons.mic_off_rounded, size: 14),
                        label: const Text('Tắt tiếng cả lớp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rose600,
                          side: const BorderSide(color: Color(0xfffecaca)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 10, color: AppColors.line),

              // Student List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _filter.isEmpty
                              ? 'Chưa có học sinh nào trong lớp'
                              : 'Không tìm thấy học sinh phù hợp',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 8, color: Color(0x11000000)),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          return _buildParticipantRow(p);
                        },
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
                const Positioned(
                  right: -2,
                  top: -2,
                  child: Text('✋', style: TextStyle(fontSize: 11)),
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
        ],
      ),
    );
  }
}
