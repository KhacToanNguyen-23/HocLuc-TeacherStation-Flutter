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
    required this.startingCourseId,
    required this.hasStartRequest,
    required this.onCompleteClass,
    required this.onStartClass,
    required this.onAddStudents,
    required this.onSync,
    required this.onSchedule,
    required this.onSetMeetAccess,
    this.classroomSyncing = false,
    this.classroomSyncError,
  });

  final Map<String, dynamic> course;
  final bool disabled;
  final String? startingCourseId;
  final bool hasStartRequest;
  final VoidCallback onCompleteClass;
  final VoidCallback onStartClass;
  final VoidCallback onAddStudents;
  final VoidCallback onSync;
  final VoidCallback onSchedule;
  final void Function(Map<String, dynamic> course, Map<String, dynamic> student)
  onSetMeetAccess;
  final bool classroomSyncing;
  final String? classroomSyncError;

  static String _date(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _notice(String text, {bool error = false}) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(14),
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
      final pendingGuidance = state == 'PROVISIONED'
          ? ' Nếu lớp chưa được kích hoạt. Mở Classroom để chấp nhận.'
          : '';
      return (message: 'Đang đồng bộ Classroom…$pendingGuidance', error: false);
    }
    if (syncError != null) {
      final retryGuidance = state == 'PROVISIONED'
          ? ' Lớp vẫn chờ được kích hoạt. Mở Classroom để chấp nhận. Thử lại bằng nút Đồng bộ hoặc khi bạn quay lại ứng dụng.'
          : ' Bấm nút Đồng bộ để thử lại.';
      return (
        message: 'Không thể đồng bộ Classroom: $syncError.$retryGuidance',
        error: true,
      );
    }
    if (state is! String || state.isEmpty) return null;

    final warnings = (course['classroomWarnings'] as List? ?? [])
        .cast<String>();
    if (state == 'PROVISIONED') {
      return (
        message:
            'Lớp đã tạo nhưng chưa được Google kích hoạt. Mở Classroom để chấp nhận; HocLucStation sẽ tự kiểm tra khi bạn quay lại.',
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
        return (message: 'Đã đồng bộ thành viên từ Classroom.', error: false);
      }
      return (
        message:
            'Lớp đã kích hoạt nhưng chưa xác nhận đồng bộ thành viên. Bấm Đồng bộ để thử lại.',
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
          padding: const EdgeInsets.all(20),
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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$joined đã tham gia · ${students.where((s) => s['classroomStatus'] == 'INVITED').length} chờ chấp nhận · ${students.length} trong danh sách',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (course['courseId'] == null)
                    FilledButton.icon(
                      onPressed: disabled ? null : onCompleteClass,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Hoàn tất tạo lớp'),
                    ),
                  FilledButton.icon(
                    onPressed: disabled ? null : onStartClass,
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
                    onPressed: disabled ? null : onAddStudents,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Thêm email học sinh'),
                  ),
                  PopupMenuButton<String>(
                    enabled: !disabled,
                    tooltip: 'Thao tác khác',
                    onSelected: (_) => onSync(),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'sync',
                        child: Text('Đồng bộ'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz),
                  ),
                  OutlinedButton.icon(
                    onPressed: disabled ? null : onSchedule,
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Lên lịch học'),
                  ),
                  if (course['classroomUrl'] case final String url
                      when url.isNotEmpty)
                    TextButton(
                      onPressed: () => openExternalUrl(url),
                      child: const Text('Mở Classroom'),
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
              Text(
                course['classroomSyncedAt'] == null
                    ? 'Chưa đồng bộ thành viên.'
                    : 'Đồng bộ gần nhất: ${_date(course['classroomSyncedAt'] as String)}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (classroomStatus != null) ...[
                const SizedBox(height: 8),
                _notice(classroomStatus.message, error: classroomStatus.error),
              ],
              const SizedBox(height: 6),
              const Text(
                'Nhập email học sinh một lần, sau đó bấm Bắt đầu dạy. HocLucStation tự chuẩn bị phòng và gửi lời mời cho buổi học. Học sinh dùng link của buổi này và đúng email được mời.',
                style: TextStyle(color: AppColors.textSecondary),
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
          disabled: disabled,
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


