import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../../services/meet_automation_service.dart';
import '../../services/url_opener.dart';
import '../create_classroom_dialog.dart';

enum StudioSettingsSection { room, media, display, shortcuts }

class StudioTopBar extends StatelessWidget {
  const StudioTopBar({
    super.key,
    required this.studio,
    required this.width,
    required this.hasLessons,
    required this.onToggleLessons,
    required this.onOpenSettings,
    required this.onRename,
    required this.onPreview,
    required this.onSave,
    required this.onRetryConnect,
    this.onToggleStudents,
    this.hasStudents = false,
    this.onLeaveClassroom,
    this.isPlanningMode = false,
    this.onExitPlanning,
    this.onCreateClassroomFromPlanning,
  });

  final StudioState studio;
  final double width;
  final bool hasLessons, hasStudents;
  final bool isPlanningMode;
  final VoidCallback? onExitPlanning, onCreateClassroomFromPlanning;
  final VoidCallback onToggleLessons,
      onRename,
      onPreview,
      onSave,
      onRetryConnect;
  final ValueChanged<StudioSettingsSection> onOpenSettings;
  final VoidCallback? onToggleStudents, onLeaveClassroom;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: width < 1000
          ? Column(
              children: [
                SizedBox(height: 44, child: _identity(context)),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _actions(),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _identity(context)),
                const SizedBox(width: 12),
                _actions(),
              ],
            ),
    ),
  );

  Widget _identity(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.sky600,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Center(
          child: Text(
            'm',
            style: TextStyle(
              fontFamily: 'Literata',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      _icon(
        tooltip: hasLessons ? 'Đóng quản lý bảng' : 'Quản lý các bảng',
        icon: Icons.view_sidebar_outlined,
        onPressed: onToggleLessons,
        selected: hasLessons,
      ),
      Expanded(
        child: InkWell(
          onTap: onRename,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    studio.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
      if (isPlanningMode && width >= 1000)
        const Text('Kế hoạch bài giảng', style: TextStyle(fontSize: 11)),
      if (!studio.online)
        Tooltip(
          message: studio.error ?? 'Chưa kết nối. Bấm để thử lại.',
          child: TextButton(
            onPressed: studio.loading ? null : onRetryConnect,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xffe65100),
              backgroundColor: const Color(0xfffff7ed),
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xfffed7aa)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 15),
                if (width >= 1440) ...[
                  const SizedBox(width: 6),
                  const Text(
                    'Chưa kết nối · Thử lại',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        )
      else if (studio.dirty)
        const Tooltip(
          message: 'Có thay đổi chưa lưu',
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.circle, size: 8, color: Color(0xffea580c)),
          ),
        ),
      const SizedBox(width: 6),
      ListenableBuilder(
        listenable: MeetAutomationService(),
        builder: (context, _) {
          if (isPlanningMode) return const SizedBox.shrink();
          final url = MeetAutomationService().meetingUrl;
          if (url == null) {
            return Tooltip(
              message: 'Tạo lớp học',
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const CreateClassroomDialog(),
                ),
                child: width >= 1440
                    ? const Text('Tạo lớp học', style: TextStyle(fontSize: 12))
                    : const Icon(Icons.add_link_rounded, size: 20),
              ),
            );
          }
          return Container(
            padding: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.blue100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (width >= 1440) ...[
                  const Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: AppColors.blue600,
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: width >= 1440 ? 150 : 90,
                    child: Text(
                      url.replaceFirst(RegExp(r'^https?://'), ''),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.blue700,
                      ),
                    ),
                  ),
                  _icon(
                    tooltip: 'Sao chép link Meet gửi học sinh',
                    icon: Icons.copy_rounded,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã sao chép link lớp học Google Meet!',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
                _icon(
                  tooltip: 'Mở Google Meet trên tab mới',
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => openExternalUrl(url),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );

  Widget _actions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (isPlanningMode) ...[
        _tab('Thoát', 'Thoát soạn bài', false, onExitPlanning ?? () {}),
        _tab(
          'Tạo phòng học',
          'Tạo phòng học',
          false,
          onCreateClassroomFromPlanning ?? () {},
        ),
        _tab('Lưu bài soạn', 'Lưu bài soạn', false, onSave),
      ],
      _tab(
        'Bảng',
        'Bảng giảng',
        studio.view == 'board' && !studio.showQuestionsDrawer,
        () {
          studio.setQuestionsDrawer(false);
          studio.setView('board');
        },
      ),
      _tab('Tài liệu', 'Tài liệu', studio.showQuestionsDrawer, () {
        studio.setView('board');
        studio.toggleQuestionsDrawer();
      }),
      _tab('Câu hỏi', 'Câu hỏi', studio.view == 'question', () {
        studio.setQuestionsDrawer(false);
        studio.setView(studio.view == 'question' ? 'board' : 'question');
      }),
      const SizedBox(width: 4),
      _icon(
        tooltip: 'Xem khung trình bày',
        icon: Icons.preview_outlined,
        onPressed: onPreview,
      ),
      if (onToggleStudents != null)
        _icon(
          tooltip: 'Danh sách học sinh',
          icon: Icons.groups_outlined,
          onPressed: onToggleStudents,
          selected: hasStudents,
        ),
      if (!isPlanningMode)
        _icon(
          tooltip: studio.saving
              ? 'Đang lưu…'
              : (isPlanningMode ? 'Lưu bài soạn' : 'Lưu bài giảng'),
          icon: studio.saving
              ? Icons.hourglass_top_rounded
              : Icons.save_outlined,
          onPressed: studio.saving || studio.loading ? null : onSave,
        ),
      PopupMenuButton<StudioSettingsSection>(
        tooltip: 'Cài đặt khác',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        elevation: 4,
        onSelected: onOpenSettings,
        itemBuilder: (_) => [
          const PopupMenuItem<StudioSettingsSection>(
            enabled: false,
            child: Text(
              'Cài đặt',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.pine,
              ),
            ),
          ),
          const PopupMenuDivider(),
          for (final (value, label, icon) in [
            (
              StudioSettingsSection.room,
              'Cài đặt phòng học',
              Icons.settings_outlined,
            ),
            (
              StudioSettingsSection.media,
              'Âm thanh & video',
              Icons.videocam_outlined,
            ),
            (
              StudioSettingsSection.display,
              'Cài đặt hiển thị',
              Icons.desktop_windows_outlined,
            ),
            (
              StudioSettingsSection.shortcuts,
              'Phím tắt',
              Icons.keyboard_outlined,
            ),
          ])
            PopupMenuItem(
              value: value,
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.pine),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 13)),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
        ],
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.more_vert, size: 22, color: AppColors.pine),
        ),
      ),
      if (!isPlanningMode && onLeaveClassroom != null) ...[
        Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: AppColors.line,
        ),
        IconButton(
          tooltip: 'Rời phòng',
          onPressed: onLeaveClassroom,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xffdc2626),
            foregroundColor: Colors.white,
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 24),
        ),
      ],
    ],
  );

  Widget _tab(
    String label,
    String tooltip,
    bool active,
    VoidCallback onPressed,
  ) => Tooltip(
    message: tooltip,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: active ? AppColors.sky600 : AppColors.pine,
        backgroundColor: active ? AppColors.sky100 : Colors.transparent,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _icon({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    bool selected = false,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      backgroundColor: selected ? AppColors.sky100 : Colors.transparent,
      foregroundColor: selected ? AppColors.sky600 : AppColors.pine,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    icon: Icon(icon, size: 20),
  );
}
