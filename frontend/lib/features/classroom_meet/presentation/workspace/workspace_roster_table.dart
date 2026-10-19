import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';

class WorkspaceRosterTable extends StatelessWidget {
  const WorkspaceRosterTable({
    super.key,
    required this.course,
    required this.students,
    required this.disabled,
    required this.onSetMeetAccess,
  });

  final Map<String, dynamic> course;
  final List<Map<String, dynamic>> students;
  final bool disabled;
  final void Function(Map<String, dynamic> course, Map<String, dynamic> student)
  onSetMeetAccess;

  static Widget statusBadge(String status) {
    const labels = {
      'JOINED': 'Đã tham gia',
      'INVITED': 'Chờ chấp nhận',
      'INVITE_FAILED': 'Mời thất bại',
      'NOT_INVITED': 'Chưa mời',
      'LEFT': 'Đã rời lớp',
      'INVITATION_CLOSED': 'Lời mời đã đóng',
      'GRANTED': 'Đã lưu membership',
      'CALENDAR_INVITED': 'Có trong lời mời Calendar',
      'VERIFYING': 'Đang xác nhận',
      'VERIFY_FAILED': 'Chưa xác nhận quyền',
      'EXTERNAL_ACCESS': 'Quyền ngoài HocLucStation',
      'NOT_GRANTED': 'Chưa cấp quyền',
      'GRANT_FAILED': 'Cấp quyền thất bại',
      'REVOKE_FAILED': 'Chưa gỡ được quyền',
    };
    final success = status == 'JOINED' || status == 'GRANTED';
    final failed = status.endsWith('FAILED');
    final color = success
        ? AppColors.success
        : failed
        ? AppColors.error
        : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: success
            ? AppColors.successSurface
            : failed
            ? AppColors.errorSurface
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Text(
        labels[status] ?? 'Chưa xác định',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1000) {
            return Column(
              children: students
                  .map(
                    (student) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['name'] as String? ??
                                student['email'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(student['email'] as String),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              statusBadge(
                                student['classroomStatus'] as String? ?? '',
                              ),
                              statusBadge(
                                student['meetStatus'] as String? ?? '',
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: disabled
                                ? null
                                : () => onSetMeetAccess(course, student),
                            child: Text(
                              student['meetAllowed'] == true
                                  ? 'Gỡ quyền Meet'
                                  : 'Cấp quyền Meet',
                            ),
                          ),
                          if (student['classroomError'] != null)
                            Text('Classroom: ${student['classroomError']}'),
                          if (student['error'] != null)
                            Text(
                              student['error'] as String,
                              style: const TextStyle(color: AppColors.error),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          }
          return SizedBox(
            width: double.infinity,
            child: DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Học sinh / Email')),
                DataColumn(label: Text('Classroom')),
                DataColumn(label: Text('Quyền vào Meet')),
                DataColumn(label: Text('Thao tác')),
              ],
              rows: students
                  .map(
                    (s) => DataRow(
                      cells: [
                        DataCell(
                          Tooltip(
                            message:
                                s['error'] as String? ?? s['email'] as String,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['name'] as String? ?? s['email'] as String,
                                ),
                                Text(
                                  s['email'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          statusBadge(s['classroomStatus'] as String? ?? ''),
                        ),
                        DataCell(statusBadge(s['meetStatus'] as String? ?? '')),
                        DataCell(
                          TextButton(
                            onPressed: disabled
                                ? null
                                : () => onSetMeetAccess(course, s),
                            child: Text(
                              s['meetAllowed'] == true
                                  ? 'Gỡ quyền Meet'
                                  : 'Cấp quyền Meet',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}

