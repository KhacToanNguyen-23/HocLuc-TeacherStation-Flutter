import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/google_meet_auth_service.dart';
import '../services/local_service.dart';
import '../services/meet_automation_service.dart';
import '../widgets/dashboard/dashboard_action_card.dart';
import '../widgets/dashboard/dashboard_empty_card.dart';
import '../widgets/dashboard/join_classroom_dialog.dart';
import '../widgets/dashboard/schedule_classroom_dialog.dart';
import 'classroom_lobby_screen.dart';
import 'login_screen.dart';

/// Classroom Dashboard Screen styled to match the layout in Image 2 with Educational Green theme.
class ClassroomDashboardScreen extends StatefulWidget {
  const ClassroomDashboardScreen({super.key});

  @override
  State<ClassroomDashboardScreen> createState() => _ClassroomDashboardScreenState();
}

class _ClassroomDashboardScreenState extends State<ClassroomDashboardScreen> {
  final _authService = GoogleMeetAuthService();
  final _localService = LocalService();
  bool _isStarting = false;
  String _selectedRoomFilter = 'Tất cả';

  Map<String, dynamic>? _activeRoom;
  List<dynamic> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadRoomsAndHistory();
  }

  Future<void> _loadRoomsAndHistory() async {
    final active = await _localService.getActiveClassroom();
    final history = await _localService.getClassroomHistory();
    if (mounted) {
      setState(() {
        _activeRoom = active.isNotEmpty && active['status'] == 'ONGOING' ? active : null;
        _historyList = history;
      });
    }
  }

  Future<void> _startClassroom() async {
    if (_isStarting) return;

    // Nếu đang có phòng cũ đang chạy, hỏi giáo viên trước khi tạo phòng mới
    if (_activeRoom != null && _activeRoom!['status'] == 'ONGOING') {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tạo phòng học mới?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Text(
            'Bạn đang có buổi học "${_activeRoom!['title'] ?? 'Hiện tại'}" chưa kết thúc.\n'
            'Tạo phòng mới sẽ đóng phòng học cũ và bắt đầu một link Google Meet mới 100%. Bạn có muốn tiếp tục?',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy', style: TextStyle(color: AppColors.slate600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sky600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Đóng cũ & Tạo mới'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;

      // Đóng phòng cũ trên backend
      await _localService.endClassroom(classroomId: _activeRoom!['id']?.toString());
      await MeetAutomationService().leaveClassroom();
    }

    setState(() => _isStarting = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.sky600),
                  ),
                ),
                SizedBox(width: 20),
                Text(
                  'Đang tạo lớp học...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    String? realMeetUrl;
    try {
      realMeetUrl = await MeetAutomationService().generateAndJoinRealMeetRoom();
    } catch (e) {
      debugPrint('[Dashboard] Error starting meet room: $e');
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isStarting = false);
      }
    }

    if (mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ClassroomLobbyScreen(
            initialMeetingUrl: realMeetUrl,
          ),
        ),
      );
      _loadRoomsAndHistory();
    }
  }

  Future<void> _rejoinClassroom(String meetUrl) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ClassroomLobbyScreen(
          initialMeetingUrl: meetUrl,
        ),
      ),
    );
    _loadRoomsAndHistory();
  }

  void _handleJoinClassroom() {
    JoinClassroomDialog.show(context);
  }

  void _handleScheduleClassroom() {
    ScheduleClassroomDialog.show(context);
  }

  Future<void> _handleLogout() async {
    await MeetAutomationService().leaveClassroom();
    _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
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
                      final name = _authService.teacherName ?? 'Giáo viên';
                      final emailOrPhone = _authService.teacherEmail ?? _authService.teacherPhone ?? '';

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
                            _handleLogout();
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
                                if (emailOrPhone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    emailOrPhone,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ],
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
                            radius: 17,
                            backgroundColor: AppColors.slate200,
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.slate700,
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

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Top Action Cards Row
                        if (!isCompact)
                          Row(
                            children: [
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Tham gia',
                                  icon: Icons.add_link_rounded,
                                  onTap: _handleJoinClassroom,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Bắt đầu',
                                  icon: Icons.videocam_rounded,
                                  onTap: _startClassroom,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Lên lịch',
                                  icon: Icons.calendar_month_rounded,
                                  onTap: _handleScheduleClassroom,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          Column(
                            children: [
                              DashboardActionCard(
                                title: 'Bắt đầu',
                                icon: Icons.videocam_rounded,
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
                          height: 380,
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
    final hasOngoing = _activeRoom != null && _activeRoom!['status'] == 'ONGOING';

    if (!hasOngoing) {
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

    final title = _activeRoom!['title']?.toString() ?? 'Phòng học trực tuyến';
    final meetUrl = _activeRoom!['meetingUrl']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Phòng học', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF16A34A)),
                    SizedBox(width: 5),
                    Text('Đang diễn ra', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.video_call_rounded, color: AppColors.sky600, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meetUrl,
                              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontFamily: 'monospace'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejoinClassroom(meetUrl),
                          icon: const Icon(Icons.login_rounded, size: 16),
                          label: const Text('Vào lại phòng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sky600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _startClassroom,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate700,
                          side: const BorderSide(color: AppColors.slate300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: const Text('Tạo mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    if (_historyList.isEmpty) {
      return const DashboardEmptyCard(
        title: 'Lịch sử',
        illustrationType: 'history',
        emptyText: 'Chưa có lịch sử',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lịch sử', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate900)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _historyList.length,
              separatorBuilder: (_, __) => const Divider(height: 12, color: AppColors.slate100),
              itemBuilder: (context, index) {
                final item = _historyList[index] as Map<String, dynamic>;
                final title = item['title']?.toString() ?? 'Phòng học trực tuyến';
                final duration = item['durationMinutes'] ?? 0;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.slate500),
                  ),
                  title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: Text(
                    duration > 0 ? '$duration phút • Đã xong' : 'Đã xong',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate400),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng', style: TextStyle(color: AppColors.slate600, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
