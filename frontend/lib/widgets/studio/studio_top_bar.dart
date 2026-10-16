import '../meet_admission_button.dart';
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
    this.hasLessons = false,
    this.hasInspector = false,
    this.onToggleLessons,
    required this.onToggleInspector,
    required this.onRename,
    this.onPreview,
    required this.onSave,
    required this.onRetryConnect,
    this.onToggleStudents,
    this.onTogglePlugins,
    this.hasStudents = false,
    this.hasPlugins = false,
    this.onLeaveClassroom,
    bool isPlanningMode = false,
    bool? isPlanning,
    this.onExitPlanning,
    this.onCreateClassroomFromPlanning,
  }) : isPlanningMode = isPlanning ?? isPlanningMode;

  final StudioState studio;
  final double width;
  final bool hasLessons;
  final bool hasInspector;
  final bool hasStudents;
  final bool hasPlugins;
  final bool isPlanningMode;
  bool get isPlanning => isPlanningMode;
  final VoidCallback? onToggleLessons;
  final VoidCallback onToggleInspector;
  final VoidCallback onRename;
  final VoidCallback? onPreview;
  final VoidCallback onSave;
  final VoidCallback onRetryConnect;
  final VoidCallback? onToggleStudents;
  final VoidCallback? onTogglePlugins;
  final VoidCallback? onLeaveClassroom;
  final VoidCallback? onExitPlanning;
  final VoidCallback? onCreateClassroomFromPlanning;

  Widget _buildSaveStatusBadge() {
    if (!studio.online) {
      return Tooltip(
        message: studio.error ?? 'Chưa kết nối Java. Bấm để thử lại.',
        child: InkWell(
          onTap: studio.loading ? null : onRetryConnect,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
      );
    }

    if (studio.saving) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 7,
              height: 7,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            SizedBox(width: 4),
            Text(
              'Đang lưu...',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      );
    }

    if (studio.savedAt.isNotEmpty && !studio.dirty) {
      return Tooltip(
        message: 'Tất cả thay đổi đã được lưu an toàn',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 11,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 4),
              Text(
                'Đã lưu ${studio.savedAt}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Hiển thị 'Chưa lưu' khi có thay đổi hoặc khi mới tạo chưa lưu
    return Tooltip(
      message: 'Có thay đổi chưa lưu. Bấm để lưu (Ctrl+S)',
      child: InkWell(
        onTap: onSave,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (width < 760) {
      return SizedBox(
        height: 54,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildBar(context, 760),
        ),
      );
    }
    return _buildBar(context, width);
  }

  Widget _buildBar(BuildContext context, double layoutWidth) {
    const pine = AppColors.pine;
    const muted = AppColors.muted;
    const line = AppColors.line;

    return Container(
      width: layoutWidth,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ==================== CỤM BÊN TRÁI (GIÓNG SÁT LỀ TRÁI) ====================
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Logo
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
                const SizedBox(width: 8),

                // 2. Tiêu đề bài giảng (Tự co giãn nếu chật, tối đa 240px)
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 90,
                      maxWidth: 240,
                    ),
                    child: InkWell(
                      onTap: onRename,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text.rich(
                          TextSpan(
                            text: studio.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: pine,
                            ),
                            children: const [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 3),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Trạng thái lưu (Có không gian cố định 108px riêng, không xê dịch các thẻ bên cạnh khi đổi trạng thái)
                if (width >= 1100) ...[
                  SizedBox(
                    width: 108,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildSaveStatusBadge(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // 4. Thẻ chế độ Kế hoạch bài giảng hoặc Link lớp học Meet
                if (isPlanningMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: 13,
                          color: Color(0xFF16A34A),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Kế hoạch bài giảng',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListenableBuilder(
                    listenable: MeetAutomationService(),
                    builder: (context, _) {
                      final meetService = MeetAutomationService();
                      final url = meetService.meetingUrl;
                      if (url == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                        decoration: BoxDecoration(
                          color: const Color(0xffeff6ff),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffbfdbfe)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              size: 15,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
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
                                      content: Text(
                                        'Đã sao chép link lớp học Google Meet!',
                                      ),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: Color(0xFF2563EB),
                                  ),
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
                                  child: Icon(
                                    Icons.open_in_new_rounded,
                                    size: 14,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // ==================== CỤM BÊN PHẢI (GIÓNG SÁT LỀ PHẢI) ====================
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Nút Thiết bị và API AI (Giữ nguyên IconButton gốc, trong không gian cố định 36x36)
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  tooltip: 'Thiết bị và API AI',
                  iconSize: 19,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: onToggleInspector,
                  icon: Icon(
                    hasInspector ? Icons.tune : Icons.tune_outlined,
                    color: hasInspector ? pine : muted,
                  ),
                ),
              ),

              // Các nút hành động cho Chế độ Soạn bài giảng (Planning Mode)
              if (isPlanningMode) ...[
                if (onExitPlanning != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 95,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: onExitPlanning,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text(
                        'Thoát',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.slate700,
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: AppColors.slate300,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Nút Lưu bài soạn với không gian 140px cố định: Khi bấm lưu và hiện "Đang lưu...", không làm xê dịch nút kế bên
                SizedBox(
                  width: 140,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: studio.saving || studio.loading ? null : onSave,
                    icon: studio.saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.save_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                    label: Text(
                      studio.saving ? 'Đang lưu…' : 'Lưu bài soạn',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shadowColor: const Color(
                        0xFF059669,
                      ).withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
                if (onCreateClassroomFromPlanning != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 155,
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: onCreateClassroomFromPlanning,
                      icon: const Icon(
                        Icons.videocam_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Tạo phòng học',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sky600,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shadowColor: AppColors.sky600.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Các nút hành động cho Chế độ Lớp học trực tiếp (Live Mode)
                const SizedBox(width: 4),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    tooltip: studio.saving ? 'Đang lưu…' : 'Lưu bài giảng',
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: studio.saving || studio.loading ? null : onSave,
                    icon: Icon(
                      studio.saving
                          ? Icons.hourglass_top_rounded
                          : Icons.save_outlined,
                      color: pine,
                    ),
                  ),
                ),
                if (onToggleStudents != null) ...[
                  const SizedBox(width: 4),
                  ListenableBuilder(
                    listenable: MeetAutomationService(),
                    builder: (context, _) {
                      final pendingCount =
                          MeetAutomationService().pendingAdmitCount;
                      Widget icon = Icon(
                        hasStudents ? Icons.groups : Icons.groups_outlined,
                        color: pine,
                      );
                      if (pendingCount > 0) {
                        icon = Badge.count(
                          count: pendingCount,
                          backgroundColor: const Color(0xFFDC2626),
                          textColor: Colors.white,
                          child: icon,
                        );
                      }
                      return SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          tooltip: pendingCount > 0
                              ? 'Danh sách học sinh ($pendingCount đang chờ duyệt)'
                              : 'Danh sách học sinh',
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: onToggleStudents,
                          style: IconButton.styleFrom(
                            backgroundColor: hasStudents
                                ? const Color(0xffedf2e5)
                                : Colors.transparent,
                          ),
                          icon: icon,
                        ),
                      );
                    },
                  ),
                ],
                ListenableBuilder(
                  listenable: MeetAutomationService(),
                  builder: (context, _) {
                    final meetService = MeetAutomationService();
                    final url = meetService.meetingUrl;
                    if (meetService.showEmbeddedMeet && url == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Chuẩn bị Meet',
                          style: TextStyle(fontSize: 11),
                        ),
                      );
                    }
                    if (url == null && onLeaveClassroom == null) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 145,
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => const CreateClassroomDialog(),
                              );
                            },
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Tạo lớp học',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 1,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
              if (studio.view != 'board') const MeetAdmissionButton(),
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
                onPressed: () => studio.setView(
                  studio.view == 'question' ? 'board' : 'question',
                ),
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
              if (!isPlanningMode)
                IconButton(
                  tooltip: studio.saving ? 'Đang lưu…' : 'Lưu bài giảng',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: studio.saving || studio.loading ? null : onSave,
                  icon: Icon(
                    studio.saving
                        ? Icons.hourglass_top_rounded
                        : Icons.save_outlined,
                    color: pine,
                  ),
                ),
              if (width > 800 && onTogglePlugins != null) ...[
                const SizedBox(width: 3),
                IconButton(
                  tooltip: 'Hoạt động & Tiện ích môn',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onTogglePlugins,
                  style: IconButton.styleFrom(
                    backgroundColor: hasPlugins
                        ? const Color(0xffedf2e5)
                        : Colors.transparent,
                  ),
                  icon: Icon(
                    hasPlugins ? Icons.extension : Icons.extension_outlined,
                    color: pine,
                  ),
                ),
              ],
              if (!isPlanningMode) ...[
                if (onLeaveClassroom != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 125,
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: onLeaveClassroom,
                      icon: const Icon(
                        Icons.call_end_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Rời phòng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shadowColor: const Color(
                          0xFFDC2626,
                        ).withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}
