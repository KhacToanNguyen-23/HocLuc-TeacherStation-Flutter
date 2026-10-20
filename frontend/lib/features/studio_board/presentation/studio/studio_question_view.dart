import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import '../presentation_surface.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/floating_pip.dart';

class StudioQuestionView extends StatelessWidget {
  const StudioQuestionView({
    super.key,
    required this.studio,
    this.interactive = true,
  });

  final StudioState studio;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    // The screen shell no longer rebuilds on every studio change, so the
    // question view subscribes to the studio itself.
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) => _buildView(context),
    );
  }

  Widget _buildView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * 16 / 9,
        );
        return Center(
          child: SizedBox(
            width: width,
            height: width * 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PresentationSurface(
                  studio: studio,
                  manageCamera: interactive,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: const Color(0xff14221d),
                      child: LayoutBuilder(
                        builder: (context, box) => Padding(
                          padding: EdgeInsets.all(box.maxWidth * .06),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CÙNG SUY NGHĨ / Q1',
                                style: TextStyle(
                                  fontSize: box.maxWidth * .015,
                                  letterSpacing: 2,
                                  color: AppColors.muted,
                                ),
                              ),
                              SizedBox(height: box.maxHeight * .05),
                              Expanded(
                                child: Text(
                                  studio.question,
                                  style: TextStyle(
                                    fontFamily: 'Literata',
                                    fontSize: box.maxWidth * .031,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  for (final (i, option) in [
                                    '(−1; −4)',
                                    '(1; −4)',
                                    '(1; 4)',
                                    '(−1; 4)',
                                  ].indexed)
                                    Container(
                                      width: (box.maxWidth * .88 - 12) / 2,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: studio.reveal && i == 1
                                            ? AppColors.lime
                                            : const Color(0xfff2f3e9),
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.control,
                                        ),
                                      ),
                                      child: Text(
                                        '${String.fromCharCode(65 + i)}. $option',
                                        style: TextStyle(
                                          fontSize: box.maxWidth * .022,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: box.maxHeight * .04),
                              Text(
                                studio.reveal
                                    ? 'Đáp án mẫu: B · x = −b/2a = 1; y = −4.'
                                    : 'Trả lời trong chat Meet theo mẫu: Q1 A / Q1 B / Q1 C / Q1 D',
                                style: TextStyle(
                                  fontSize: box.maxWidth * .014,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (interactive)
                  Positioned.fill(child: FloatingPip(studio: studio)),
              ],
            ),
          ),
        );
      },
    );
  }
}

