import 'package:flutter/material.dart';
import '../models/studio_state.dart';

class FloatingTimer extends StatefulWidget {
  const FloatingTimer({super.key, required this.studio});

  final StudioState studio;

  @override
  State<FloatingTimer> createState() => _FloatingTimerState();
}

class _FloatingTimerState extends State<FloatingTimer> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.studio,
      builder: (context, _) {
        final studio = widget.studio;
        final minutes = studio.seconds ~/ 60;
        final secs = studio.seconds % 60;
        final timeStr =
            '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        final isZero = studio.seconds == 0 && !studio.timerRunning;
        final isRunning = studio.timerRunning;

        final borderColor = isZero
            ? const Color(0xffff6b6b)
            : isRunning
            ? const Color(0xffd4e8a6)
            : const Color(0x33ffffff);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill Badge
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xee14221d),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: isRunning
                          ? const Color(0x44d4e8a6)
                          : isZero
                          ? const Color(0x44ff6b6b)
                          : const Color(0x33000000),
                      blurRadius: isRunning || isZero ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRunning
                          ? Icons.timer_outlined
                          : isZero
                          ? Icons.alarm_on
                          : Icons.hourglass_empty,
                      size: 15,
                      color: isZero
                          ? const Color(0xffff6b6b)
                          : isRunning
                          ? const Color(0xffd4e8a6)
                          : const Color(0xffc5d2c8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isZero
                            ? const Color(0xffff6b6b)
                            : isRunning
                            ? const Color(0xffd4e8a6)
                            : const Color(0xffe8eae6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 14,
                      color: const Color(0xff8a9a8d),
                    ),
                  ],
                ),
              ),
            ),

            // Popover Controls Card
            if (_isExpanded)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xf5101a15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x33ffffff)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preset Duration Chips
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _presetChip('2p', 120),
                        const SizedBox(width: 6),
                        _presetChip('5p', 300),
                        const SizedBox(width: 6),
                        _presetChip('10p', 600),
                        const SizedBox(width: 6),
                        _presetChip('15p', 900),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: studio.addTimerMinute,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x22ffffff),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '+1p',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xffd4e8a6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0x22ffffff), height: 1),
                    const SizedBox(height: 10),

                    // Action Controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: studio.toggleTimer,
                          style: FilledButton.styleFrom(
                            backgroundColor: isRunning
                                ? const Color(0xffe57373)
                                : const Color(0xffd4e8a6),
                            foregroundColor: const Color(0xff14221d),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            isRunning ? Icons.pause : Icons.play_arrow,
                            size: 15,
                          ),
                          label: Text(
                            isRunning ? 'Tạm dừng' : 'Bắt đầu',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => studio.resetTimer(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xffc5d2c8),
                            side: const BorderSide(color: Color(0x33ffffff)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text(
                            'Đặt lại',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Đóng cài đặt',
                          onPressed: () => setState(() => _isExpanded = false),
                          icon: const Icon(
                            Icons.close,
                            size: 15,
                            color: Color(0xff8a9a8d),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _presetChip(String label, int seconds) {
    final studio = widget.studio;
    final isSelected = studio.seconds == seconds;
    return InkWell(
      onTap: () => studio.setTimerSeconds(seconds),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffd4e8a6) : const Color(0x22ffffff),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? const Color(0xff14221d)
                : const Color(0xffe8eae6),
          ),
        ),
      ),
    );
  }
}
