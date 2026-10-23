import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

class StudioSpeakerNotesToggle extends StatelessWidget {
  const StudioSpeakerNotesToggle({required this.studio, super.key});

  final StudioState studio;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: studio.showSpeakerNotes
        ? 'Ẩn ghi chú nhắc bài'
        : 'Hiện ghi chú nhắc bài',
    iconSize: 18,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    onPressed: studio.toggleSpeakerNotes,
    style: IconButton.styleFrom(
      backgroundColor: studio.showSpeakerNotes
          ? AppColors.selected
          : Colors.transparent,
    ),
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          studio.showSpeakerNotes
              ? Icons.sticky_note_2
              : Icons.sticky_note_2_outlined,
          color: studio.showSpeakerNotes ? AppColors.primary : AppColors.pine,
        ),
        if (studio.currentPageNote.trim().isNotEmpty)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );
}
