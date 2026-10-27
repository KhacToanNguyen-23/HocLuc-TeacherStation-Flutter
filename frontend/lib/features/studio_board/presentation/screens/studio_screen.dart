import 'package:teaching_companion/core/utils/frontend_logger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/features/studio_board/presentation/scoped_listenable_builder.dart';
import 'package:teaching_companion/features/classroom_meet/services/classroom_settings_service.dart';
import 'package:teaching_companion/features/studio_board/presentation/stage_container.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_drawing_toolbar.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_inspector_panel.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_speaker_notes_bar.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_preview_dialog.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_question_view.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_rename_dialog.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_students_drawer.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_top_bar.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_plugins_marketplace_panel.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/save_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/services/planning_repository.dart';
import 'package:teaching_companion/features/auth/presentation/google_webview_login_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/select_classroom_dialog.dart';

part 'studio_screen_actions.dart';

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
  bool showInspectorModal = false;
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
    final classroomSettings = ClassroomSettingsService.instance;
    await classroomSettings.load();
    if (!mounted) return;
    if (studio.showCameraPip != classroomSettings.autoCamera) {
      studio.toggleCameraPip();
    }
    setState(() {
      _openingRoom = true;
      _sessionError = null;
    });
    try {
      meet.linkedTeacherEmail = target.isLinked ? target.teacherEmail : null;
      meet.showEmbeddedMeet = true;
      var url = await meet.generateAndJoinRealMeetRoom(
        existingUrl: target.meetingUrl,
        autoJoin: true,
      );
      if (url == null && meet.needsGoogleLogin && mounted) {
        final loginResult = await GoogleWebviewLoginDialog.show(context);
        if (loginResult != null && mounted) {
          url = await meet.generateAndJoinRealMeetRoom(
            existingUrl: target.meetingUrl,
            autoJoin: true,
          );
        }
      }
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

  Future<Map<String, dynamic>?> _ensureTeachingSessionRecorded() async {
    final meet = MeetAutomationService();
    await meet.pendingSessionRegistration;

    final candidateUrl =
        widget.teachingTarget?.meetingUrl ??
        widget.meetingUrl ??
        meet.meetingUrl;
    final knownUrl = candidateUrl?.trim().isEmpty == true
        ? null
        : candidateUrl?.trim();
    final active = await _sessionApi.getActiveClassroom(strict: true);
    if (active['status'] == 'ONGOING' &&
        (knownUrl == null || active['meetingUrl'] == knownUrl)) {
      final id = active['id'] as String?;
      if (id == null || id.isEmpty) {
        throw StateError('Buổi học đang mở nhưng thiếu mã phiên.');
      }
      if (mounted) {
        setState(() {
          _sessionId = id;
          _sessionRecorded = true;
          _sessionError = null;
        });
      }
      return active;
    }
    if (active['status'] == 'ONGOING') {
      throw StateError('Đang có một buổi học khác mở trên hệ thống.');
    }
    if (knownUrl == null) {
      if (widget.teachingTarget != null) {
        throw StateError(
          'Không xác định được đường dẫn Meet để ghi nhận buổi học.',
        );
      }
      return null;
    }

    final result = await _sessionApi.post(
      'classroom/create',
      data: {
        'directUrl': knownUrl,
        'title':
            widget.lessonTitle ?? widget.teachingTarget?.title ?? studio.title,
      },
    );
    if (result['success'] != true ||
        result['status'] != 'ONGOING' ||
        result['id'] is! String) {
      throw StateError(
        result['error']?.toString() ?? 'Chưa ghi nhận được buổi học.',
      );
    }
    if (mounted) {
      setState(() {
        _sessionId = result['id'] as String;
        _sessionRecorded = true;
        _sessionError = null;
      });
    }
    return result;
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
      final id = result['id'] as String?;
      if (!mounted) return;
      setState(() {
        _sessionId = id;
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
      final content =
          await PlanningRepository(localService: studio.service)
              .getPlanningContent(id);
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
      FrontendLogger.write('[StudioScreen] Failed to load planning: $e');
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

  @override
  Widget build(BuildContext context) =>
      ScopedListenableBuilder<({bool dirty, String view})>(
    // The screen shell only depends on the dirty flag (back navigation guard)
    // and the active view. Stage, toolbar, notes and panels subscribe to the
    // studio themselves, so pen/laser/PDF/audio updates no longer rebuild the
    // whole screen.
    listenable: studio,
    selector: () => (dirty: studio.dirty, view: studio.view),
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
            const SingleActivator(LogicalKeyboardKey.f5): preview,
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
                            ),
                            child: showPluginsMarketplace
                                ? StudioPluginsMarketplacePanel(
                                    onClose: () => setState(
                                      () => showPluginsMarketplace = false,
                                    ),
                                    onOpenPlugin: (plugin) {
                                      if (plugin is InstalledPlugin) {
                                        studio.openPlugin(
                                          plugin,
                                          openModal:
                                              plugin.manifest.uiPlacement !=
                                              'floating_window',
                                        );
                                        setState(
                                          () => showPluginsMarketplace = false,
                                        );
                                      }
                                    },
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

                        hasInspector: hasInspector || showInspectorModal,
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
                                if (studio.view != 'question')
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
                                    child: Column(
                                      children: [
                                        Expanded(child: fittedStage()),
                                        if (studio.view == 'board' &&
                                            studio.showSpeakerNotes) ...[
                                          const SizedBox(height: 4),
                                          StudioSpeakerNotesBar(
                                            studio: studio,
                                          ),
                                        ],
                                      ],
                                    ),
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
                                  final slide =
                                      Tween<Offset>(
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
                                layoutBuilder:
                                    (currentChild, previousChildren) => Stack(
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
