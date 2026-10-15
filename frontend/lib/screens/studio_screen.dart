import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/camera_broadcast_service.dart';
import '../services/teacher_media_service.dart';
import '../constants/theme.dart';
import '../models/studio_state.dart';
import '../screens/classroom_dashboard_screen.dart';
import '../screens/classroom_lobby_screen.dart';
import '../services/local_service.dart';
import '../services/meet_automation_service.dart';
import '../widgets/stage_container.dart';
import '../widgets/studio/studio_drawing_toolbar.dart';
import '../widgets/studio/studio_inspector_panel.dart';
import '../widgets/studio/studio_preview_dialog.dart';
import '../widgets/studio/studio_question_view.dart';
import '../widgets/studio/studio_rename_dialog.dart';
import '../widgets/studio/studio_students_drawer.dart';
import '../widgets/studio/studio_top_bar.dart';
import '../services/plugin_manager.dart';
import '../widgets/studio/studio_plugins_marketplace_panel.dart';
import '../widgets/studio/save_classroom_dialog.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    this.initialState,
    this.lessonTitle,
    this.meetingUrl,
    this.isPlanningMode = false,
    this.planningId,
  });

  final StudioState? initialState;
  final String? lessonTitle;
  final String? meetingUrl;
  final bool isPlanningMode;
  final String? planningId;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  late final StudioState studio;
  final notes = TextEditingController();
  final question = TextEditingController();
  final endpoint = TextEditingController();
  bool initializedControllers = false;
  bool showInspector = false;
  bool showStudentsDrawer = false;
  bool showPluginsMarketplace = false;
  String? _currentPlanningId;

  @override
  void initState() {
    super.initState();
    _currentPlanningId = widget.planningId;
    PluginManager().init();
    studio = widget.initialState ?? StudioState();
    if (widget.initialState == null) {
      if (widget.isPlanningMode && widget.planningId != null) {
        _loadPlanning(widget.planningId!);
      } else {
        studio.initialize();
      }
    }

    if (widget.lessonTitle != null && widget.lessonTitle!.trim().isNotEmpty) {
      studio.title = widget.lessonTitle!.trim();
    }
    if (widget.meetingUrl != null && widget.meetingUrl!.trim().isNotEmpty) {
      MeetAutomationService().setMeetingUrl(widget.meetingUrl!.trim());
    }

    studio.addListener(syncControllers);
  }

  Future<void> _loadPlanning(String id) async {
    try {
      _currentPlanningId = id;
      await studio.service.connect();
      final content = await studio.service.getPlanningContent(id);
      if (content != null) {
        studio.change(() {
          studio.restoreFromJson(content);
          if (widget.lessonTitle != null &&
              widget.lessonTitle!.trim().isNotEmpty) {
            studio.title = widget.lessonTitle!.trim();
          }
          studio.online = true;
          studio.loading = false;
          studio.dirty = false;
        }, persist: false);
        syncControllers();
        return;
      }
    } catch (e) {
      debugPrint('[StudioScreen] Failed to load planning: $e');
    }
    studio.initialize();
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
    unawaited(CameraBroadcastService().stop());
    unawaited(TeacherMediaService().shutdown());
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
    if (widget.isPlanningMode) {
      if (studio.saving) return;
      studio.change(() => studio.saving = true, persist: false);
      String? errorMessage;
      try {
        final lessonSnapshot = studio.exportLessonJson();
        final targetId = _currentPlanningId ?? widget.planningId;
        debugPrint(
          '[StudioScreen] Starting save planning: title="${studio.title}", targetId=$targetId, pdf=${studio.pdfFilePath}, page=${studio.pdfPage}',
        );

        bool success = false;
        if (targetId != null) {
          final res = await studio.service.updatePlanning(
            id: targetId,
            title: studio.title,
            subject: studio.subject,
            content: lessonSnapshot,
          );
          success = res != null;
          if (!success) {
            errorMessage = 'Backend từ chối cập nhật bài giảng "$targetId"';
          }
        } else {
          final res = await studio.service.createPlanning(
            title: studio.title,
            subject: studio.subject,
            content: lessonSnapshot,
          );
          success = res != null;
          if (res != null) {
            _currentPlanningId = res.id;
            debugPrint('[StudioScreen] Saved new planning with id: ${res.id}');
          } else {
            errorMessage = 'Backend từ chối tạo bài giảng mới';
          }
        }
        studio.change(() {
          studio.dirty = !success;
          if (success) {
            final now = DateTime.now();
            studio.savedAt =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          }
        }, persist: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    success
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      success
                          ? 'Đã lưu kế hoạch bài giảng "${studio.title}" thành công.'
                          : 'Không lưu được bài giảng: ${errorMessage ?? 'Kiểm tra terminal log'}.',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: success
                  ? const Color(0xFF15803D)
                  : const Color(0xFFDC2626),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e, st) {
        debugPrint('[StudioScreen] Save planning exception: $e\n$st');
        if (mounted) message('Lỗi khi lưu bài giảng: $e');
      } finally {
        studio.change(() => studio.saving = false, persist: false);
      }
      return;
    }

    // Chế độ phòng học (Live Classroom Mode): Hiển thị lựa chọn lưu Slide và file PDF
    SaveClassroomDialog.show(
      context,
      studio: studio,
      onSaveSlide: () async => await studio.save(),
    );
  }

  Future<void> _handleExitPlanning() async {
    if (studio.dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Thoát chế độ soạn bài?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Bạn có thay đổi chưa lưu trên bảng vẽ bài giảng. Bạn có muốn lưu trước khi thoát không?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.slate600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: const Text(
                'Không lưu',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sky600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu & Thoát'),
            ),
          ],
        ),
      );

      if (choice == 'cancel' || choice == null) return;
      if (choice == 'save') {
        await save();
        if (studio.dirty) return;
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleCreateClassroomFromPlanning() async {
    if (studio.dirty) {
      await save();
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.videocam_rounded, size: 20, color: AppColors.sky600),
            SizedBox(width: 8),
            Text(
              'Tạo phòng học từ bài giảng?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Hệ thống sẽ nhân bản nội dung bài giảng "${studio.title}" sang một phòng học trực tuyến mới để bạn bắt đầu dạy ngay.\n\nBài giảng kế hoạch gốc vẫn sẽ được giữ nguyên vẹn.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.slate600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sky600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tạo & Bắt đầu dạy'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                  'Đang nhân bản bài giảng & tạo phòng học...',
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
      final planId = _currentPlanningId ?? widget.planningId;
      if (planId != null) {
        await studio.service.clonePlanningToClassroom(planId);
      }
      realMeetUrl = await MeetAutomationService().generateAndJoinRealMeetRoom();
    } catch (e) {
      debugPrint('[StudioScreen] Error launching classroom from planning: $e');
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (mounted) {
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => ClassroomLobbyScreen(
            initialMeetingUrl: realMeetUrl,
            initialLessonTitle: studio.title,
          ),
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        title: const Row(
          children: [
            Icon(
              Icons.meeting_room_outlined,
              color: AppColors.slate900,
              size: 22,
            ),
            SizedBox(width: 10),
            Text(
              'Rời khỏi lớp học',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.pause_circle_outline_rounded,
                      color: AppColors.sky600,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Về trang chủ, giữ kết nối Meet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate900,
                        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFECDD3)),
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.stop_circle_outlined,
                      color: AppColors.rose600,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kết thúc buổi học',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.rose600,
                        ),
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
            child: const Text(
              'Ở lại tiếp tục dạy',
              style: TextStyle(
                color: AppColors.slate600,
                fontWeight: FontWeight.w600,
              ),
            ),
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

  Widget fittedStage({bool interactive = true}) {
    if (studio.view == 'question') {
      return StudioQuestionView(studio: studio, interactive: interactive);
    }
    return StageContainer(studio: studio, interactive: interactive);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: studio,
    builder: (context, _) {
      return PopScope(
        canPop: !widget.isPlanningMode || !studio.dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && widget.isPlanningMode) {
            _handleExitPlanning();
          }
        },
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): save,
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): save,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: LayoutBuilder(
                builder: (context, box) {
                  final hasInspector = showInspector && box.maxWidth >= 1250;

                  return Column(
                    children: [
                      StudioTopBar(
                        studio: studio,
                        width: box.maxWidth,
                        hasInspector: hasInspector,
                        hasStudents: showStudentsDrawer,
                        hasPlugins: showPluginsMarketplace,
                        isPlanningMode: widget.isPlanningMode,
                        onExitPlanning: _handleExitPlanning,
                        onCreateClassroomFromPlanning:
                            _handleCreateClassroomFromPlanning,
                        onToggleInspector: () {
                          if (box.maxWidth < 1250) {
                            openInspector();
                          } else {
                            setState(() {
                              showInspector = !showInspector;
                              if (showInspector) {
                                showStudentsDrawer = false;
                                showPluginsMarketplace = false;
                              }
                            });
                          }
                        },
                        onToggleStudents: () {
                          setState(() {
                            showStudentsDrawer = !showStudentsDrawer;
                            if (showStudentsDrawer) {
                              showInspector = false;
                              showPluginsMarketplace = false;
                            }
                          });
                        },
                        onTogglePlugins: () {
                          setState(() {
                            showPluginsMarketplace = !showPluginsMarketplace;
                            if (showPluginsMarketplace) {
                              showInspector = false;
                              showStudentsDrawer = false;
                            }
                          });
                        },
                        onLeaveClassroom: widget.isPlanningMode
                            ? null
                            : _handleLeaveClassroom,
                        onRename: rename,
                        onPreview: preview,
                        onSave: save,
                        onRetryConnect: () {
                          initializedControllers = false;
                          studio.initialize();
                        },
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                if (studio.view == 'board')
                                  StudioDrawingToolbar(
                                    studio: studio,
                                    isVertical: true,
                                  ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      4,
                                      10,
                                      4,
                                    ),
                                    child: fittedStage(),
                                  ),
                                ),
                              ],
                            ),
                            // OVERLAY RIGHT PANELS (Hover đè lên mép phải màn hình, KHÔNG MỜ NỀN, KHÔNG BÓP UI)
                            if (hasInspector ||
                                showStudentsDrawer ||
                                showPluginsMarketplace)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                right: 0,
                                child: Material(
                                  elevation: 16,
                                  shadowColor: Colors.black.withValues(
                                    alpha: 0.35,
                                  ),
                                  child: Container(
                                    width: 320,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        left: BorderSide(color: AppColors.line),
                                      ),
                                    ),
                                    child: showPluginsMarketplace
                                        ? StudioPluginsMarketplacePanel(
                                            onClose: () => setState(
                                              () => showPluginsMarketplace =
                                                  false,
                                            ),
                                          )
                                        : showStudentsDrawer
                                        ? StudioStudentsDrawer(
                                            meetService:
                                                MeetAutomationService(),
                                            onClose: () => setState(
                                              () => showStudentsDrawer = false,
                                            ),
                                          )
                                        : StudioInspectorPanel(
                                            studio: studio,
                                            notesController: notes,
                                            questionController: question,
                                            endpointController: endpoint,
                                            onPreview: preview,
                                          ),
                                  ),
                                ),
                              ),
                            // Floating active plugin window
                            ListenableBuilder(
                              listenable: PluginManager(),
                              builder: (context, _) {
                                final active = PluginManager().activePlugin;
                                if (active == null) {
                                  return const SizedBox.shrink();
                                }

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
                                        border: Border.all(
                                          color: AppColors.slate200,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            color: const Color(0xFFF8FAFC),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  active.icon,
                                                  size: 16,
                                                  color: active.color,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    active.name,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.close_rounded,
                                                    size: 18,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: () =>
                                                      PluginManager()
                                                          .closeActivePlugin(),
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
            ),
          ),
        ),
      );
    },
  );
}
