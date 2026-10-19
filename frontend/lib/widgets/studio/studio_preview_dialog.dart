import '../meet_admission_button.dart';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../stage_container.dart';
import 'studio_question_view.dart';

class StudioPreviewDialog extends StatelessWidget {
  const StudioPreviewDialog({super.key, required this.studio});

  final StudioState studio;

  static void show(BuildContext context, StudioState studio) {
    showDialog<void>(
      context: context,
      builder: (_) => StudioPreviewDialog(studio: studio),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xff101e19),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.crop_landscape, color: AppColors.lime),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Xem trước bảng trình bày',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const MeetAdmissionButton(color: Colors.white),
                IconButton(
                  tooltip: 'Đóng xem trước',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedBuilder(
                animation: studio,
                builder: (_, _) {
                  if (studio.view == 'question') {
                    return StudioQuestionView(
                      studio: studio,
                      interactive: false,
                    );
                  }
                  return StageContainer(studio: studio, interactive: false);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
