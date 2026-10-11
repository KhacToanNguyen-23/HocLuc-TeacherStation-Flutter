import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/studio_state.dart';
import '../screens/classroom_dashboard_screen.dart';
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

  @override
  void initState() {
    super.initState();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.rose600),
            SizedBox(width: 8),
            Text('Rời khỏi lớp học?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn kết thúc buổi giảng dạy này và quay lại Dashboard?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kết thúc & Rời phòng'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
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
                        ],
                      ),
                      // Floating student admission alert toast
                      StudioAdmissionBanner(meetService: MeetAutomationService()),
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
