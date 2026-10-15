import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../../services/camera_broadcast_service.dart';
import '../../services/teacher_media_service.dart';

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
    final broadcast = CameraBroadcastService();

    return ListenableBuilder(
      listenable: Listenable.merge([studio, media, broadcast]),
      builder: (context, _) {
        final isBroadcasting = broadcast.isBroadcasting;

        return Container(
          width: 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
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
                      color: isBroadcasting
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBroadcasting ? Icons.videocam : Icons.videocam_outlined,
                      size: 16,
                      color: isBroadcasting
                          ? const Color(0xFF16A34A)
                          : AppColors.slate700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Điều khiển Camera & Phát',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
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

              // Button Phát / Dừng camera ảo
              FilledButton.icon(
                onPressed: broadcast.isStarting
                    ? null
                    : () async {
                        if (broadcast.isBroadcasting) {
                          await broadcast.stop();
                        } else {
                          await broadcast.start();
                        }
                        if (context.mounted && broadcast.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(broadcast.errorMessage!)),
                          );
                        }
                      },
                icon: Icon(
                  isBroadcasting
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(
                  broadcast.isStarting
                      ? 'Đang mở…'
                      : isBroadcasting
                      ? 'Dừng camera ảo'
                      : 'Phát camera ảo (Meet)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isBroadcasting
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Vùng truyền phát (Capture Area)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.crop_free,
                      size: 16,
                      color: AppColors.slate600,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Vùng phát:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<CameraCaptureArea>(
                      value: broadcast.captureArea,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: CameraCaptureArea.board,
                          child: Text('Chỉ bảng'),
                        ),
                        DropdownMenuItem(
                          value: CameraCaptureArea.app,
                          child: Text('Toàn bộ app'),
                        ),
                      ],
                      onChanged: (area) {
                        if (area != null) broadcast.setCaptureArea(area);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Bật/tắt Webcam PIP trên bảng
              InkWell(
                onTap: studio.toggleCameraPip,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: studio.showCameraPip
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: studio.showCameraPip
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        studio.showCameraPip
                            ? Icons.picture_in_picture_alt
                            : Icons.picture_in_picture_alt_outlined,
                        size: 16,
                        color: studio.showCameraPip
                            ? const Color(0xFF16A34A)
                            : AppColors.slate600,
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
                                ? const Color(0xFF15803D)
                                : AppColors.slate700,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: studio.showCameraPip,
                          onChanged: (_) => studio.toggleCameraPip(),
                          activeThumbColor: const Color(0xFF16A34A),
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
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam_outlined,
                        size: 16,
                        color: AppColors.slate600,
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
                            color: AppColors.slate900,
                          ),
                          items: media.cameras
                              .map(
                                (c) => DropdownMenuItem(
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

              // Trạng thái kỹ thuật & Thông tin kết nối
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isBroadcasting
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBroadcasting
                      ? '720p · ${broadcast.fps.toStringAsFixed(0)} fps · ${broadcast.receiverConnected ? 'Đã kết nối Meet' : 'Chưa kết nối Meet (Chọn Unity Video Capture)'}'
                      : 'Unity Video Capture · Sẵn sàng phát',
                  style: TextStyle(
                    fontSize: 11,
                    color: isBroadcasting
                        ? const Color(0xFF15803D)
                        : AppColors.slate600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (broadcast.errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  broadcast.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
