import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import '../services/camera_broadcast_service.dart';
import '../services/teacher_media_service.dart';
import 'presentation_surface.dart';

/// Interactive controls sit above the clean webcam in PresentationSurface.
class FloatingPip extends StatelessWidget {
  const FloatingPip({super.key, required this.studio,
    this.showDeviceControls = true, this.controlsOnly = false});
  final StudioState studio;
  final bool showDeviceControls, controlsOnly;
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
              if (!controlsOnly && studio.showCameraPip)
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
              if (showDeviceControls || controlsOnly) Positioned(
                top: controlsOnly ? 0 : null,
                bottom: controlsOnly ? 0 : 12,
                left: controlsOnly ? 0 : 12,
                right: controlsOnly ? 0 : 160,
                child: Align(
                  alignment: controlsOnly ? Alignment.topLeft : Alignment.bottomLeft,
                  child: SingleChildScrollView(child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xee14221d),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilledButton.icon(
                          onPressed: broadcast.isStarting
                              ? null
                              : () async {
                                  if (broadcast.isBroadcasting) {
                                    await broadcast.stop();
                                  } else {
                                    await broadcast.start();
                                  }
                                  if (context.mounted &&
                                      broadcast.errorMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(broadcast.errorMessage!),
                                      ),
                                    );
                                  }
                                },
                          icon: Icon(
                            broadcast.isBroadcasting
                                ? Icons.stop
                                : Icons.play_arrow,
                            size: 16,
                          ),
                          label: Text(
                            broadcast.isStarting
                                ? 'Đang mở…'
                                : broadcast.isBroadcasting
                                ? 'Dừng camera ảo'
                                : 'Phát camera ảo',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hiện / ẩn webcam',
                          onPressed: () {
                            studio.toggleCameraPip();
                          },
                          icon: Icon(
                            studio.showCameraPip
                                ? Icons.videocam
                                : Icons.videocam_off,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (media.cameras.isNotEmpty)
                          PopupMenuButton<String>(
                            tooltip: 'Chọn webcam',
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 20,
                            ),
                            onSelected: media.selectCamera,
                            itemBuilder: (_) => media.cameras
                                .map(
                                  (camera) => PopupMenuItem(
                                    value: camera.name,
                                    child: Text(
                                      '${camera.name == media.selectedCamera ? '✓ ' : ''}${camera.name}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        Text(
                          broadcast.isBroadcasting
                              ? '720p · ${broadcast.fps.toStringAsFixed(0)} fps · ${broadcast.receiverConnected ? 'Đã kết nối' : 'Chọn Unity Video Capture trong Meet'}'
                              : 'Unity Video Capture',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        if (broadcast.errorMessage != null)
                          Text(
                            broadcast.errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    ),
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
