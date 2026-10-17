import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import '../../services/url_opener.dart';
import '../../services/teaching_launcher.dart';
import '../../services/meet_automation_service.dart';
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
  final void Function(Map<String, dynamic> course, Map<String, dynamic> student) onSetMeetAccess;

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

  @override
  Widget build(BuildContext context) {
    final students = (course['students'] as List? ?? []).cast<Map<String, dynamic>>();
    final joined = students.where((s) => s['classroomStatus'] == 'JOINED').length;
    final warnings = [
      ...(course['warnings'] as List? ?? []),
      ...(course['classroomWarnings'] as List? ?? []),
    ].cast<String>();
    final events = (course['events'] as List? ?? []).cast<Map<String, dynamic>>();

    final isStarting = startingCourseId == course['id'];
    final isResuming = TeachingLauncher.hasStudio &&
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
                  if (course['classroomUrl'] case final String url when url.isNotEmpty)
                    TextButton(
                      onPressed: () => openExternalUrl(url),
                      child: const Text('Mở Classroom'),
                    ),
                  if (course['meetingUrl'] case final String url when url.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sao chép link Meet.')),
                          );
                        }
                      },
                      child: const Text('Sao chép link Meet'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course['syncedAt'] == null
                    ? 'Chưa đồng bộ thành viên.'
                    : 'Đồng bộ gần nhất: ${_date(course['syncedAt'] as String)}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nhập email học sinh một lần, sau đó bấm Bắt đầu dạy. HocLucStation tự chuẩn bị phòng và gửi lời mời cho buổi học. Học sinh dùng link của buổi này và đúng email được mời.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        for (final warning in warnings) _notice(warning, error: true),
        if (course['accessNotice'] != null) _notice(course['accessNotice'] as String),
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
