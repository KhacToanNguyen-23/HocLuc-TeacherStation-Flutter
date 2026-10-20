import 'package:teaching_companion/features/classroom_meet/presentation/meet_admission_button.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/dashboard_action_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/exam_dashboard_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/dashboard_empty_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/join_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/schedule_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';
import 'package:teaching_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:teaching_companion/features/studio_board/presentation/screens/studio_screen.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/services/planning_repository.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/planning_list_card.dart';
import 'package:teaching_companion/features/exams/presentation/screens/exam_workspace_screen.dart';
import 'package:teaching_companion/features/exams/services/exam_api.dart';
import 'package:teaching_companion/features/exams/services/exam_session_service.dart';
import 'google_workspace_screen.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/select_classroom_dialog.dart';
import 'package:teaching_companion/core/ui/google_brand_icon.dart';

part 'classroom_dashboard_rooms_and_history.dart';

/// Classroom Dashboard Screen styled to match the layout in Image 2 with Educational Green theme.
class ClassroomDashboardScreen extends StatefulWidget {
  const ClassroomDashboardScreen({super.key, this.examApi});
  final ExamApi? examApi;

  @override
  State<ClassroomDashboardScreen> createState() =>
      _ClassroomDashboardScreenState();
}

class _ClassroomDashboardScreenState extends State<ClassroomDashboardScreen> {
  final _authService = GoogleMeetAuthService();
  final _localService = LocalService();
  late final _planningRepository = PlanningRepository(localService: _localService);
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
        _activeRoom = active.isNotEmpty && active['status'] == 'ONGOING'
            ? active
            : null;
        _historyList = history;
      });
    }
  }

  Future<void> _loadPlannings() async {
    setState(() => _loadingPlannings = true);
    final list = await _planningRepository.getPlannings();
    if (mounted) {
      setState(() {
        _plannings = list;
        _loadingPlannings = false;
      });
    }
  }

  Future<void> _handleCreateNewPlanning() async {
    final titleController = TextEditingController(
      text: 'Kế hoạch bài giảng mới',
    );
    String selectedSub = 'Tiếng Anh';

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.panel),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.edit_calendar_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Soạn kế hoạch bài giảng mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tên kế hoạch bài giảng',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nhập tên bài giảng...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Môn học',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.control),
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
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
              ),
              child: const Text('Bắt đầu soạn'),
            ),
          ],
        ),
      ),
    );

    if (shouldCreate != true || !mounted) return;

    final title = titleController.text.trim().isNotEmpty
        ? titleController.text.trim()
        : 'Kế hoạch bài giảng mới';
    final newPlan = await _planningRepository.createPlanning(
      title: title,
      subject: selectedSub,
    );

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
    await SelectClassroomDialog.show(context, plan: plan);
    if (mounted) {
      await _loadRoomsAndHistory();
      await _loadPlannings();
    }
  }

  Future<void> _handleDeletePlanning(PlanningMeta plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        title: const Text(
          'Xóa kế hoạch bài giảng?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa bài giảng "${plan.title}"?\nThao tác này không thể hoàn tác.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _planningRepository.deletePlanning(plan.id);
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
        if (index == 1) {
          _loadPlannings();
        } else {
          _loadRoomsAndHistory();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, milliseconds: 200),
        curve: AppMotion.stateCurve,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selected : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.slate700,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const GoogleWorkspaceScreen()),
    );
    if (mounted) await _loadRoomsAndHistory();
  }

  Future<void> _rejoinClassroom(String meetUrl) async {
    if (TeachingLauncher.hasStudio &&
        MeetAutomationService().meetingUrl == meetUrl) {
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
          if (item['meetingUrl'] == meetUrl) {
            courseId = item['id'] as String;
            break;
          }
        }
      } catch (_) {
        /* A one-off room doesn't require a Google API connection. */
      } finally {
        api.close();
      }
    }
    if (!mounted) return;
    try {
      await TeachingLauncher.open(
        context,
        TeachingTarget(
          title: _activeRoom?['title'] as String? ?? 'Buổi học đang mở',
          meetingUrl: meetUrl,
          courseId: courseId,
          teacherEmail: courseId == null ? null : email,
        ),
      );
      if (mounted) await _loadRoomsAndHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _handleJoinClassroom() {
    JoinClassroomDialog.show(context);
  }

  void _handleScheduleClassroom() {
    ScheduleClassroomDialog.show(context);
  }

  void _openExams(int page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ExamWorkspaceScreen(api: widget.examApi, initialPage: page),
      ),
    );
  }

  Future<void> _handleLogout() async {
    if (TeachingLauncher.hasStudio || MeetAutomationService().hasRoom) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Lưu bài và kết thúc buổi dạy trước khi đăng xuất HocLuc.',
            ),
            action: TeachingLauncher.hasStudio
                ? SnackBarAction(
                    label: 'Về buổi dạy',
                    onPressed: TeachingLauncher.returnToStudio,
                  )
                : null,
          ),
        );
      }
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

    final viewport = MediaQuery.sizeOf(context);
    final screenWidth = viewport.width;
    final isCompact = screenWidth < 800;
    final tabContentHeight = isCompact ? 340.0 : 380.0;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: const Center(
                      child: Text(
                        'H',
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
                    'HocLucStation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  const MeetAdmissionButton(),
                  IconButton(
                    tooltip: 'Lớp học & kết nối Google',
                    icon: const GoogleBrandIcon(size: 20),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const GoogleWorkspaceScreen(),
                      ),
                    ),
                  ),
                  if (isCompact)
                    IconButton(
                      tooltip: 'Đề thi & năng lực',
                      icon: const Icon(
                        Icons.assignment_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _openExams(0),
                    )
                  else
                    Tooltip(
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
                      final emailOrPhone =
                          _authService.teacherEmail ??
                          _authService.teacherPhone ??
                          '';

                      return PopupMenuButton<String>(
                        tooltip: 'Hồ sơ & Cài đặt',
                        offset: const Offset(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
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
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (emailOrPhone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    emailOrPhone,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
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
                                Icon(
                                  Icons.settings_outlined,
                                  size: 16,
                                  color: AppColors.textPrimary,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Cài đặt',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
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
                                Icon(
                                  Icons.logout_rounded,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Đăng xuất',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
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
                            backgroundColor: AppColors.border,
                            child: Text(
                              name.isNotEmpty
                                  ? name.substring(0, 1).toUpperCase()
                                  : 'G',
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
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? AppSpacing.lg : AppSpacing.xxxl,
                  vertical: AppSpacing.xxl,
                ),
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
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Chọn lớp để dạy',
                                  icon: Icons.videocam_rounded,
                                  onTap: _startClassroom,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
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
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: DashboardActionCard(
                                      title: 'Tham gia',
                                      icon: Icons.add_link_rounded,
                                      onTap: _handleJoinClassroom,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
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

                        const SizedBox(height: AppSpacing.xxl),

                        ListenableBuilder(
                          listenable: Listenable.merge([
                            _authService,
                            ExamSessionService(),
                          ]),
                          builder: (context, _) => ExamDashboardCard(
                            onOpen: _openExams,
                            isAdmin: ExamSessionService().role == 'ADMIN',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        // Tab Bar: 3 Horizontal Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabButton(
                                index: 0,
                                title: 'Phòng học',
                                icon: Icons.meeting_room_outlined,
                                badgeCount: _activeRoom != null ? 1 : null,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _buildTabButton(
                                index: 1,
                                title: 'Kế hoạch bài giảng',
                                icon: Icons.menu_book_outlined,
                                badgeCount: _plannings.isNotEmpty
                                    ? _plannings.length
                                    : null,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _buildTabButton(
                                index: 2,
                                title: 'Lịch sử',
                                icon: Icons.history_rounded,
                                badgeCount: _historyList.isNotEmpty
                                    ? _historyList.length
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25.4),

                        // Tab Content View
                        SizedBox(
                          height: tabContentHeight,
                          child: AnimatedSwitcher(
                            duration: AppMotion.duration(
                              context,
                              milliseconds: 180,
                            ),
                            switchInCurve: AppMotion.enterCurve,
                            switchOutCurve: AppMotion.exitCurve,
                            transitionBuilder: (child, animation) {
                              final slide =
                                  Tween<Offset>(
                                    begin: const Offset(0, 0.025),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: AppMotion.enterCurve,
                                    ),
                                  );
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_selectedTabIndex),
                              child: _selectedTabIndex == 0
                                  ? _buildRoomListCard()
                                  : _selectedTabIndex == 1
                                  ? PlanningListCard(
                                      plannings: _plannings,
                                      isLoading: _loadingPlannings,
                                      selectedSubject: _selectedSubjectFilter,
                                      subjectOptions: _subjectOptions,
                                      onSubjectChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _selectedSubjectFilter = val,
                                          );
                                        }
                                      },
                                      onCreateNew: _handleCreateNewPlanning,
                                      onEdit: _handleEditPlanning,
                                      onLaunch: _handleLaunchFromPlanning,
                                      onDelete: _handleDeletePlanning,
                                    )
                                  : _buildHistoryCard(),
                            ),
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
}


