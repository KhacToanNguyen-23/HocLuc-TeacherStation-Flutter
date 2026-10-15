import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/google_meet_auth_service.dart';
import '../services/local_service.dart';
import '../services/meet_automation_service.dart';
import '../widgets/dashboard/dashboard_action_card.dart';
import '../widgets/dashboard/exam_dashboard_card.dart';
import '../widgets/dashboard/dashboard_empty_card.dart';
import '../widgets/dashboard/join_classroom_dialog.dart';
import '../widgets/dashboard/schedule_classroom_dialog.dart';
import '../services/teaching_launcher.dart';
import '../services/google_workspace_api.dart';
import '../models/teaching_target.dart';
import '../services/teacher_media_service.dart';
import 'login_screen.dart';
import 'studio_screen.dart';
import '../models/planning_meta.dart';
import '../widgets/dashboard/planning_list_card.dart';
import 'exams/exam_workspace_screen.dart';
import '../services/exam_api.dart';
import '../services/exam_session_service.dart';
import 'google_workspace_screen.dart';

/// Classroom Dashboard Screen styled to match the layout in Image 2 with Educational Green theme.
class ClassroomDashboardScreen extends StatefulWidget {
  const ClassroomDashboardScreen({super.key, this.examApi});
  final ExamApi? examApi;

  @override
  State<ClassroomDashboardScreen> createState() => _ClassroomDashboardScreenState();
}

class _ClassroomDashboardScreenState extends State<ClassroomDashboardScreen> {
  final _authService = GoogleMeetAuthService();
  final _localService = LocalService();
  String _selectedRoomFilter = 'Tất cả';

  int _selectedTabIndex = 0; // 0: Phòng học, 1: Kế hoạch bài giảng, 2: Lịch sử
  List<PlanningMeta> _plannings = [];
  bool _loadingPlannings = false;
  String _selectedSubjectFilter = 'Tất cả';
  final List<String> _subjectOptions = [
    'Tất cả',
    'Tiếng Anh',
    'Toán',
    'Ngữ văn',
    'Vật lý',
    'Hóa học',
    'Sinh học',
    'Lịch sử',
    'Địa lý',
    'Chung',
  ];

  Map<String, dynamic>? _activeRoom;
  List<dynamic> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadRoomsAndHistory();
    _loadPlannings();
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

  Future<void> _loadPlannings() async {
    setState(() => _loadingPlannings = true);
    final list = await _localService.getPlannings();
    if (mounted) {
      setState(() {
        _plannings = list;
        _loadingPlannings = false;
      });
    }
  }

  Future<void> _handleCreateNewPlanning() async {
    final titleController = TextEditingController(text: 'Kế hoạch bài giảng mới');
    String selectedSub = 'Tiếng Anh';

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.sky600),
              SizedBox(width: 8),
              Text('Soạn kế hoạch bài giảng mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tên kế hoạch bài giảng', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate700)),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nhập tên bài giảng...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Môn học', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.slate300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSub,
                    isExpanded: true,
                    items: _subjectOptions.where((s) => s != 'Tất cả').map((s) {
                      return DropdownMenuItem<String>(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedSub = val);
                    },
                  ),
                ),
              ),
            ],
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Bắt đầu soạn'),
            ),
          ],
        ),
      ),
    );

    if (shouldCreate != true || !mounted) return;

    final title = titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'Kế hoạch bài giảng mới';
    final newPlan = await _localService.createPlanning(title: title, subject: selectedSub);

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudioScreen(
          isPlanningMode: true,
          planningId: newPlan?.id,
          lessonTitle: title,
        ),
      ),
    );
    _loadPlannings();
  }

  Future<void> _handleEditPlanning(PlanningMeta plan) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudioScreen(
          isPlanningMode: true,
          planningId: plan.id,
          lessonTitle: plan.title,
        ),
      ),
    );
    _loadPlannings();
  }

  Future<void> _handleLaunchFromPlanning(PlanningMeta plan) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => GoogleWorkspaceScreen(planningId: plan.id, lessonTitle: plan.title)));
    if (mounted) { await _loadRoomsAndHistory(); await _loadPlannings(); }
  }

  Future<void> _handleDeletePlanning(PlanningMeta plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa kế hoạch bài giảng?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Bạn có chắc chắn muốn xóa bài giảng "${plan.title}"?\nThao tác này không thể hoàn tác.',
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
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _localService.deletePlanning(plan.id);
      _loadPlannings();
    }
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required IconData icon,
    int? badgeCount,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedTabIndex = index);
        if (index == 1) _loadPlannings();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.sky600 : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.sky600.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected ? AppColors.sky600 : AppColors.slate600,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.sky600 : AppColors.slate700,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.sky50 : AppColors.slate200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.sky600 : AppColors.slate600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startClassroom() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const GoogleWorkspaceScreen()));
    if (mounted) await _loadRoomsAndHistory();
  }

  Future<void> _rejoinClassroom(String meetUrl) async {
    if (TeachingLauncher.hasStudio && MeetAutomationService().meetingUrl == meetUrl) {
      TeachingLauncher.returnToStudio();
      return;
    }
    String? courseId;
    final email = _authService.teacherEmail;
    if (email != null) {
      final api = GoogleWorkspaceApi(email: email);
      try {
        final result = await api.call('courses');
        for (final item in result['courses'] as List) {
          if (item['meetingUrl'] == meetUrl) { courseId = item['id'] as String; break; }
        }
      } catch (_) { /* A one-off room doesn't require a Google API connection. */ }
      finally { api.close(); }
    }
    if (!mounted) return;
    try {
      await TeachingLauncher.open(context, TeachingTarget(
        title: _activeRoom?['title'] as String? ?? 'Buổi học đang mở',
        meetingUrl: meetUrl, courseId: courseId, teacherEmail: courseId == null ? null : email,
      ));
      if (mounted) await _loadRoomsAndHistory();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _handleJoinClassroom() {
    JoinClassroomDialog.show(context);
  }

  void _handleScheduleClassroom() {
    ScheduleClassroomDialog.show(context);
  }

  void _openExams(int page) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ExamWorkspaceScreen(api: widget.examApi, initialPage: page),
    ));
  }

  Future<void> _handleLogout() async {
    if (TeachingLauncher.hasStudio || MeetAutomationService().hasRoom) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Lưu bài và kết thúc buổi dạy trước khi đăng xuất HocLuc.'),
        action: TeachingLauncher.hasStudio ? SnackBarAction(label: 'Về buổi dạy', onPressed: TeachingLauncher.returnToStudio) : null,
      )); }
      return;
    }
    await MeetAutomationService().leaveClassroom();
    await TeacherMediaService().shutdown();
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
                  IconButton(
                    tooltip: 'Lớp học & kết nối Google',
                    icon: const Icon(Icons.hub_outlined, color: AppColors.sky600),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const GoogleWorkspaceScreen()),
                    ),
                  ),
                  if (isCompact) IconButton(
                    tooltip: 'Đề thi & năng lực',
                    icon: const Icon(Icons.assignment_outlined, color: AppColors.sky600),
                    onPressed: () => _openExams(0),
                  ) else Tooltip(
                    message: 'Đề thi & năng lực',
                    child: TextButton.icon(
                      onPressed: () => _openExams(0),
                      icon: const Icon(Icons.assignment_outlined, size: 20),
                      label: const Text('Đề thi & năng lực'),
                    ),
                  ),
                  const SizedBox(width: 8),

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
                                  title: 'Chọn lớp để dạy',
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
                                title: 'Chọn lớp để dạy',
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

                        const SizedBox(height: 16),

                        ListenableBuilder(
                          listenable: Listenable.merge([_authService, ExamSessionService()]),
                          builder: (context, _) => ExamDashboardCard(
                            onOpen: _openExams,
                            isAdmin: ExamSessionService().role == 'ADMIN',
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tab Bar: 3 Horizontal Tabs
                        Row(
                          children: [
                            _buildTabButton(
                              index: 0,
                              title: 'Phòng học',
                              icon: Icons.meeting_room_outlined,
                              badgeCount: _activeRoom != null ? 1 : null,
                            ),
                            const SizedBox(width: 8),
                            _buildTabButton(
                              index: 1,
                              title: 'Kế hoạch bài giảng',
                              icon: Icons.menu_book_outlined,
                              badgeCount: _plannings.isNotEmpty ? _plannings.length : null,
                            ),
                            const SizedBox(width: 8),
                            _buildTabButton(
                              index: 2,
                              title: 'Lịch sử',
                              icon: Icons.history_rounded,
                              badgeCount: _historyList.isNotEmpty ? _historyList.length : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Tab Content View
                        SizedBox(
                          height: 380,
                          child: _selectedTabIndex == 0
                              ? _buildRoomListCard()
                              : _selectedTabIndex == 1
                                  ? PlanningListCard(
                                      plannings: _plannings,
                                      isLoading: _loadingPlannings,
                                      selectedSubject: _selectedSubjectFilter,
                                      subjectOptions: _subjectOptions,
                                      onSubjectChanged: (val) {
                                        if (val != null) setState(() => _selectedSubjectFilter = val);
                                      },
                                      onCreateNew: _handleCreateNewPlanning,
                                      onEdit: _handleEditPlanning,
                                      onLaunch: _handleLaunchFromPlanning,
                                      onDelete: _handleDeletePlanning,
                                    )
                                  : _buildHistoryCard(),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
          ),
          child: const Text('Bắt đầu', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
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
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Vào lại phòng', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sky600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                        ),
                        child: const Text('Tạo mới', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
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
              separatorBuilder: (context, index) => const Divider(height: 12, color: AppColors.slate100),
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
