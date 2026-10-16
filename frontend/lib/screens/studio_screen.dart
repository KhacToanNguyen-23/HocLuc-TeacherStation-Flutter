import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/camera_broadcast_service.dart';
import '../services/teacher_media_service.dart';
import '../constants/theme.dart';
import '../models/studio_state.dart';
import '../screens/classroom_dashboard_screen.dart';
import 'google_workspace_screen.dart';
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
import '../models/teaching_target.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    this.initialState,
    this.lessonTitle,
    this.meetingUrl,
    this.isPlanningMode = false,
    this.planningId,
    this.teachingTarget,
    this.initialSessionId,
  });

  final StudioState? initialState;
  final String? lessonTitle;
  final String? meetingUrl;
  final bool isPlanningMode;
  final String? planningId;
  final TeachingTarget? teachingTarget;
  final String? initialSessionId;

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
  bool _openingRoom = false,
      _recordingSession = false,
      _sessionRecorded = false;
  String? _sessionId, _sessionError;
  final _sessionApi = LocalService();

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
    if (widget.teachingTarget == null &&
        widget.meetingUrl != null &&
        widget.meetingUrl!.trim().isNotEmpty) {
      MeetAutomationService().setMeetingUrl(widget.meetingUrl!.trim());
    }

    studio.addListener(syncControllers);
    if (widget.teachingTarget != null) {
      _sessionId = widget.initialSessionId;
      MeetAutomationService().addListener(_onMeetChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openTeachingRoom());
      });
    }
  }

  Future<void> _openTeachingRoom() async {
    if (_openingRoom || !mounted) return;
    final target = widget.teachingTarget!;
    final meet = MeetAutomationService();
    setState(() {
      _openingRoom = true;
      _sessionError = null;
    });
    try {
      meet.linkedTeacherEmail = target.isLinked ? target.teacherEmail : null;
      meet.showEmbeddedMeet = true;
      final url = await meet.generateAndJoinRealMeetRoom(
        existingUrl: target.meetingUrl,
        autoJoin: target.isOneOff,
      );
      if (url == null) {
        throw StateError(
          'Chưa mở được Meet. Thử lại ngay tại đây; phòng liên kết sẽ được giữ nguyên.',
        );
      }
      if (!mounted) return;
      _onMeetChanged();
    } catch (e) {
      if (mounted) {
        setState(
          () => _sessionError = e.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _openingRoom = false);
    }
  }

  void _onMeetChanged() {
    if (!mounted || widget.teachingTarget == null) return;
    final meet = MeetAutomationService();
    if (!meet.isHostJoined ||
        _sessionRecorded ||
        _recordingSession ||
        _sessionError != null) {
      return;
    }
    final expected = widget.teachingTarget!.meetingUrl;
    if (expected != null && meet.meetingUrl != expected) return;
    _queueSessionRegistration();
  }

  void _queueSessionRegistration() {
    if (_recordingSession || _sessionRecorded) return;
    final meet = MeetAutomationService();
    final pending = _recordTeachingSession();
    meet.pendingSessionRegistration = pending;
    unawaited(
      pending.whenComplete(() {
        if (identical(meet.pendingSessionRegistration, pending)) {
          meet.pendingSessionRegistration = null;
        }
      }),
    );
  }

  Future<void> _recordTeachingSession() async {
    if (_recordingSession || _sessionRecorded || !mounted) return;
    final meet = MeetAutomationService();
    final url = meet.meetingUrl;
    if (!meet.isHostJoined || url == null) return;
    setState(() {
      _recordingSession = true;
      _sessionError = null;
    });
    try {
      final result = await _sessionApi.post(
        'classroom/create',
        data: {
          'directUrl': url,
          'title': widget.lessonTitle ?? widget.teachingTarget!.title,
        },
      );
      if (result['success'] != true) {
        throw StateError('Chưa ghi nhận được buổi dạy.');
      }
      if (!mounted) return;
      setState(() {
        _sessionId = result['id'] as String?;
        _sessionRecorded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _sessionError = e.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _recordingSession = false);
    }
  }

  Widget _teachingStatus() => ListenableBuilder(
    listenable: MeetAutomationService(),
    builder: (context, _) {
      final meet = MeetAutomationService();
      final text =
          _sessionError ??
          (_openingRoom
              ? 'Đang mở phòng học…'
              : _sessionRecorded
              ? 'Đang dạy · ${widget.teachingTarget!.title}'
              : _recordingSession
              ? 'Đang ghi nhận buổi học…'
              : meet.isHostJoined
              ? 'Meet đã tham gia · chưa ghi nhận buổi học'
              : 'Chuẩn bị · kiểm tra tài khoản, mic/camera và bấm Tham gia trong Meet');
      final statusColor = _sessionError != null
          ? AppColors.error
          : _sessionRecorded
          ? AppColors.success
          : AppColors.onSelected;
      return Container(
        color: _sessionError != null
            ? AppColors.errorSurface
            : _sessionRecorded
            ? AppColors.successSurface
            : AppColors.selected,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(
              _sessionRecorded
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 18,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
            ),
            if (widget.teachingTarget!.teacherEmail != null &&
                MediaQuery.sizeOf(context).width > 900)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  widget.teachingTarget!.teacherEmail!,
                  style: TextStyle(fontSize: 11, color: statusColor),
                ),
              ),
            if (_sessionError != null)
              TextButton(
                onPressed: _openingRoom || _recordingSession
                    ? null
                    : () {
                        if (meet.isHostJoined) {
                          _queueSessionRegistration();
                        } else {
                          unawaited(_openTeachingRoom());
                        }
                      },
                child: const Text('Thử lại'),
              ),
          ],
        ),
      );
    },
  );

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
    MeetAutomationService().removeListener(_onMeetChanged);
    _sessionApi.dispose();
    if (widget.teachingTarget == null) {
      unawaited(CameraBroadcastService().stop());
      unawaited(TeacherMediaService().shutdown());
    }
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
              backgroundColor: success ? AppColors.success : AppColors.error,
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
            borderRadius: BorderRadius.circular(AppRadii.panel),
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
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: const Text(
                'Không lưu',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('save'),
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
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
    await save();
    if (!mounted) return;
    final id = _currentPlanningId ?? widget.planningId;
    if (id == null || studio.dirty) {
      message('Lưu bài giảng trước khi chọn lớp để dạy.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            GoogleWorkspaceScreen(planningId: id, lessonTitle: studio.title),
      ),
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
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
              color: AppColors.textPrimary,
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
                  border: Border.all(color: AppColors.border),
                  color: AppColors.sky50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.teachingTarget == null
                            ? 'Về trang chủ, giữ kết nối Meet'
                            : 'Về danh sách lớp (giữ buổi học)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
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
                  border: Border.all(color: AppColors.error),
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.stop_circle_outlined,
                      color: AppColors.error,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kết thúc buổi học',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
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
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (action == 'pause' && mounted) {
      if (widget.teachingTarget != null) {
        await MeetAutomationService().stopBroadcast();
        if (mounted) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const ClassroomDashboardScreen()),
          );
        }
        return;
      }
      await MeetAutomationService().pauseSession();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ClassroomDashboardScreen()),
          (route) => false,
        );
      }
    } else if (action == 'end' && mounted) {
      if (widget.teachingTarget != null && _recordingSession) {
        message('Đang ghi nhận buổi học. Vui lòng thử lại sau.');
        return;
      }
      final local = LocalService();
      try {
        final active = await local.getActiveClassroom(strict: true);
        if (active['status'] == 'ONGOING') {
          if (!await local.endClassroom(
            classroomId: _sessionId ?? active['id'] as String?,
          )) {
            message('Chưa kết thúc được buổi học. Vui lòng thử lại.');
            return;
          }
        }
      } catch (_) {
        message('Không kết nối được backend để kết thúc buổi học.');
        return;
      } finally {
        local.dispose();
      }
      await MeetAutomationService().leaveClassroom();
      await TeacherMediaService().shutdown();
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
        canPop:
            widget.teachingTarget == null &&
            (!widget.isPlanningMode || !studio.dirty),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && widget.isPlanningMode) {
            _handleExitPlanning();
          } else if (!didPop && widget.teachingTarget != null) {
            _handleLeaveClassroom();
          }
        },
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): save,
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): save,
            const SingleActivator(LogicalKeyboardKey.escape): () {
              setState(() => showInspector = false);
            },
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: LayoutBuilder(
                builder: (context, box) {
                  final hasInspector = showInspector && box.maxWidth >= 1250;
                  final panelVisible =
                      hasInspector ||
                      showStudentsDrawer ||
                      showPluginsMarketplace;
                  final panelKind = showPluginsMarketplace
                      ? 'plugins'
                      : showStudentsDrawer
                      ? 'students'
                      : 'inspector';
                  final panelWidth = box.maxWidth < 440
                      ? box.maxWidth - 64
                      : widget.teachingTarget != null
                      ? 380.0
                      : 320.0;
                  final Widget rightPanel = panelVisible
                      ? Material(
                          key: ValueKey('studio-panel-$panelKind'),
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.12),
                          child: Container(
                            width: panelWidth,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                left: BorderSide(color: AppColors.line),
                              ),
                            ),
                            child: showPluginsMarketplace
                                ? StudioPluginsMarketplacePanel(
                                    onClose: () => setState(
                                      () => showPluginsMarketplace = false,
                                    ),
                                  )
                                : showStudentsDrawer
                                ? StudioStudentsDrawer(
                                    meetService: MeetAutomationService(),
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
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('studio-panel-hidden'),
                        );

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
                      if (widget.teachingTarget != null) _teachingStatus(),
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
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              child: AnimatedSwitcher(
                                duration: AppMotion.duration(
                                  context,
                                  milliseconds: 220,
                                ),
                                switchInCurve: AppMotion.enterCurve,
                                switchOutCurve: AppMotion.exitCurve,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0.06, 0),
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
                                layoutBuilder: (currentChild, previousChildren) =>
                                    Stack(
                                      alignment: Alignment.centerRight,
                                      clipBehavior: Clip.none,
                                      children: [
                                        ...previousChildren,
                                        ?currentChild,
                                      ],
                                    ),
                                child: rightPanel,
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
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.panel,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Container(
                                      width: 340,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.panel,
                                        ),
                                        border: Border.all(
                                          color: AppColors.border,
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
                                            color: AppColors.background,
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
