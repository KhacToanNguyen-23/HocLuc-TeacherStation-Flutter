import 'package:flutter/material.dart';
import '../models/studio_state.dart';

class FloatingPip extends StatelessWidget {
  const FloatingPip({super.key, required this.studio});

  final StudioState studio;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        if (!studio.showCameraPip) {
          return const SizedBox.shrink();
        }

        if (studio.pipMinimized) {
          return Positioned(
            top: studio.pipPosition.dy,
            right: studio.pipPosition.dx,
            child: GestureDetector(
              onPanUpdate: (details) => _handleDrag(details, context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xee14221d),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x33ffffff)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_outlined,
                      size: 15,
                      color: Color(0xffd4e8a6),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Webcam GV',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffe8eae6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: studio.togglePipMinimized,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.open_in_full,
                          size: 13,
                          color: Color(0xffa5b5a8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Positioned(
          top: studio.pipPosition.dy,
          right: studio.pipPosition.dx,
          child: GestureDetector(
            onPanUpdate: (details) => _handleDrag(details, context),
            child: Container(
              width: 240,
              height: 135,
              decoration: BoxDecoration(
                color: const Color(0xf20e1814),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x44d4e8a6), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Simulated Camera Feed Background
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xff12201a), Color(0xff09110d)],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0x33d4e8a6),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x55d4e8a6),
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'GV',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xffd4e8a6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Giáo viên giảng dạy',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xffa0b3a5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Bar Controls
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: const Color(0x66000000),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.drag_indicator,
                            size: 13,
                            color: Color(0x88ffffff),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Webcam GV',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xddffffff),
                            ),
                          ),
                          const SizedBox(width: 5),
                          // Live indicator
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xff4ade80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Spacer(),
                          // Minimize button
                          InkWell(
                            onTap: studio.togglePipMinimized,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.remove,
                                size: 14,
                                color: Color(0xffc5d2c8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Close button
                          InkWell(
                            onTap: studio.toggleCameraPip,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Color(0xffc5d2c8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Info Bar
                  Positioned(
                    bottom: 6,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x55000000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '1080p · 30fps',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xff8a9a8d),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x334ade80),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0x664ade80)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mic,
                                size: 9,
                                color: Color(0xff4ade80),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Mic ON',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff4ade80),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  void _handleDrag(DragUpdateDetails details, BuildContext context) {
    final newRight = (studio.pipPosition.dx - details.delta.dx).clamp(
      8.0,
      800.0,
    );
    final newTop = (studio.pipPosition.dy + details.delta.dy).clamp(8.0, 500.0);
    studio.setPipPosition(Offset(newRight, newTop));
  }
}
