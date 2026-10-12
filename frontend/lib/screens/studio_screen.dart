import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/studio_state.dart';
import '../screens/classroom_dashboard_screen.dart';
import '../services/local_service.dart';
import '../services/meet_automation_service.dart';
import '../widgets/stage_container.dart';
import '../widgets/studio/studio_admission_banner.dart';
import '../widgets/studio/studio_drawing_toolbar.dart';
import '../widgets/studio/studio_inspector_panel.dart';
import '../widgets/studio/studio_lessons_drawer.dart';
import '../widgets/studio/studio_preview_dialog.dart';
import '../widgets/studio/studio_question_view.dart';
import '../widgets/studio/studio_rename_dialog.dart';
import '../widgets/studio/studio_student_strip.dart';
import '../widgets/studio/studio_students_drawer.dart';
import '../widgets/studio/studio_top_bar.dart';
import '../services/plugin_manager.dart';
import '../widgets/studio/studio_plugins_marketplace_panel.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    this.initialState,
    this.lessonTitle,
    this.meetingUrl,
  });

  final StudioState? initialState;
  final String? lessonTitle;
  final String? meetingUrl;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  late final StudioState studio;
  final notes = TextEditingController();
  final question = TextEditingController();
  final endpoint = TextEditingController();
  bool initializedControllers = false;
  bool showLessons = false;
  bool showInspector = false;
  bool showStudentsDrawer = false;
  bool showPluginsMarketplace = false;

  @override
  void initState() {
    super.initState();
    PluginManager().init();
    studio = widget.initialState ?? StudioState();
    if (widget.initialState == null) studio.initialize();

    if (widget.lessonTitle != null && widget.lessonTitle!.trim().isNotEmpty) {
      studio.title = widget.lessonTitle!.trim();
    }
    if (widget.meetingUrl != null && widget.meetingUrl!.trim().isNotEmpty) {
      MeetAutomationService().setMeetingUrl(widget.meetingUrl!.trim());
    }

    studio.addListener(syncControllers);
  }

  void syncControllers() {
    if (!studio.loading && !initializedControllers) {
      notes.text = studio.notes;
      question.text = studio.question;
      endpoint.text = studio.endpoint;
      initializedControllers = true;
    }
  }

  @override
  void dispose() {
    studio.removeListener(syncControllers);
    studio.dispose();
    notes.dispose();
    question.dispose();
    endpoint.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> save() async {
    final success = await studio.save();
    if (mounted) {
      message(
        success
            ? 'Đã lưu bài giảng và cấu hình trên máy.'
            : 'Không lưu được. Kiểm tra dịch vụ Java rồi thử lại.',
      );
    }
  }

  void preview() => StudioPreviewDialog.show(context, studio);

  Future<void> rename() async {
    final result = await StudioRenameDialog.show(context, studio.title);
    if (result != null && result.isNotEmpty) {
      studio.change(() => studio.title = result);
    }
  }

  Future<void> _handleLeaveClassroom() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        title: const Row(
          children: [
            Icon(Icons.meeting_room_outlined, color: AppColors.slate900, size: 22),
            SizedBox(width: 10),
            Text('Rời khỏi lớp học', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => Navigator.of(ctx).pop('pause'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.pause_circle_outline_rounded, color: AppColors.sky600, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tạm rời phòng',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => Navigator.of(ctx).pop('end'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFECDD3)),
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stop_circle_outlined, color: AppColors.rose600, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kết thúc buổi học',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.rose600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Ở lại tiếp tục dạy', style: TextStyle(color: AppColors.slate600, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (action == 'pause' && mounted) {
      await MeetAutomationService().pauseSession();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ClassroomDashboardScreen()),
          (route) => false,
        );
      }
    } else if (action == 'end' && mounted) {
      await LocalService().endClassroom();
      await MeetAutomationService().leaveClassroom();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ClassroomDashboardScreen()),
          (route) => false,
        );
      }
    }
  }

  void openInspector() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SizedBox(
      height: 520,
      child: StudioInspectorPanel(
        studio: studio,
        notesController: notes,
        questionController: question,
        endpointController: endpoint,
        onPreview: preview,
      ),
    ),
  );

  void openLessons() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SizedBox(
      height: 380,
      child: Material(
        color: Colors.white,
        child: StudioLessonsDrawer(
          studio: studio,
          onClose: () => Navigator.pop(context),
          onPluginMessage: message,
        ),
      ),
    ),
  );

  Widget fittedStage({bool interactive = true}) {
    if (studio.view == 'question') {
      return StudioQuestionView(studio: studio);
    }
    return StageContainer(studio: studio, interactive: interactive);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: studio,
    builder: (context, _) {
      return Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final hasInspector = showInspector && box.maxWidth >= 1250;
            final hasLessons = showLessons && box.maxWidth >= 1000;

            return Column(
              children: [
                StudioTopBar(
                  studio: studio,
                  width: box.maxWidth,
                  hasLessons: hasLessons,
                  hasInspector: hasInspector,
                  onToggleLessons: () {
                    if (box.maxWidth < 1000) {
                      openLessons();
                    } else {
                      setState(() => showLessons = !showLessons);
                    }
                  },
                  onToggleInspector: () {
                    if (box.maxWidth < 1250) {
                      openInspector();
                    } else {
                      setState(() => showInspector = !showInspector);
                    }
                  },
                  onToggleStudents: () {
                    setState(() => showStudentsDrawer = !showStudentsDrawer);
                  },
                  onLeaveClassroom: _handleLeaveClassroom,
                  onRename: rename,
                  onPreview: preview,
                  onSave: save,
                  onRetryConnect: () {
                    initializedControllers = false;
                    studio.initialize();
                  },
                ),
                // Horizontal Student Gallery Strip (Zoom style)
                StudioStudentStrip(
                  meetService: MeetAutomationService(),
                  onOpenStudentsDrawer: () {
                    setState(() => showStudentsDrawer = true);
                  },
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          if (hasLessons)
                            SizedBox(
                              width: 200,
                              child: StudioLessonsDrawer(
                                studio: studio,
                                onClose: () => setState(() => showLessons = false),
                                onPluginMessage: message,
                                onOpenPluginsMarketplace: () => setState(() => showPluginsMarketplace = true),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                                    child: fittedStage(),
                                  ),
                                ),
                                if (studio.view == 'board')
                                  StudioDrawingToolbar(studio: studio),
                              ],
                            ),
                          ),
                          if (hasInspector)
                            SizedBox(
                              width: 304,
                              child: StudioInspectorPanel(
                                studio: studio,
                                notesController: notes,
                                questionController: question,
                                endpointController: endpoint,
                                onPreview: preview,
                              ),
                            ),
                          if (showStudentsDrawer)
                            StudioStudentsDrawer(
                              meetService: MeetAutomationService(),
                              onClose: () => setState(() => showStudentsDrawer = false),
                            ),
                          if (showPluginsMarketplace)
                            StudioPluginsMarketplacePanel(
                              onClose: () => setState(() => showPluginsMarketplace = false),
                            ),
                        ],
                      ),
                      // Floating student admission alert toast
                      StudioAdmissionBanner(meetService: MeetAutomationService()),
                      // Floating active plugin window
                      ListenableBuilder(
                        listenable: PluginManager(),
                        builder: (context, _) {
                          final active = PluginManager().activePlugin;
                          if (active == null) return const SizedBox.shrink();

                          return Positioned(
                            top: 50,
                            right: 40,
                            child: Material(
                              elevation: 12,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: Container(
                                width: 340,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      color: const Color(0xFFF8FAFC),
                                      child: Row(
                                        children: [
                                          Icon(active.icon, size: 16, color: active.color),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              active.name,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => PluginManager().closeActivePlugin(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: active.buildWidget(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
