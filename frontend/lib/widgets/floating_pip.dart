import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import '../services/meet_automation_service.dart';
import '../services/teacher_media_service.dart';

class FloatingPip extends StatefulWidget {
  const FloatingPip({super.key, required this.studio});

  final StudioState studio;

  @override
  State<FloatingPip> createState() => _FloatingPipState();
}

class _FloatingPipState extends State<FloatingPip> {
  final mediaService = TeacherMediaService();
  final meetService = MeetAutomationService();

  @override
  void initState() {
    super.initState();
    // Khởi tạo luồng webcam và micro khi widget được render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mediaService.initMedia();
    });
  }

  void _handleDrag(DragUpdateDetails details, BuildContext context) {
    final studio = widget.studio;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(1920, 1080);
    const margin = 16.0;
    const pipW = 250.0;
    const pipH = 155.0;

    final newRight = (studio.pipPosition.dx - details.delta.dx).clamp(
      margin,
      size.width - pipW - margin,
    );
    final newTop = (studio.pipPosition.dy + details.delta.dy).clamp(
      margin,
      size.height - pipH - margin,
    );

    studio.setPipPosition(Offset(newRight, newTop));
  }

  @override
  Widget build(BuildContext context) {
    final studio = widget.studio;

    return ListenableBuilder(
      listenable: Listenable.merge([studio, meetService, mediaService]),
      builder: (context, _) {
        if (!studio.showCameraPip) {
          return const SizedBox.shrink();
        }

        final isLive = meetService.isBroadcasting;
        final isCamOn = mediaService.isCameraActive;
        final isMicOn = mediaService.isMicActive;
        final audioLevel = mediaService.audioLevel;

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
                  border: Border.all(
                    color: isLive ? Colors.redAccent : const Color(0x33ffffff),
                  ),
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
                    Icon(
                      isCamOn ? Icons.videocam : Icons.videocam_off,
                      size: 15,
                      color: isCamOn ? const Color(0xffd4e8a6) : Colors.redAccent,
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      isMicOn ? Icons.mic : Icons.mic_off,
                      size: 15,
                      color: isMicOn ? const Color(0xff4ade80) : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLive ? 'LIVE' : 'Webcam GV',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isLive ? Colors.redAccent : const Color(0xffe8eae6),
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
              width: 250,
              height: 155,
              decoration: BoxDecoration(
                color: const Color(0xf20e1814),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isLive ? Colors.redAccent : const Color(0x44d4e8a6),
                  width: isLive ? 2.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isLive
                        ? Colors.redAccent.withValues(alpha: 0.3)
                        : const Color(0x66000000),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Camera Feed / Real Webcam Stream
                  Positioned.fill(
                    child: mediaService.buildCameraPreview(),
                  ),

                  // Top Bar Controls
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      color: const Color(0x88000000),
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
                          const SizedBox(width: 6),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xff4ade80),
                                shape: BoxShape.circle,
                              ),
                            ),
                          const Spacer(),
                          // Toggle Mic ON/OFF button
                          Tooltip(
                            message: isMicOn ? 'Tắt Micro' : 'Bật Micro',
                            child: InkWell(
                              onTap: mediaService.toggleMic,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Icon(
                                  isMicOn ? Icons.mic : Icons.mic_off,
                                  size: 15,
                                  color: isMicOn
                                      ? const Color(0xff4ade80)
                                      : Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Toggle Cam ON/OFF button
                          Tooltip(
                            message: isCamOn ? 'Tắt Camera' : 'Bật Camera',
                            child: InkWell(
                              onTap: mediaService.toggleCamera,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Icon(
                                  isCamOn
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  size: 15,
                                  color: isCamOn
                                      ? const Color(0xffd4e8a6)
                                      : Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
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

                  // Bottom Action Controls: Mic Visualizer & Bắt đầu dạy
                  Positioned(
                    bottom: 6,
                    left: 8,
                    right: 8,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
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
                          const SizedBox(width: 4),
                          // Audio Level Visualizer & Mic status
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xaa000000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMicOn ? Icons.mic : Icons.mic_off,
                                  size: 11,
                                  color: isMicOn
                                      ? const Color(0xff4ade80)
                                      : Colors.redAccent,
                                ),
                                const SizedBox(width: 4),
                                if (isMicOn) ...[
                                  const Text(
                                    'Mic ON',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff4ade80),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  _buildAudioWave(audioLevel),
                                ] else ...[
                                  const Text(
                                    'Đã tắt mic',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        if (!isLive)
                          ElevatedButton.icon(
                            onPressed: () => meetService.startBroadcast(),
                            icon: const Icon(Icons.play_arrow_rounded, size: 13),
                            label: const Text('Bắt đầu dạy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => meetService.stopBroadcast(),
                            icon: const Icon(Icons.pause_rounded, size: 13),
                            label: const Text('Tạm dừng'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildAudioWave(double level) {
    // 3 cột sóng âm phản ứng theo âm lượng mic
    final h1 = (4 + level * 8).clamp(3.0, 10.0);
    final h2 = (4 + level * 12).clamp(4.0, 12.0);
    final h3 = (4 + level * 7).clamp(3.0, 9.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildBar(h1),
        const SizedBox(width: 2),
        _buildBar(h2),
        const SizedBox(width: 2),
        _buildBar(h3),
      ],
    );
  }

  Widget _buildBar(double height) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xff4ade80),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
