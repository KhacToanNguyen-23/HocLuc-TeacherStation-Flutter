import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import '../services/camera_broadcast_service.dart';
import '../services/teacher_media_service.dart';
import 'presentation_surface.dart';

/// Interactive controls sit above the clean webcam in PresentationSurface.
class FloatingPip extends StatelessWidget {
  const FloatingPip({super.key, required this.studio});
  final StudioState studio;
  @override
  Widget build(BuildContext context) {
    final media = TeacherMediaService();
    final broadcast = CameraBroadcastService();
    return ListenableBuilder(
      listenable: Listenable.merge([studio, media, broadcast]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final rect = cameraRect(size, studio);
          return Stack(
            children: [
              if (studio.showCameraPip)
                Positioned.fromRect(
                  rect: rect,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) => studio.setPipPosition(
                      studio.pipPosition +
                          Offset(
                            details.delta.dx /
                                math.max(1, size.width - rect.width),
                            details.delta.dy /
                                math.max(1, size.height - rect.height),
                          ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ColoredBox(
                            color: const Color(0x88000000),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.drag_indicator,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const Expanded(
                                  child: Text(
                                    'Webcam',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: media.isCameraActive
                                      ? 'Tắt camera'
                                      : 'Bật camera',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: media.isInitializing
                                      ? null
                                      : media.toggleCamera,
                                  icon: Icon(
                                    media.isCameraActive
                                        ? Icons.videocam
                                        : Icons.videocam_off,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Ẩn webcam',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    studio.toggleCameraPip();
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onPanUpdate: (details) => studio.setPipWidth(
                              studio.pipWidthFraction +
                                  details.delta.dx / size.width,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.open_in_full,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
