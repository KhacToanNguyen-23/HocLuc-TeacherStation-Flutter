import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/core/platform/url_opener.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'workspace_roster_table.dart';
import 'workspace_events_card.dart';

class WorkspaceCourseDetail extends StatelessWidget {
  const WorkspaceCourseDetail({
    super.key,
    required this.course,
    required this.disabled,
    this.googleActionsDisabled = false,
    required this.startingCourseId,
    required this.hasStartRequest,
    required this.onCompleteClass,
    required this.onStartClass,
    required this.onAddStudents,
    required this.onSync,
    required this.onSchedule,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
    required this.onRestore,
    required this.onSetMeetAccess,
    this.isArchived = false,
    this.classroomSyncing = false,
    this.classroomSyncError,
  });

  final Map<String, dynamic> course;
  final bool disabled;
  final bool googleActionsDisabled;
  final String? startingCourseId;
  final bool hasStartRequest;
  final VoidCallback onCompleteClass;
  final VoidCallback onStartClass;
  final VoidCallback onAddStudents;
  final VoidCallback onSync;
  final VoidCallback onSchedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final bool isArchived;
  final void Function(Map<String, dynamic> course, Map<String, dynamic> student)
  onSetMeetAccess;
  final bool classroomSyncing;
  final String? classroomSyncError;

  Widget _notice(String text, {bool error = false}) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xfffff1ed) : const Color(0xffe8f4f3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline : Icons.info_outline,
          size: 20,
          color: error ? AppColors.error : AppColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );

  static ({String message, bool error})? _classroomStatus(
    Map<String, dynamic> course, {
    required bool syncing,
    required String? syncError,
  }) {
    final state = course['classroomState'];
    if (syncing) {
      return (message: 'Đang đồng bộ Classroom…', error: false);
    }
    if (syncError != null) {
      return (message: 'Đồng bộ Classroom thất bại: $syncError', error: true);
    }
    if (state is! String || state.isEmpty) return null;

    final warnings = (course['classroomWarnings'] as List? ?? [])
        .cast<String>();
    if (state == 'PROVISIONED') {
      return (
        message: 'Đang chờ kích hoạt trên Google Classroom.',
        error: false,
      );
    }
    if (state == 'ACTIVE') {
      if (warnings.isNotEmpty) {
        return (
          message: 'Lớp đã kích hoạt nhưng còn cảnh báo đồng bộ Classroom.',
          error: true,
        );
      }
      if (course['classroomSyncedAt'] is String &&
          (course['classroomSyncedAt'] as String).isNotEmpty) {
        return null;
      }
      return (
        message: 'Chưa đồng bộ thành viên. Bấm Đồng bộ để thử lại.',
        error: true,
      );
    }
    return (
      message: 'Trạng thái Classroom là $state. Kiểm tra lớp trong Classroom.',
      error: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseId = course['courseId'];
    final isRemote = courseId is String && courseId.isNotEmpty;
    final state = course['classroomState'];
    final canArchive = isRemote && state == 'ACTIVE';
    final canDeleteLocally = !isRemote;
    final actionDisabled = disabled || googleActionsDisabled;
    if (isArchived) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course['title'] as String,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _notice('Lớp đã lưu trữ. Khôi phục lớp để tiếp tục sử dụng.'),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: actionDisabled ? null : onRestore,
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Khôi phục lớp'),
                ),
                OutlinedButton.icon(
                  onPressed: actionDisabled ? null : onDelete,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Xóa vĩnh viễn'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final students = (course['students'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final joined = students
        .where((s) => s['classroomStatus'] == 'JOINED')
        .length;
    final warnings = [
      ...(course['warnings'] as List? ?? []),
      ...(course['classroomWarnings'] as List? ?? []),
    ].cast<String>();
    final classroomStatus = _classroomStatus(
      course,
      syncing: classroomSyncing,
      syncError: classroomSyncError,
    );
    final events = (course['events'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    final isStarting = startingCourseId == course['id'];
    final isResuming =
        TeachingLauncher.hasStudio &&
        MeetAutomationService().meetingUrl == course['meetingUrl'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course['title'] as String,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!isRemote || !googleActionsDisabled)
                    PopupMenuButton<String>(
                      enabled: !disabled,
                      tooltip: 'Tùy chọn lớp',
                      onSelected: (action) {
                        if (action == 'edit') onEdit();
                        if (action == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Sửa thông tin'),
                        ),
                        if (canDeleteLocally)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Xóa lớp'),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$joined đã tham gia · ${students.where((s) => s['classroomStatus'] == 'INVITED').length} chờ chấp nhận · ${students.length} trong danh sách',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (!isRemote)
                    FilledButton.icon(
                      onPressed: actionDisabled ? null : onCompleteClass,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Hoàn tất tạo lớp'),
                    ),
                  FilledButton.icon(
                    onPressed: actionDisabled || (isRemote && state != 'ACTIVE')
                        ? null
                        : onStartClass,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      isStarting
                          ? 'Đang chuẩn bị phòng…'
                          : isResuming
                          ? 'Tiếp tục dạy'
                          : hasStartRequest
                          ? 'Thử lại'
                          : 'Bắt đầu dạy',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: actionDisabled || (isRemote && state != 'ACTIVE')
                        ? null
                        : onAddStudents,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Thêm email học sinh'),
                  ),
                  OutlinedButton.icon(
                    onPressed: actionDisabled || (isRemote && state != 'ACTIVE')
                        ? null
                        : onSchedule,
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Lên lịch học'),
                  ),
                  if (course['classroomUrl'] case final String url
                      when url.isNotEmpty)
                    TextButton(
                      onPressed: () => openExternalUrl(url),
                      child: const Text('Mở Classroom'),
                    ),
                  if (canArchive)
                    OutlinedButton.icon(
                      onPressed: actionDisabled ? null : onArchive,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Lưu trữ lớp'),
                    ),
                  if (course['meetingUrl'] case final String url
                      when url.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép link Meet.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Sao chép link Meet'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (classroomStatus != null) ...[
                const SizedBox(height: 8),
                _notice(classroomStatus.message, error: classroomStatus.error),
              ],
              if (state == 'PROVISIONED')
                _notice(
                  'Mở Google Classroom và kích hoạt lớp trước khi lưu trữ.',
                ),
            ],
          ),
        ),
        for (final warning in warnings) _notice(warning, error: true),
        if (course['accessNotice'] != null)
          _notice(course['accessNotice'] as String),
        const SizedBox(height: 16),
        WorkspaceRosterTable(
          course: course,
          students: students,
          disabled: actionDisabled,
          onSetMeetAccess: onSetMeetAccess,
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 20),
          WorkspaceEventsCard(events: events),
        ],
      ],
    );
  }
}
