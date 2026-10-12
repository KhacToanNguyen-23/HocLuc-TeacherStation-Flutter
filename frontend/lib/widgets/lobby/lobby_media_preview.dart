import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/teacher_media_service.dart';

/// Left panel in Classroom Lobby for Hardware, Camera, Mic testing and Virtual Backgrounds.
class LobbyMediaPreview extends StatefulWidget {
  const LobbyMediaPreview({
    super.key,
    required this.mediaService,
    required this.selectedBackground,
    required this.selectedCamera,
    required this.selectedMic,
    required this.simulatedDb,
    required this.onBackgroundSelected,
    required this.onCameraChanged,
    required this.onMicChanged,
  });

  final TeacherMediaService mediaService;
  final String selectedBackground;
  final String selectedCamera;
  final String selectedMic;
  final double simulatedDb;
  final ValueChanged<String> onBackgroundSelected;
  final ValueChanged<String> onCameraChanged;
  final ValueChanged<String> onMicChanged;

  @override
  State<LobbyMediaPreview> createState() => _LobbyMediaPreviewState();
}

class _LobbyMediaPreviewState extends State<LobbyMediaPreview> {
  bool _showDeviceSettings = false;

  static const _availableCameras = [
    'Webcam HD (Tích hợp trên máy)',
    'OBS Virtual Camera',
    'USB 2.0 HD Camera (Rời ngoài)',
  ];

  static const _availableMics = [
    'Microphone (Realtek High Definition Audio)',
    'Headset Microphone (Tai nghe dạy học)',
    'Virtual Audio Cable',
  ];

  @override
  Widget build(BuildContext context) {
    final mediaService = widget.mediaService;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(Icons.videocam_rounded, size: 20, color: AppColors.sky600),
              const SizedBox(width: 8),
              const Text(
                'Kiểm tra Thiết bị & Hình ảnh',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
              const Spacer(),
              // Toggle Device Settings Cog Button
              IconButton(
                icon: Icon(
                  _showDeviceSettings ? Icons.tune_rounded : Icons.settings_outlined,
                  size: 18,
                  color: _showDeviceSettings ? AppColors.sky600 : AppColors.slate600,
                ),
                tooltip: 'Cài đặt Camera & Micro',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _showDeviceSettings = !_showDeviceSettings),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Camera Preview Frame (Google Meet Stage)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Video feed or fallback
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: mediaService,
                      builder: (context, _) => mediaService.buildCameraPreview(),
                    ),
                  ),

                  // Mic volume pulse dot (Top Right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: ListenableBuilder(
                      listenable: mediaService,
                      builder: (context, _) {
                        final isMicOn = mediaService.isMicActive;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isMicOn ? AppColors.emerald500 : AppColors.rose500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isMicOn ? 'Mic đang bật' : 'Mic đã tắt',
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Center Avatar when Camera is OFF
                  ListenableBuilder(
                    listenable: mediaService,
                    builder: (context, _) {
                      if (mediaService.isCameraActive) return const SizedBox.shrink();
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: const Color(0xFF1E293B),
                              child: const Text(
                                'GV',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Giáo viên giảng dạy',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Floating Round Action Buttons (Google Meet Style) at bottom center
                  Positioned(
                    bottom: 14,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Round Camera Button
                        ListenableBuilder(
                          listenable: mediaService,
                          builder: (context, _) {
                            final isActive = mediaService.isCameraActive;
                            return Tooltip(
                              message: isActive ? 'Tắt Camera' : 'Bật Camera',
                              child: InkWell(
                                onTap: mediaService.toggleCamera,
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.white : AppColors.rose600,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isActive ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                                    size: 22,
                                    color: isActive ? const Color(0xFF1E293B) : Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 14),

                        // Round Mic Button
                        ListenableBuilder(
                          listenable: mediaService,
                          builder: (context, _) {
                            final isActive = mediaService.isMicActive;
                            return Tooltip(
                              message: isActive ? 'Tắt Micro' : 'Bật Micro',
                              child: InkWell(
                                onTap: mediaService.toggleMic,
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.white : AppColors.rose600,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isActive ? Icons.mic_rounded : Icons.mic_off_rounded,
                                    size: 22,
                                    color: isActive ? const Color(0xFF1E293B) : Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Collapsible Device Settings Drawer
          if (_showDeviceSettings) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: widget.selectedCamera,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thiết bị Camera',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: _availableCameras.map((cam) => DropdownMenuItem(value: cam, child: Text(cam, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) {
                      if (val != null) widget.onCameraChanged(val);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: widget.selectedMic,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thiết bị Micro',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: _availableMics.map((mic) => DropdownMenuItem(value: mic, child: Text(mic, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) {
                      if (val != null) widget.onMicChanged(val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
