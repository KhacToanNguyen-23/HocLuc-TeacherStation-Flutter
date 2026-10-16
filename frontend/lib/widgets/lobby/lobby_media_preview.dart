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

  List<String> get _cameras {
    final list = widget.mediaService.availableCameras;
    if (list.isNotEmpty) {
      if (!list.contains(widget.selectedCamera)) {
        return [widget.selectedCamera, ...list];
      }
      return list;
    }
    return _availableCameras;
  }

  List<String> get _mics {
    final list = widget.mediaService.availableMicrophones;
    if (list.isNotEmpty) {
      if (!list.contains(widget.selectedMic)) {
        return [widget.selectedMic, ...list];
      }
      return list;
    }
    return _availableMics;
  }

  @override
  Widget build(BuildContext context) {
    final mediaService = widget.mediaService;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(
                Icons.videocam_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Kiểm tra Thiết bị & Hình ảnh',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Toggle Device Settings Cog Button
              IconButton(
                icon: Icon(
                  _showDeviceSettings
                      ? Icons.tune_rounded
                      : Icons.settings_outlined,
                  size: 18,
                  color: _showDeviceSettings
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                tooltip: 'Cài đặt Camera & Micro',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => _showDeviceSettings = !_showDeviceSettings),
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
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(AppRadii.panel),
                border: Border.all(color: AppColors.slate700),
              ),
              child: Stack(
                children: [
                  // Video feed or fallback
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: mediaService,
                      builder: (context, _) => mediaService.isCameraActive
                          ? mediaService.buildCameraPreview()
                          : const ColoredBox(color: AppColors.overlaySurface),
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
                        final isTalking =
                            isMicOn && mediaService.audioLevel > 0.05;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(AppRadii.panel),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: AppMotion.duration(
                                  context,
                                  milliseconds: 80,
                                ),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isMicOn
                                      ? (isTalking
                                            ? const Color(0xFF4ADE80)
                                            : AppColors.success)
                                      : AppColors.error,
                                  boxShadow: isTalking
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF4ADE80,
                                            ).withValues(alpha: 0.8),
                                            blurRadius: 6,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isMicOn ? 'Mic đang bật' : 'Mic đã tắt',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
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
                      if (mediaService.isCameraActive) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.slate800,
                              child: const Text(
                                'GV',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: AppColors.overlayMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              mediaService.errorMessage ??
                                  (mediaService.isInitializing
                                      ? 'Đang mở webcam…'
                                      : 'Giáo viên giảng dạy'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.overlayMuted,
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
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.videocam_rounded
                                        : Icons.videocam_off_rounded,
                                    size: 22,
                                    color: isActive
                                        ? AppColors.slate800
                                        : Colors.white,
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
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.mic_rounded
                                        : Icons.mic_off_rounded,
                                    size: 22,
                                    color: isActive
                                        ? AppColors.slate800
                                        : Colors.white,
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
          // Real-time Audio Level Meter Bar
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: mediaService,
            builder: (context, _) {
              final level = mediaService.audioLevel;
              final isMicOn = mediaService.isMicActive;
              return Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: isMicOn ? level.clamp(0.01, 1.0) : 0.0,
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, milliseconds: 60),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: level > 0.8
                            ? [
                                AppColors.success,
                                AppColors.warning,
                                AppColors.error,
                              ]
                            : [AppColors.success, AppColors.success],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            },
          ),
          // Collapsible Device Settings Drawer
          if (_showDeviceSettings) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _cameras.contains(widget.selectedCamera)
                        ? widget.selectedCamera
                        : _cameras.first,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thiết bị Camera',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    items: _cameras
                        .map(
                          (cam) => DropdownMenuItem(
                            value: cam,
                            child: Text(
                              cam,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        widget.mediaService.switchCamera(val);
                        widget.onCameraChanged(val);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _mics.contains(widget.selectedMic)
                        ? widget.selectedMic
                        : _mics.first,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thiết bị Micro',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    items: _mics
                        .map(
                          (mic) => DropdownMenuItem(
                            value: mic,
                            child: Text(
                              mic,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        widget.mediaService.switchMicrophone(val);
                        widget.onMicChanged(val);
                      }
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
