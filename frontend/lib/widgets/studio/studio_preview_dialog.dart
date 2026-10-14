import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../stage_container.dart';
import 'studio_question_view.dart';
import '../../services/camera_broadcast_service.dart';

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
                  child: ListenableBuilder(
                    listenable: CameraBroadcastService(),
                    builder: (_, _) => Text(
                      CameraBroadcastService().isBroadcasting
                          ? 'Camera ảo · khung hình đang gửi đến Unity Video Capture'
                          : 'Khung trình bày · camera ảo chưa phát',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
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
                animation: Listenable.merge([studio, CameraBroadcastService()]),
                builder: (_, _) {
                  final frame = CameraBroadcastService().preview;
                  if (frame != null) {
                    if (CameraBroadcastService().captureArea ==
                        CameraCaptureArea.app) {
                      return const _AppFrameSnapshot();
                    }
                    return RawImage(image: frame, fit: BoxFit.contain);
                  }
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

// A live app preview would capture itself recursively. Keep a snapshot instead.
class _AppFrameSnapshot extends StatefulWidget {
  const _AppFrameSnapshot();
  @override
  State<_AppFrameSnapshot> createState() => _AppFrameSnapshotState();
}

class _AppFrameSnapshotState extends State<_AppFrameSnapshot> {
  ui.Image? _image;
  @override
  void initState() {
    super.initState();
    _image = CameraBroadcastService().preview?.clone();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text(
        'Toàn bộ ứng dụng · ảnh chụp lúc mở xem trước',
        style: TextStyle(color: Colors.white70),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: RawImage(image: _image, fit: BoxFit.contain),
      ),
    ],
  );
}
