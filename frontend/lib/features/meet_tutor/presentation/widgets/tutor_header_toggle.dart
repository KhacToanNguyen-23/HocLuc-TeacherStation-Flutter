import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../services/tutor_controller.dart';

class TutorHeaderToggle extends StatelessWidget {
  const TutorHeaderToggle({
    super.key,
    required this.controller,
    required this.onConfigure,
  });
  final TutorController controller;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final active = controller.enabled;
      final starting = controller.starting;
      final color = active || starting
          ? AppColors.primary
          : AppColors.textSecondary;
      final tooltip = controller.config == null
          ? 'Cấu hình AI để bật nhận và tự trả lời câu hỏi'
          : starting
          ? 'Đang bật AI — nhấn để hủy'
          : active
          ? 'Tắt AI: ngừng nhận và trả lời câu hỏi'
          : 'Bật AI: nhận và tự trả lời câu hỏi\n${controller.status}';
      return Semantics(
        label: 'AI agent nhận và trả lời câu hỏi',
        toggled: active,
        child: SizedBox(
          width: 42,
          height: 42,
          child: IconButton(
            key: const ValueKey('tutor-header-toggle'),
            tooltip: tooltip,
            padding: const EdgeInsets.all(4),
            style: IconButton.styleFrom(
              backgroundColor: active || starting
                  ? AppColors.selected
                  : AppColors.surfaceMuted,
              foregroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
            ),
            onPressed: () {
              if (controller.config == null ||
                  controller.configurationPending) {
                onConfigure();
                return;
              }
              controller.setEnabled(!active && !starting);
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: const Alignment(0, -.3),
                  child: Icon(
                    active ? Icons.smart_toy_rounded : Icons.smart_toy_outlined,
                    size: 23,
                    color: color,
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    color: active || starting
                        ? AppColors.selected
                        : AppColors.surfaceMuted,
                    child: starting
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Icon(
                            active
                                ? Icons.toggle_on_rounded
                                : Icons.toggle_off_outlined,
                            size: 19,
                            color: color,
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
