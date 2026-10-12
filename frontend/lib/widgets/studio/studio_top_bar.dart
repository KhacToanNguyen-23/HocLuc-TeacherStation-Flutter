import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../../services/meet_automation_service.dart';
import '../../services/url_opener.dart';
import '../create_classroom_dialog.dart';

class StudioTopBar extends StatelessWidget {
  const StudioTopBar({
    super.key,
    required this.studio,
    required this.width,
    required this.hasLessons,
    required this.hasInspector,
    required this.onToggleLessons,
    required this.onToggleInspector,
    required this.onRename,
    required this.onPreview,
    required this.onSave,
    required this.onRetryConnect,
    this.onToggleStudents,
    this.onTogglePlugins,
    this.hasStudents = false,
    this.hasPlugins = false,
    this.onLeaveClassroom,
  });

  final StudioState studio;
  final double width;
  final bool hasLessons;
  final bool hasInspector;
  final bool hasStudents;
  final bool hasPlugins;
  final VoidCallback onToggleLessons;
  final VoidCallback onToggleInspector;
  final VoidCallback onRename;
  final VoidCallback onPreview;
  final VoidCallback onSave;
  final VoidCallback onRetryConnect;
  final VoidCallback? onToggleStudents;
  final VoidCallback? onTogglePlugins;
  final VoidCallback? onLeaveClassroom;

  @override
  Widget build(BuildContext context) {
    const pine = AppColors.pine;
    const muted = AppColors.muted;
    const line = AppColors.line;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.sky600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'm',
                style: TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: hasLessons ? 'Đóng mục bài giảng' : 'Mở mục bài giảng',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: onToggleLessons,
            icon: Icon(
              hasLessons ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              color: pine,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: InkWell(
              onTap: onRename,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        studio.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: pine,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_outlined, size: 13, color: muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (!studio.online)
            Tooltip(
              message: studio.error ?? 'Chưa kết nối Java. Bấm để thử lại.',
              child: InkWell(
                onTap: studio.loading ? null : onRetryConnect,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffffeed9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xffffcc80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 11, color: Color(0xffe65100)),
                      SizedBox(width: 4),
                      Text(
                        'Thử lại',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xffe65100),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (studio.dirty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xfffff7ed),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xfffed7aa)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: Color(0xffea580c)),
                  SizedBox(width: 4),
                  Text(
                    'Chưa lưu',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xffc2410c),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: MeetAutomationService(),
            builder: (context, _) {
              final meetService = MeetAutomationService();
              final url = meetService.meetingUrl;
              if (url != null) {
                return Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xffeff6ff),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xffbfdbfe)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_rounded, size: 15, color: Color(0xFF2563EB)),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width > 1150 ? 150 : 90),
                        child: Text(
                          url.replaceFirst(RegExp(r'^https?:\/\/'), ''),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Sao chép link Meet gửi học sinh',
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép link lớp học Google Meet!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Tooltip(
                        message: 'Mở Google Meet trên tab mới',
                        child: InkWell(
                          onTap: () => openExternalUrl(url),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ElevatedButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const CreateClassroomDialog(),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Tạo lớp học'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Bảng giảng',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => studio.setView('board'),
            style: IconButton.styleFrom(
              backgroundColor: studio.view == 'board'
                  ? const Color(0xffedf2e5)
                  : Colors.transparent,
            ),
            icon: Icon(
              Icons.dashboard_outlined,
              color: studio.view == 'board' ? pine : muted,
            ),
          ),
          const SizedBox(width: 3),
          IconButton(
            tooltip: 'Câu hỏi',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () =>
                studio.setView(studio.view == 'question' ? 'board' : 'question'),
            style: IconButton.styleFrom(
              backgroundColor: studio.view == 'question'
                  ? const Color(0xffedf2e5)
                  : Colors.transparent,
            ),
            icon: Icon(
              Icons.quiz_outlined,
              color: studio.view == 'question' ? pine : muted,
            ),
          ),
          const SizedBox(width: 3),
          IconButton(
            tooltip: 'Xem khung trình bày',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onPreview,
            icon: const Icon(Icons.slideshow_outlined, color: pine),
          ),
          const SizedBox(width: 3),
          IconButton(
            tooltip: 'Thiết bị và API AI',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onToggleInspector,
            icon: Icon(
              hasInspector ? Icons.tune : Icons.tune_outlined,
              color: hasInspector ? pine : muted,
            ),
          ),
          IconButton(
            tooltip: studio.saving ? 'Đang lưu…' : 'Lưu bài giảng',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: studio.saving || studio.loading ? null : onSave,
            icon: Icon(
              studio.saving ? Icons.hourglass_top_rounded : Icons.save_outlined,
              color: pine,
            ),
          ),
          if (width > 800 && onToggleStudents != null) ...[
            const SizedBox(width: 3),
            IconButton(
              tooltip: 'Danh sách học sinh',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onToggleStudents,
              style: IconButton.styleFrom(
                backgroundColor: hasStudents ? const Color(0xffedf2e5) : Colors.transparent,
              ),
              icon: Icon(hasStudents ? Icons.groups : Icons.groups_outlined, color: pine),
            ),
          ],
          if (width > 800 && onTogglePlugins != null) ...[
            const SizedBox(width: 3),
            IconButton(
              tooltip: 'Hoạt động & Tiện ích môn',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onTogglePlugins,
              style: IconButton.styleFrom(
                backgroundColor: hasPlugins ? const Color(0xffedf2e5) : Colors.transparent,
              ),
              icon: Icon(hasPlugins ? Icons.extension : Icons.extension_outlined, color: pine),
            ),
          ],
          if (onLeaveClassroom != null) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onLeaveClassroom,
              icon: const Icon(Icons.call_end_rounded, size: 14, color: Colors.white),
              label: Text(
                width > 900 ? 'Rời phòng' : '',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: width > 900 ? 10 : 8,
                  vertical: 7,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
