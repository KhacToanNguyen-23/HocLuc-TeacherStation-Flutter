import 'package:teaching_companion/features/classroom_meet/presentation/meet_admission_button.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: studio,
    builder: (context, _) => _buildToolbar(context),
  );

  Widget _buildToolbar(BuildContext context) {
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
                ('pan', Icons.pan_tool_outlined, 'Di chuyển bảng (giữ Space)'),
                ('pen', Icons.edit_outlined, 'Bút vẽ'),
                ('highlight', Icons.brush_outlined, 'Bút đánh dấu'),
                ('erase', Icons.auto_fix_normal, 'Tẩy nét'),
                ('laser', Icons.adjust, 'Chấm Laser (Chỉ trỏ)'),
              ])
                AppPressable(
                  tooltip: label,
                  onTap: () =>
                      studio.change(() => studio.tool = name, persist: false),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, milliseconds: 140),
                    curve: AppMotion.stateCurve,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: studio.tool == name
                          ? AppColors.selected
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 18,
                      color: studio.tool == name ? AppColors.primary : pine,
                    ),
                  ),
                ),
              _strokeSettings(context),
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
                AppPressable(
                  tooltip: label,
                  onTap: () =>
                      studio.change(() => studio.ink = color, persist: false),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, milliseconds: 140),
                    curve: AppMotion.stateCurve,
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
              const SizedBox(height: 6),
              Container(width: 24, height: 1, color: line),
              const SizedBox(height: 6),
              AppPressable(
                tooltip: 'Hoàn tác nét',
                onTap: studio.canUndo ? studio.undo : null,
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.undo,
                    size: 18,
                    color: studio.canUndo ? pine : AppColors.textMuted,
                  ),
                ),
              ),
              AppPressable(
                tooltip: 'Làm lại nét',
                onTap: studio.canRedo ? studio.redo : null,
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.redo,
                    size: 19,
                    color: studio.canRedo ? pine : AppColors.textMuted,
                  ),
                ),
              ),
              AppPressable(
                tooltip: 'Xóa nét trang này',
                onTap: studio.strokes.isEmpty
                    ? null
                    : () => _confirmClear(context),
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: studio.strokes.isNotEmpty
                        ? AppColors.error
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 24, height: 1, color: line),
              const SizedBox(height: 6),
              Builder(
                builder: (btnContext) {
                  return ListenableBuilder(
                    listenable: studio,
                    builder: (context, _) {
                      final isPip = studio.showCameraPip;
                      final isActive = isPip;

                      return IconButton(
                        tooltip: 'Điều khiển Webcam',
                        onPressed: () => _openVerticalCameraMenu(btnContext),
                        style: IconButton.styleFrom(
                          backgroundColor: isPip
                              ? AppColors.selected
                              : Colors.transparent,
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
                              color: pine,
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
              IconButton(
                tooltip: studio.showSpeakerNotes
                    ? 'Đóng ghi chú nhắc bài'
                    : 'Mở ghi chú nhắc bài',
                onPressed: studio.toggleSpeakerNotes,
                style: IconButton.styleFrom(
                  backgroundColor: studio.showSpeakerNotes
                      ? AppColors.selected
                      : Colors.transparent,
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      studio.showSpeakerNotes
                          ? Icons.sticky_note_2
                          : Icons.sticky_note_2_outlined,
                      size: 18,
                      color: studio.showSpeakerNotes ? AppColors.primary : pine,
                    ),
                    if (studio.currentPageNote.trim().isNotEmpty)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
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
                ('pan', Icons.pan_tool_outlined, 'Di chuyển bảng (giữ Space)'),
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
              _strokeSettings(context),
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
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hoàn tác nét',
                onPressed: studio.canUndo ? studio.undo : null,
                icon: const Icon(Icons.undo, size: 19),
              ),
              IconButton(
                tooltip: 'Làm lại nét',
                onPressed: studio.canRedo ? studio.redo : null,
                icon: const Icon(Icons.redo, size: 19),
              ),
              IconButton(
                tooltip: 'Xóa nét trang này',
                onPressed: studio.strokes.isEmpty
                    ? null
                    : () => _confirmClear(context),
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
              const SizedBox(width: 6),
              Container(width: 1, height: 20, color: line),
              const SizedBox(width: 6),
              Builder(
                builder: (btnContext) {
                  return ListenableBuilder(
                    listenable: studio,
                    builder: (context, _) {
                      final isPip = studio.showCameraPip;
                      final isActive = isPip;

                      return IconButton(
                        tooltip: 'Điều khiển Webcam',
                        onPressed: () => _openHorizontalCameraMenu(btnContext),
                        style: IconButton.styleFrom(
                          backgroundColor: isPip
                              ? AppColors.selected
                              : Colors.transparent,
                        ),
                        icon: Icon(
                          isActive
                              ? Icons.videocam
                              : Icons.videocam_off_outlined,
                          size: 19,
                          color: pine,
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
              IconButton(
                tooltip: studio.showSpeakerNotes
                    ? 'Đóng ghi chú nhắc bài'
                    : 'Mở ghi chú nhắc bài',
                onPressed: studio.toggleSpeakerNotes,
                style: IconButton.styleFrom(
                  backgroundColor: studio.showSpeakerNotes
                      ? AppColors.selected
                      : Colors.transparent,
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      studio.showSpeakerNotes
                          ? Icons.sticky_note_2
                          : Icons.sticky_note_2_outlined,
                      size: 19,
                      color: studio.showSpeakerNotes ? AppColors.primary : pine,
                    ),
                    if (studio.currentPageNote.trim().isNotEmpty)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
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
  }

  Widget _strokeSettings(BuildContext context) {
    final supported = ['pen', 'highlight', 'erase'].contains(studio.tool);
    return IconButton(
      tooltip: 'Độ dày và xem trước nét',
      onPressed: supported
          ? () => showDialog<void>(
              context: context,
              builder: (context) => ListenableBuilder(
                listenable: studio,
                builder: (context, _) {
                  final eraser = studio.tool == 'erase';
                  final highlight = studio.tool == 'highlight';
                  final values = eraser
                      ? [0.015, 0.03, 0.05, 0.08]
                      : highlight
                      ? [8.0, 14.0, 20.0, 32.0]
                      : [1.5, 3.5, 6.0, 10.0];
                  final width = studio.currentToolSize;
                  return AlertDialog(
                    title: Text(
                      eraser
                          ? 'Kích thước tẩy'
                          : highlight
                          ? 'Bút đánh dấu'
                          : 'Bút vẽ',
                    ),
                    content: SizedBox(
                      width: 280,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xff1b2b25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: eraser
                                ? Icon(
                                    Icons.auto_fix_normal,
                                    color: Colors.white,
                                    size: 20 + width * 200,
                                  )
                                : Container(
                                    width: 180,
                                    height: width,
                                    decoration: BoxDecoration(
                                      color: studio.ink.withValues(
                                        alpha: highlight ? 0.35 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        width,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final value in values)
                                ChoiceChip(
                                  label: Text(
                                    eraser
                                        ? '${(value * 100).round()}%'
                                        : '$value px',
                                  ),
                                  selected: (width - value).abs() < 0.001,
                                  onSelected: (_) =>
                                      studio.setCurrentToolSize(value),
                                ),
                            ],
                          ),
                          Slider(
                            label: eraser
                                ? '${(width * 100).round()}%'
                                : '${width.toStringAsFixed(1)} px',
                            min: values.first,
                            max: values.last,
                            value: width.clamp(values.first, values.last),
                            onChanged: studio.setCurrentToolSize,
                          ),
                          Text(
                            eraser
                                ? 'Tẩy trọn nét trong vùng chạm'
                                : 'Độ dày: ${width.toStringAsFixed(1)} px',
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Xong'),
                      ),
                    ],
                  );
                },
              ),
            )
          : null,
      icon: const Icon(Icons.line_weight_rounded, size: 18),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nét trang này?'),
        content: const Text(
          'Xóa nét vẽ và chú thích phấn thông minh trên trang bảng hiện tại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa nét'),
          ),
        ],
      ),
    );
    if (confirmed == true) studio.clearPage();
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
