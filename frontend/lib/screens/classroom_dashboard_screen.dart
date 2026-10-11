import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/google_meet_auth_service.dart';
import '../services/meet_automation_service.dart';
import '../widgets/dashboard/dashboard_action_card.dart';
import '../widgets/dashboard/dashboard_empty_card.dart';
import '../widgets/dashboard/join_classroom_dialog.dart';
import '../widgets/dashboard/schedule_classroom_dialog.dart';
import 'studio_screen.dart';

/// Classroom Dashboard Screen styled to match the layout in Image 2 with Educational Green theme.
class ClassroomDashboardScreen extends StatefulWidget {
  const ClassroomDashboardScreen({super.key});

  @override
  State<ClassroomDashboardScreen> createState() => _ClassroomDashboardScreenState();
}

class _ClassroomDashboardScreenState extends State<ClassroomDashboardScreen> {
  final _meetService = MeetAutomationService();
  final _authService = GoogleMeetAuthService();
  bool _isStarting = false;
  String _selectedRoomFilter = 'Tất cả';
  Future<void> _startClassroom() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      await _meetService.createClassroom();
      if (mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const StudioScreen()),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _handleJoinClassroom() {
    JoinClassroomDialog.show(context);
  }

  void _handleScheduleClassroom() {
    ScheduleClassroomDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    const paper = AppColors.paper;

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.slate200)),
              ),
              child: Row(
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Mộc',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),

                  // Avatar Dropdown Menu: Cài đặt & Đăng xuất
                  ListenableBuilder(
                    listenable: _authService,
                    builder: (context, _) {
                      final name = _authService.teacherName ?? 'Thầy Khắc Toàn';
                      final emailOrPhone = _authService.teacherEmail ?? _authService.teacherPhone ?? 'khactoan2233@gmail.com';

                      return PopupMenuButton<String>(
                        tooltip: 'Hồ sơ & Cài đặt',
                        offset: const Offset(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.slate200),
                        ),
                        elevation: 4,
                        color: Colors.white,
                        onSelected: (value) {
                          if (value == 'settings') {
                            _showSettingsDialog(context);
                          } else if (value == 'logout') {
                            _authService.signOut();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  emailOrPhone,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          const PopupMenuItem<String>(
                            value: 'settings',
                            height: 40,
                            child: Row(
                              children: [
                                Icon(Icons.settings_outlined, size: 16, color: AppColors.slate900),
                                SizedBox(width: 10),
                                Text(
                                  'Cài đặt',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'logout',
                            height: 40,
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                                SizedBox(width: 10),
                                Text(
                                  'Đăng xuất',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.slate900,
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.sky400,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Dashboard Main Container
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Top Action Cards Row - Purely dynamic hover blue state
                        if (!isCompact) ...[
                          Row(
                            children: [
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Tham gia',
                                  icon: Icons.add_link_rounded,
                                  onTap: _handleJoinClassroom,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Bắt đầu',
                                  icon: Icons.menu_book_rounded,
                                  onTap: _startClassroom,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Lên lịch',
                                  icon: Icons.calendar_month_rounded,
                                  onTap: _handleScheduleClassroom,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Column(
                            children: [
                              DashboardActionCard(
                                title: 'Bắt đầu',
                                icon: Icons.menu_book_rounded,
                                onTap: _startClassroom,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DashboardActionCard(
                                      title: 'Tham gia',
                                      icon: Icons.add_link_rounded,
                                      onTap: _handleJoinClassroom,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DashboardActionCard(
                                      title: 'Lên lịch',
                                      icon: Icons.calendar_month_rounded,
                                      onTap: _handleScheduleClassroom,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),

                        // 2. Bottom Two Equal Columns
                        SizedBox(
                          height: 440,
                          child: isCompact
                              ? Column(
                                  children: [
                                    Expanded(child: _buildRoomListCard()),
                                    const SizedBox(height: 16),
                                    Expanded(child: _buildHistoryCard()),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: _buildRoomListCard()),
                                    const SizedBox(width: 20),
                                    Expanded(child: _buildHistoryCard()),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomListCard() {
    return DashboardEmptyCard(
      title: 'Phòng học',
      dropdownValue: _selectedRoomFilter,
      dropdownItems: const ['Tất cả', 'Đang diễn ra', 'Đã lên lịch'],
      onDropdownChanged: (val) {
        if (val != null) setState(() => _selectedRoomFilter = val);
      },
      illustrationType: 'rooms',
      emptyText: 'Chưa có phòng học',
      actionButton: ElevatedButton(
        onPressed: _startClassroom,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sky600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          elevation: 0,
        ),
        child: const Text('Bắt đầu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return const DashboardEmptyCard(
      title: 'Lịch sử',
      illustrationType: 'history',
      emptyText: 'Chưa có lịch sử',
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.slate200),
        ),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, size: 20, color: AppColors.sky600),
            SizedBox(width: 8),
            Text('Cài đặt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.videocam_outlined, color: AppColors.sky600),
                title: const Text('Tự động bật camera khi vào lớp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: Switch(value: true, activeThumbColor: AppColors.sky600, onChanged: (_) {}),
              ),
              const Divider(height: 1, color: AppColors.slate200),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mic_none_rounded, color: AppColors.sky600),
                title: const Text('Khử tiếng ồn micro thông minh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: Switch(value: true, activeThumbColor: AppColors.sky600, onChanged: (_) {}),
              ),
              const Divider(height: 1, color: AppColors.slate200),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.draw_outlined, color: AppColors.sky600),
                title: const Text('Tối ưu hóa bút vẽ & cảm ứng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: Switch(value: true, activeThumbColor: AppColors.sky600, onChanged: (_) {}),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sky600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              elevation: 0,
            ),
            child: const Text('Đóng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
