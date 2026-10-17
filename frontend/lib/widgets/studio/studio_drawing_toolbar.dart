import '../meet_admission_button.dart';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../../services/camera_broadcast_service.dart';
import 'studio_camera_control_panel.dart';

class StudioDrawingToolbar extends StatelessWidget {
  const StudioDrawingToolbar({
    super.key,
    required this.studio,
    this.isVertical = false,
  });

  final StudioState studio;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    const pine = AppColors.pine;
    const line = AppColors.line;

    if (isVertical) {
      return Container(
        margin: const EdgeInsets.only(left: 6, right: 6, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MeetAdmissionButton(),
              for (final (name, icon, label) in [
                ('pen', Icons.edit_outlined, 'Bút vẽ'),
                ('highlight', Icons.brush_outlined, 'Bút đánh dấu'),
                ('erase', Icons.auto_fix_normal, 'Tẩy nét'),
                ('laser', Icons.adjust, 'Chấm Laser (Chỉ trỏ)'),
              ])
                IconButton(
                  tooltip: label,
                  onPressed: () =>
                      studio.change(() => studio.tool = name, persist: false),
                  style: IconButton.styleFrom(
                    backgroundColor: studio.tool == name
                        ? AppColors.selected
                        : Colors.transparent,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    icon,
                    size: 18,
                    color: studio.tool == name ? AppColors.primary : pine,
                  ),
                ),
              const SizedBox(height: 6),
              Container(width: 24, height: 1, color: line),
              const SizedBox(height: 6),
              for (final (color, label) in [
                (const Color(0xfff0f3ed), 'Trắng phấn'),
                (const Color(0xffffe66d), 'Vàng phấn'),
                (const Color(0xff70e0d0), 'Xanh phấn'),
                (const Color(0xffff8c69), 'Cam phấn'),
                (const Color(0xffff85a2), 'Hồng phấn'),
              ])
                Tooltip(
                  message: label,
                  child: InkWell(
                    onTap: () =>
                        studio.change(() => studio.ink = color, persist: false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: studio.ink == color ? pine : AppColors.border,
                          width: studio.ink == color ? 2.5 : 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Tự động bắt đáp án',
                onPressed: () =>
                    studio.setSmartSnapEnabled(!studio.smartSnapEnabled),
                style: IconButton.styleFrom(
                  backgroundColor: studio.smartSnapEnabled
                      ? AppColors.selected
                      : Colors.transparent,
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(
                  Icons.bolt,
                  size: 18,
                  color: studio.smartSnapEnabled ? AppColors.primary : pine,
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 24, height: 1, color: line),
              const SizedBox(height: 6),
              IconButton(
                tooltip: 'Hoàn tác nét',
                onPressed: studio.canUndo ? studio.undo : null,
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.undo, size: 18),
              ),
              IconButton(
                tooltip: 'Xóa nét trang này',
                onPressed: studio.strokes.isEmpty ? null : studio.clearPage,
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
              const SizedBox(height: 6),
              Container(width: 24, height: 1, color: line),
              const SizedBox(height: 6),
              Builder(
                builder: (btnContext) {
                  final broadcast = CameraBroadcastService();
                  return ListenableBuilder(
                    listenable: Listenable.merge([studio, broadcast]),
                    builder: (context, _) {
                      final isBroadcasting = broadcast.isBroadcasting;
                      final isPip = studio.showCameraPip;
                      final isActive = isBroadcasting || isPip;

                      return IconButton(
                        tooltip: isBroadcasting
                            ? 'Camera & Phát ảo (Đang phát Meet)'
                            : 'Điều khiển Camera & Phát ảo',
                        onPressed: () => _openVerticalCameraMenu(btnContext),
                        style: IconButton.styleFrom(
                          backgroundColor: isBroadcasting
                              ? AppColors.successSurface
                              : (isPip
                                    ? AppColors.selected
                                    : Colors.transparent),
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isActive
                                  ? Icons.videocam
                                  : Icons.videocam_off_outlined,
                              size: 18,
                              color: isBroadcasting ? AppColors.success : pine,
                            ),
                            if (isBroadcasting)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              IconButton(
                tooltip: studio.showQuestionsDrawer
                    ? 'Đóng khay tài liệu đã nhập'
                    : 'Mở khay tài liệu đã nhập',
                onPressed: studio.toggleQuestionsDrawer,
                style: IconButton.styleFrom(
                  backgroundColor: studio.showQuestionsDrawer
                      ? AppColors.selected
                      : Colors.transparent,
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(
                  Icons.collections_bookmark_outlined,
                  size: 18,
                  color: pine,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 3,
            children: [
              const MeetAdmissionButton(),
              for (final (name, icon, label) in [
                ('pen', Icons.edit_outlined, 'Bút vẽ'),
                ('highlight', Icons.brush_outlined, 'Bút đánh dấu'),
                ('erase', Icons.auto_fix_normal, 'Tẩy nét'),
                ('laser', Icons.adjust, 'Chấm Laser (Chỉ trỏ)'),
              ])
                IconButton(
                  tooltip: label,
                  onPressed: () =>
                      studio.change(() => studio.tool = name, persist: false),
                  style: IconButton.styleFrom(
                    backgroundColor: studio.tool == name
                        ? AppColors.selected
                        : Colors.transparent,
                  ),
                  icon: Icon(
                    icon,
                    size: 19,
                    color: studio.tool == name ? AppColors.primary : pine,
                  ),
                ),
              const SizedBox(width: 8),
              for (final (color, label) in [
                (const Color(0xfff0f3ed), 'Trắng phấn'),
                (const Color(0xffffe66d), 'Vàng phấn'),
                (const Color(0xff70e0d0), 'Xanh phấn'),
                (const Color(0xffff8c69), 'Cam phấn'),
                (const Color(0xffff85a2), 'Hồng phấn'),
              ])
                Tooltip(
                  message: label,
                  child: InkWell(
                    onTap: () =>
                        studio.change(() => studio.ink = color, persist: false),
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: studio.ink == color ? pine : AppColors.border,
                          width: studio.ink == color ? 2.5 : 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Tự động bắt đáp án',
                onPressed: () =>
                    studio.setSmartSnapEnabled(!studio.smartSnapEnabled),
                style: IconButton.styleFrom(
                  backgroundColor: studio.smartSnapEnabled
                      ? AppColors.selected
                      : Colors.transparent,
                ),
                icon: Icon(
                  Icons.bolt,
                  size: 19,
                  color: studio.smartSnapEnabled ? AppColors.primary : pine,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hoàn tác nét',
                onPressed: studio.canUndo ? studio.undo : null,
                icon: const Icon(Icons.undo, size: 19),
              ),
              IconButton(
                tooltip: 'Xóa nét trang này',
                onPressed: studio.strokes.isEmpty ? null : studio.clearPage,
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
              const SizedBox(width: 6),
              Container(width: 1, height: 20, color: line),
              const SizedBox(width: 6),
              Builder(
                builder: (btnContext) {
                  final broadcast = CameraBroadcastService();
                  return ListenableBuilder(
                    listenable: Listenable.merge([studio, broadcast]),
                    builder: (context, _) {
                      final isBroadcasting = broadcast.isBroadcasting;
                      final isPip = studio.showCameraPip;
                      final isActive = isBroadcasting || isPip;

                      return IconButton(
                        tooltip: isBroadcasting
                            ? 'Camera & Phát ảo (Đang phát Meet)'
                            : 'Điều khiển Camera & Phát ảo',
                        onPressed: () => _openHorizontalCameraMenu(btnContext),
                        style: IconButton.styleFrom(
                          backgroundColor: isBroadcasting
                              ? AppColors.successSurface
                              : (isPip
                                    ? AppColors.selected
                                    : Colors.transparent),
                        ),
                        icon: Icon(
                          isActive
                              ? Icons.videocam
                              : Icons.videocam_off_outlined,
                          size: 19,
                          color: isBroadcasting ? AppColors.success : pine,
                        ),
                      );
                    },
                  );
                },
              ),
              IconButton(
                tooltip: studio.showQuestionsDrawer
                    ? 'Đóng khay tài liệu đã nhập'
                    : 'Mở khay tài liệu đã nhập',
                onPressed: studio.toggleQuestionsDrawer,
                style: IconButton.styleFrom(
                  backgroundColor: studio.showQuestionsDrawer
                      ? AppColors.selected
                      : Colors.transparent,
                ),
                icon: const Icon(
                  Icons.collections_bookmark_outlined,
                  size: 19,
                  color: pine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openVerticalCameraMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset =
        renderBox?.localToGlobal(Offset.zero) ?? const Offset(60, 200);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return Stack(
          children: [
            Positioned(
              left: offset.dx + (renderBox?.size.width ?? 40) + 8,
              top: (offset.dy - 60).clamp(16.0, screenHeight - 380),
              child: Material(
                color: Colors.transparent,
                child: StudioCameraControlPanel(
                  studio: studio,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openHorizontalCameraMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset =
        renderBox?.localToGlobal(Offset.zero) ?? const Offset(200, 500);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        final screenWidth = MediaQuery.of(ctx).size.width;
        return Stack(
          children: [
            Positioned(
              left: (offset.dx - 120).clamp(16.0, screenWidth - 340),
              top: (offset.dy - 340).clamp(16.0, screenHeight - 380),
              child: Material(
                color: Colors.transparent,
                child: StudioCameraControlPanel(
                  studio: studio,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
