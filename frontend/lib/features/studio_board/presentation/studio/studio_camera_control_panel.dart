import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';

class StudioCameraControlPanel extends StatelessWidget {
  const StudioCameraControlPanel({
    super.key,
    required this.studio,
    this.onClose,
  });

  final StudioState studio;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final media = TeacherMediaService();

    return ListenableBuilder(
      listenable: Listenable.merge([studio, media]),
      builder: (context, _) {
        final isCameraActive = media.isCameraActive;

        return Container(
          width: 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.panel),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isCameraActive
                          ? AppColors.successSurface
                          : AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCameraActive ? Icons.videocam : Icons.videocam_outlined,
                      size: 16,
                      color: isCameraActive
                          ? AppColors.success
                          : AppColors.slate700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Điều khiển Webcam',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 17),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      onPressed: onClose,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Bật/tắt Webcam PIP trên bảng
              InkWell(
                onTap: studio.toggleCameraPip,
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: studio.showCameraPip
                        ? AppColors.successSurface
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        studio.showCameraPip
                            ? Icons.picture_in_picture_alt
                            : Icons.picture_in_picture_alt_outlined,
                        size: 16,
                        color: studio.showCameraPip
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          studio.showCameraPip
                              ? 'Webcam PIP đang hiện trên bảng'
                              : 'Ẩn Webcam PIP trên bảng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: studio.showCameraPip
                                ? AppColors.success
                                : AppColors.slate700,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: studio.showCameraPip,
                          onChanged: (_) => studio.toggleCameraPip(),
                          activeThumbColor: AppColors.success,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Chọn thiết bị Webcam (nếu có camera)
              if (media.cameras.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Thiết bị:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButton<String>(
                          value: media.selectedCamera,
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          items: media.cameras
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c.name,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) media.selectCamera(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const Text(
                'Chia sẻ màn hình bằng nút Trình bày trong cửa sổ Google Meet.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}


