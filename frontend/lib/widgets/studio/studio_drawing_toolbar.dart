import '../meet_admission_button.dart';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';

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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                  onPressed: () => studio.change(() => studio.tool = name, persist: false),
                  style: IconButton.styleFrom(
                    backgroundColor: studio.tool == name ? AppColors.sky100 : Colors.transparent,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    icon,
                    size: 18,
                    color: studio.tool == name ? AppColors.sky600 : pine,
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
                    onTap: () => studio.change(() => studio.ink = color, persist: false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: studio.ink == color ? pine : const Color(0xffd5dcd2),
                          width: studio.ink == color ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          if (studio.ink == color)
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Container(width: 24, height: 1, color: line),
              const SizedBox(height: 6),
              IconButton(
                tooltip: 'Hoàn tác nét',
                onPressed: studio.strokes.isEmpty ? null : studio.undo,
                style: IconButton.styleFrom(minimumSize: const Size(36, 36), padding: EdgeInsets.zero),
                icon: const Icon(Icons.undo, size: 18),
              ),
              IconButton(
                tooltip: 'Xóa nét trang này',
                onPressed: studio.strokes.isEmpty ? null : studio.clearPage,
                style: IconButton.styleFrom(minimumSize: const Size(36, 36), padding: EdgeInsets.zero),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
              const SizedBox(height: 6),
              Container(width: 24, height: 1, color: line),
              const SizedBox(height: 6),
              IconButton(
                tooltip: studio.showCameraPip ? 'Ẩn Webcam PIP' : 'Hiện Webcam PIP',
                onPressed: studio.toggleCameraPip,
                style: IconButton.styleFrom(
                  backgroundColor: studio.showCameraPip ? const Color(0xffedf2e5) : Colors.transparent,
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(
                  studio.showCameraPip ? Icons.videocam : Icons.videocam_off_outlined,
                  size: 18,
                  color: pine,
                ),
              ),
              IconButton(
                tooltip: studio.showQuestionsDrawer ? 'Đóng khay tài liệu đã nhập' : 'Mở khay tài liệu đã nhập',
                onPressed: studio.toggleQuestionsDrawer,
                style: IconButton.styleFrom(
                  backgroundColor: studio.showQuestionsDrawer ? const Color(0xffedf2e5) : Colors.transparent,
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
                        ? AppColors.sky100
                        : Colors.transparent,
                  ),
                  icon: Icon(
                    icon,
                    size: 19,
                    color: studio.tool == name ? AppColors.sky600 : pine,
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
                          color: studio.ink == color
                              ? pine
                              : const Color(0xffd5dcd2),
                          width: studio.ink == color ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          if (studio.ink == color)
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hoàn tác nét',
                onPressed: studio.strokes.isEmpty ? null : studio.undo,
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
              IconButton(
                tooltip: studio.showCameraPip
                    ? 'Ẩn Webcam PIP'
                    : 'Hiện Webcam PIP',
                onPressed: studio.toggleCameraPip,
                style: IconButton.styleFrom(
                  backgroundColor: studio.showCameraPip
                      ? const Color(0xffedf2e5)
                      : Colors.transparent,
                ),
                icon: Icon(
                  studio.showCameraPip
                      ? Icons.videocam
                      : Icons.videocam_off_outlined,
                  size: 19,
                  color: pine,
                ),
              ),
              IconButton(
                tooltip: studio.showQuestionsDrawer
                    ? 'Đóng khay tài liệu đã nhập'
                    : 'Mở khay tài liệu đã nhập',
                onPressed: studio.toggleQuestionsDrawer,
                style: IconButton.styleFrom(
                  backgroundColor: studio.showQuestionsDrawer
                      ? const Color(0xffedf2e5)
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
}
