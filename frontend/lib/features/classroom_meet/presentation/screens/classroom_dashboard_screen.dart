import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:teaching_companion/features/classroom_meet/bloc/classroom_dashboard_cubit.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/meet_admission_button.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/meet_webview.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/dashboard_action_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/exam_dashboard_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/dashboard_empty_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/create_planning_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/join_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/schedule_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/classroom_settings_service.dart';
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
import 'package:teaching_companion/features/classroom_meet/presentation/screens/google_workspace_screen.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/select_classroom_dialog.dart';
import 'package:teaching_companion/core/ui/google_brand_icon.dart';
import 'package:teaching_companion/core/ui/hocluc_brand_mark.dart';

part 'classroom_dashboard_rooms_and_history.dart';

/// Classroom Dashboard Screen styled to match the layout in Image 2 with Educational Green theme.
class ClassroomDashboardScreen extends StatefulWidget {
  const ClassroomDashboardScreen({super.key, this.examApi, this.cubit});
  final ExamApi? examApi;
  final ClassroomDashboardCubit? cubit;

  @override
  State<ClassroomDashboardScreen> createState() =>
      _ClassroomDashboardScreenState();
}

class _ClassroomDashboardScreenState extends State<ClassroomDashboardScreen> {
  final _authService = GoogleMeetAuthService();
  final _localService = LocalService();
  late final _planningRepository = PlanningRepository(
    localService: _localService,
  );
  late final ClassroomDashboardCubit _cubit;
  bool _ownsCubit = false;

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

  Map<String, dynamic>? get _activeRoom => _cubit.state.activeRoom;
  List<dynamic> get _historyList => _cubit.state.historyList;
  int get _selectedTabIndex => _cubit.state.selectedTabIndex;
  String get _selectedRoomFilter => _cubit.state.selectedRoomFilter;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else {
      _cubit = ClassroomDashboardCubit(
        localService: _localService,
        planningRepository: _planningRepository,
      );
      _ownsCubit = true;
    }
    _cubit.loadAll();
  }

  @override
  void didUpdateWidget(covariant ClassroomDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cubit != null && widget.cubit != oldWidget.cubit) {
      if (_ownsCubit) {
        _cubit.close();
        _ownsCubit = false;
      }
      _cubit = widget.cubit!;
    }
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  Future<void> _loadRoomsAndHistory() => _cubit.loadRoomsAndHistory();
  Future<void> _loadPlannings() => _cubit.loadPlannings();

  Future<void> _handleCreateNewPlanning() async {
    final result = await CreatePlanningDialog.show(
      context,
      subjectOptions: _subjectOptions,
    );
    if (result == null || !mounted) return;

    final newPlan = await _cubit.createPlanning(
      title: result.title,
      subject: result.subject,
    );

    if (!mounted) return;
    if (newPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cubit.state.errorMessage ??
                'Không thể tạo kế hoạch bài giảng. Vui lòng thử lại.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudioScreen(
          isPlanningMode: true,
          planningId: newPlan.id,
          lessonTitle: result.title,
        ),
      ),
    );
    _cubit.loadPlannings();
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
    final confirm = await showAppModalDialog<bool>(
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
      await _cubit.deletePlanning(plan.id);
    }
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required IconData icon,
    int? badgeCount,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Semantics(
      button: true,
      selected: isSelected,
      label: badgeCount != null && badgeCount > 0
          ? '$title, $badgeCount mục'
          : title,
      child: AppPressable(
        scaleDown: 0.98,
        onTap: () => _cubit.setTabIndex(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
        duration: AppMotion.duration(context, milliseconds: 200),
        curve: AppMotion.easeOut,
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
    if (MeetPermissionPrompt.navigatorKey.currentState == null && mounted) {
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

    return BlocProvider<ClassroomDashboardCubit>.value(
      value: _cubit,
      child: BlocListener<ClassroomDashboardCubit, ClassroomDashboardState>(
        listenWhen: (prev, current) =>
            current.errorMessage != null &&
            current.errorMessage != prev.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
            _cubit.clearError();
          }
        },
        child: Scaffold(
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
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const HocLucBrandMark(size: 34),
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
                            icon: const Icon(
                              Icons.assignment_outlined,
                              size: 20,
                            ),
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
                                      primary: true,
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
                                    primary: true,
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

                            // Tab Bar & Tab Content Area
                            BlocBuilder<
                              ClassroomDashboardCubit,
                              ClassroomDashboardState
                            >(
                              builder: (context, state) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Tab Bar: 3 Horizontal Tabs
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          _buildTabButton(
                                            index: 0,
                                            title: 'Phòng học',
                                            icon: Icons.meeting_room_outlined,
                                            badgeCount: state.activeRoom != null
                                                ? 1
                                                : null,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          _buildTabButton(
                                            index: 1,
                                            title: 'Kế hoạch bài giảng',
                                            icon: Icons.menu_book_outlined,
                                            badgeCount:
                                                state.plannings.isNotEmpty
                                                ? state.plannings.length
                                                : null,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          _buildTabButton(
                                            index: 2,
                                            title: 'Lịch sử',
                                            icon: Icons.history_rounded,
                                            badgeCount:
                                                state.historyList.isNotEmpty
                                                ? state.historyList.length
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
                                          key: ValueKey(state.selectedTabIndex),
                                          child: state.selectedTabIndex == 0
                                              ? _buildRoomListCard()
                                              : state.selectedTabIndex == 1
                                              ? PlanningListCard(
                                                  plannings: state.plannings,
                                                  isLoading:
                                                      state.loadingPlannings,
                                                  selectedSubject: state
                                                      .selectedSubjectFilter,
                                                  subjectOptions:
                                                      _subjectOptions,
                                                  onSubjectChanged: (val) {
                                                    if (val != null) {
                                                      _cubit.setSubjectFilter(
                                                        val,
                                                      );
                                                    }
                                                  },
                                                  onCreateNew:
                                                      _handleCreateNewPlanning,
                                                  onEdit: _handleEditPlanning,
                                                  onLaunch:
                                                      _handleLaunchFromPlanning,
                                                  onDelete:
                                                      _handleDeletePlanning,
                                                )
                                              : _buildHistoryCard(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
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
        ),
      ),
    );
  }
}
