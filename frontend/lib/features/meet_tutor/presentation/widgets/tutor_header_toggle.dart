import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../services/tutor_controller.dart';

class TutorHeaderToggle extends StatefulWidget {
  const TutorHeaderToggle({super.key, required this.controller});
  final TutorController controller;

  @override
  State<TutorHeaderToggle> createState() => _TutorHeaderToggleState();
}

class _TutorHeaderToggleState extends State<TutorHeaderToggle> {
  TutorController get controller => widget.controller;
  String? _shownError;
  int _errorSequence = 0;

  @override
  void initState() {
    super.initState();
    _shownError = controller.activationError;
    controller.addListener(_activationChanged);
  }

  @override
  void didUpdateWidget(TutorHeaderToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_activationChanged);
      controller.addListener(_activationChanged);
      _shownError = controller.activationError;
      _errorSequence++;
    }
  }

  void _activationChanged() {
    final error = controller.activationError;
    if (_shownError == error) return;
    _shownError = error;
    final sequence = ++_errorSequence;
    if (error == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          sequence == _errorSequence &&
          controller.activationError == error) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error)));
      }
    });
  }

  @override
  void dispose() {
    controller.removeListener(_activationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final active = controller.enabled;
      final starting = controller.starting;
      final recovering = controller.recovering;
      final waiting = starting || recovering;
      final color = active && !recovering
          ? Colors.white
          : waiting
          ? AppColors.primary
          : AppColors.textSecondary;
      final background = active && !recovering
          ? AppColors.primary
          : waiting
          ? AppColors.selected
          : AppColors.surfaceMuted;
      final tooltip = controller.config == null
          ? 'Trợ giảng chưa sẵn sàng'
          : starting
          ? 'Đang bật AI — nhấn để hủy'
          : recovering
          ? '${controller.displayStatus}\nNhấn để tắt AI và hủy kết nối lại.'
          : active
          ? 'Tắt AI: ngừng tự đọc và trả lời câu hỏi Meet'
          : 'Bật AI: tự đọc và trả lời câu hỏi, không cần mở panel Meet\n${controller.status}';
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
              backgroundColor: background,
              foregroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
            ),
            onPressed: controller.config == null
                ? null
                : () => controller.setEnabled(!active && !starting),
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
                    color: background,
                    child: waiting
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
