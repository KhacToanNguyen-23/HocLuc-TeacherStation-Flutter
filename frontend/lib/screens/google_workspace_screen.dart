import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/google_meet_auth_service.dart';
import '../services/google_workspace_api.dart';
import '../services/google_connection_flow.dart';
import '../models/teaching_target.dart';
import '../services/teaching_launcher.dart';
import '../services/meet_automation_service.dart';
import '../widgets/workspace/workspace_connection_panel.dart';
import '../widgets/workspace/workspace_invite_dialog.dart';
import '../widgets/workspace/workspace_schedule_dialog.dart';
import '../widgets/workspace/workspace_course_detail.dart';
import '../widgets/google_brand_icon.dart';

class GoogleWorkspaceScreen extends StatefulWidget {
  const GoogleWorkspaceScreen({
    super.key,
    this.api,
    this.planningId,
    this.lessonTitle,
    this.launchLesson,
  });
  final GoogleWorkspaceApi? api;
  final String? planningId, lessonTitle;
  final Future<void> Function(Map<String, dynamic>)? launchLesson;
  @override
  State<GoogleWorkspaceScreen> createState() => _GoogleWorkspaceScreenState();
}

class _GoogleWorkspaceScreenState extends State<GoogleWorkspaceScreen>
    with WidgetsBindingObserver {
  late GoogleWorkspaceApi _api;
  final _auth = GoogleMeetAuthService();
  Map<String, dynamic> _connection = {};
  List<Map<String, dynamic>> _courses = [];
  String? _selected, _error;
  bool _busy = true, _polling = false;
  final Map<String, String> _startRequests = {};
  final Set<String> _syncingClassrooms = {};
  final Map<String, String> _classroomSyncErrors = {};
  String? _pendingClassroomCourseId;
  bool _resumeRetryQueued = false;
  String? _startingCourse;
  int _connectGeneration = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? GoogleWorkspaceApi(email: _auth.teacherEmail ?? '');
    _auth.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  void _accountChanged() {
    if ((_auth.teacherEmail ?? '').toLowerCase() != _api.email.toLowerCase() ||
        !_auth.isSignedIn) {
      _connectGeneration++;
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _connectGeneration++;
    _auth.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final connection = await _api.call('status');
      if (!mounted) return;
      setState(() => _connection = connection);
      var courses = <Map<String, dynamic>>[];
      if (connection['connected'] == true) {
        final result = await _api.call('courses');
        courses = (result['courses'] as List).cast<Map<String, dynamic>>();
      }
      if (!mounted) return;
      setState(() {
        _connection = connection;
        _courses = courses;
        _error = connection['message'] as String?;
        if (!courses.any((c) => c['id'] == _selected)) {
          _selected = courses.isEmpty ? null : courses.first['id'] as String;
        }
      });
      final trackedPendingCourse = _courseById(_pendingClassroomCourseId);
      if (trackedPendingCourse == null ||
          !_needsClassroomSync(trackedPendingCourse)) {
        _pendingClassroomCourseId = null;
      }
      final selectedCourse = _courseById(_selected);
      if (selectedCourse != null && _needsClassroomSync(selectedCourse)) {
        _rememberPendingCourse(selectedCourse);
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _message(Object e) => e is FormatException
      ? e.message
      : e.toString().replaceFirst('Bad state: ', '');

  void _handleError(Object e) {
    if (!mounted) return;
    setState(() {
      _error = _message(e);
      if (e is GoogleWorkspaceFailure && e.needsConsent) {
        _connection = {
          ..._connection,
          'connected': false,
          'state': 'REAUTH_REQUIRED',
          'message': _error,
        };
        _courses = [];
        _selected = null;
      }
    });
  }

  void _replace(Map<String, dynamic> course) {
    _rememberPendingCourse(course);
    final id = course['id'];
    if (id is String) _classroomSyncErrors.remove(id);
    setState(() {
      _courses = [
        for (final c in _courses)
          if (c['id'] == course['id']) course else c,
      ];
      _selected = course['id'] as String;
      _error = null;
    });
  }

  Map<String, dynamic>? _courseById(String? id) {
    if (id == null) return null;
    for (final course in _courses) {
      if (course['id'] == id) return course;
    }
    return null;
  }

  void _rememberPendingCourse(Map<String, dynamic> course) {
    final id = course['id'];
    if (id is! String) return;
    if (_needsClassroomSync(course)) {
      _pendingClassroomCourseId = id;
    } else if (_pendingClassroomCourseId == id) {
      _pendingClassroomCourseId = null;
    }
  }

  bool _needsClassroomSync(Map<String, dynamic> course) {
    final courseId = course['courseId'];
    if (courseId is! String || courseId.isEmpty) return false;
    if (course['classroomState'] == 'PROVISIONED') return true;
    final classroomSyncedAt = course['classroomSyncedAt'];
    final hasClassroomSync =
        classroomSyncedAt is String && classroomSyncedAt.isNotEmpty;
    return course['classroomState'] == 'ACTIVE' && !hasClassroomSync;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final courseId = _pendingClassroomCourseId;
    if (courseId == null || courseId != _selected) return;
    final course = _courseById(courseId);
    if (course == null || !_needsClassroomSync(course)) return;
    if (_syncingClassrooms.contains(courseId)) return;
    if (_busy) {
      _resumeRetryQueued = true;
      return;
    }
    unawaited(_syncClassroomCourse(courseId));
  }

  void _retryQueuedResume() {
    if (!mounted || !_resumeRetryQueued || _busy) return;
    _resumeRetryQueued = false;
    final courseId = _pendingClassroomCourseId;
    if (courseId == null || courseId != _selected) return;
    final course = _courseById(courseId);
    if (course == null ||
        !_needsClassroomSync(course) ||
        _syncingClassrooms.contains(courseId)) {
      return;
    }
    unawaited(_syncClassroomCourse(courseId));
  }

  Future<void> _syncClassroomCourse(String courseId) async {
    if (!_syncingClassrooms.add(courseId)) return;
    if (mounted) {
      setState(() => _classroomSyncErrors.remove(courseId));
    }
    try {
      await _run(() async {
        try {
          final course = await _api.call('courses/$courseId/sync', post: true);
          if (!mounted) return;
          _replace(course);
        } catch (e) {
          if (!mounted) return;
          if (e is GoogleWorkspaceFailure && e.needsConsent) {
            _handleError(e);
          } else {
            setState(() => _classroomSyncErrors[courseId] = _message(e));
          }
        }
      });
    } finally {
      _syncingClassrooms.remove(courseId);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _retryQueuedResume();
      }
    }
  }

  Future<void> _connect({
    bool repair = false,
    bool changeAccount = false,
  }) async {
    await _run(() async {
      if (changeAccount) await TeachingLauncher.requireIdleForAccountChange();
      final generation = ++_connectGeneration;
      setState(() => _polling = true);
      try {
        final email = await GoogleConnectionFlow.connect(
          _api,
          context: context,
          forceConsent: repair,
          isActive: () => mounted && generation == _connectGeneration,
        );
        if (!mounted || generation != _connectGeneration) return;
        if (email.toLowerCase() != _api.email.toLowerCase()) {
          await TeachingLauncher.requireIdleForAccountChange();
          if (!mounted || generation != _connectGeneration) return;
          await MeetAutomationService().leaveClassroom();
        }
        _auth.removeListener(_accountChanged);
        try {
          if (widget.api == null) {
            _api.close();
            _api = GoogleWorkspaceApi(email: email);
          }
          await _auth.signInWithGoogleConnection(email);
          _connection = {
            'configured': true,
            'connected': false,
            'state': 'CHECKING',
          };
          _courses = [];
          _selected = null;
        } finally {
          if (mounted) _auth.addListener(_accountChanged);
        }
        await _load();
      } finally {
        if (mounted) setState(() => _polling = false);
      }
    });
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ngắt kết nối Google?'),
        content: const Text(
          'HocLucStation sẽ thu hồi quyền truy cập Classroom, Meet và Calendar của tài khoản này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ngắt kết nối'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await TeachingLauncher.requireIdleForAccountChange();
      await _api.call('disconnect', post: true);
      await _load();
    });
  }

  Future<void> _setMeetAccess(
    Map<String, dynamic> course,
    Map<String, dynamic> student,
  ) async {
    final allowed = student['meetAllowed'] != true;
    if (!allowed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gỡ quyền Meet của học sinh?'),
          content: Text(
            'Học sinh ${student['email']} sẽ không được tự động duyệt vào phòng Meet của lớp này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gỡ quyền'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _run(() async {
      final result = await _api.call(
        'courses/${course['id']}/access',
        post: true,
        body: {'email': student['email'], 'allowed': allowed},
      );
      _replace(result);
    });
  }

  Future<void> _editClass({Map<String, dynamic>? course}) async {
    await WorkspaceInviteDialog.show(
      context,
      api: _api,
      course: course,
      onSuccess: _replace,
    );
    if (mounted) await _load();
  }

  Future<void> _schedule(
    Map<String, dynamic> course, {
    bool now = false,
  }) async {
    if (TeachingLauncher.hasStudio || MeetAutomationService().hasRoom) {
      _handleError(
        StateError(
          'Lưu bài và kết thúc buổi đang mở trước khi tạo phòng Calendar mới.',
        ),
      );
      return;
    }
    DateTime? selectedDate;
    if (now) {
      selectedDate = DateTime.now().add(const Duration(minutes: 1));
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 730)),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time == null || !mounted) return;
      selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!selectedDate.isAfter(DateTime.now())) {
        setState(() => _error = 'Chọn thời gian học trong tương lai.');
        return;
      }
    }

    await WorkspaceScheduleDialog.show(
      context,
      api: _api,
      course: course,
      start: selectedDate,
      isNow: now,
      onSuccess: _replace,
    );
    if (mounted) await _load();
  }

  Future<void> _start(Map<String, dynamic> course) async {
    if (TeachingLauncher.hasStudio &&
        MeetAutomationService().meetingUrl == course['meetingUrl']) {
      TeachingLauncher.returnToStudio();
      return;
    }
    await _run(() async {
      final id = course['id'] as String;
      final request = _startRequests.putIfAbsent(
        id,
        GoogleWorkspaceApi.requestId,
      );
      setState(() => _startingCourse = id);
      late Map<String, dynamic> ready;
      try {
        for (var attempt = 0; ; attempt++) {
          ready = await _api.call(
            'courses/$id/start',
            post: true,
            body: {'requestId': request},
          );
          if (!mounted) return;
          _replace(ready);
          if (ready['calendarStatus'] == 'READY' &&
              ready['meetingUrl'] is String) {
            break;
          }
          if (!{'PENDING', 'CREATING'}.contains(ready['calendarStatus']) ||
              attempt >= 9) {
            final warnings = (ready['warnings'] as List? ?? []).join('\n');
            throw StateError(
              warnings.isEmpty
                  ? 'Chưa chuẩn bị xong phòng. Bấm Thử lại để tiếp tục buổi này.'
                  : warnings,
            );
          }
          await Future<void>.delayed(const Duration(seconds: 2));
          if (!mounted) return;
        }
      } on GoogleWorkspaceFailure catch (e) {
        if (e.code == 'START_REQUEST_FINISHED') _startRequests.remove(id);
        rethrow;
      } finally {
        if (mounted) setState(() => _startingCourse = null);
      }
      _replace(ready);
      if (!mounted) return;
      if (widget.launchLesson != null) {
        await widget.launchLesson!(ready);
        _startRequests.remove(id);
        return;
      }
      await TeachingLauncher.open(
        context,
        TeachingTarget(
          title: widget.lessonTitle ?? ready['title'] as String,
          meetingUrl: ready['meetingUrl'] as String,
          courseId: ready['id'] as String,
          teacherEmail: _api.email,
          planningId: widget.planningId,
        ),
      );
      _startRequests.remove(id);
    });
  }

  Future<void> _oneOff() async {
    await _run(() async {
      await TeachingLauncher.open(
        context,
        TeachingTarget(
          title: widget.lessonTitle ?? 'Buổi học riêng',
          planningId: widget.planningId,
        ),
      );
    });
  }

  Widget _notice(String text, {bool error = false}) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xfffff1ed) : const Color(0xffe8f4f3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline : Icons.info_outline,
          size: 20,
          color: error ? AppColors.error : AppColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: AppColors.surfaceBorder),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final connected = _connection['connected'] == true;
    final disabled = _busy || _polling;
    final selected = _courses.where((c) => c['id'] == _selected).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            GoogleBrandIcon(size: 20),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Lớp học & kết nối Google',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: disabled ? null : _oneOff,
            icon: const Icon(Icons.video_call_outlined),
            label: const Text('Dạy buổi lẻ'),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: disabled ? null : () => _run(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null) _notice(_error!, error: true),
                    if (_error != null && TeachingLauncher.hasStudio)
                      TextButton(
                        onPressed: TeachingLauncher.returnToStudio,
                        child: const Text('Trở về buổi dạy để lưu và kết thúc'),
                      ),
                    WorkspaceConnectionPanel(
                      connection: _connection,
                      email: _api.email,
                      disabled: disabled,
                      polling: _polling,
                      onConnect: () {
                        final retry =
                            _connection['state'] == 'TEMPORARY_ERROR' ||
                            _connection['state'] == 'CONFIG_ERROR';
                        if (connected || retry) {
                          _run(_load);
                        } else {
                          _connect(
                            repair: _connection['state'] == 'REAUTH_REQUIRED',
                          );
                        }
                      },
                      onChangeAccount: () => _connect(changeAccount: true),
                      onDisconnect: _disconnect,
                      onCancelPolling: () {
                        _connectGeneration++;
                        setState(() => _polling = false);
                      },
                    ),
                    if (connected) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Lớp học của bạn',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: disabled ? null : _editClass,
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo lớp học'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_courses.isEmpty)
                        _panel(
                          child: const Text(
                            'Chưa có lớp liên kết. Tạo lớp để mời học sinh và chuẩn bị phòng học.',
                          ),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _courses
                            .map(
                              (course) => ChoiceChip(
                                selected: _selected == course['id'],
                                label: Text(
                                  course['title'] as String? ?? 'Lớp học',
                                ),
                                onSelected: disabled
                                    ? null
                                    : (_) {
                                        final id = course['id'] as String;
                                        setState(() => _selected = id);
                                        final selectedCourse = _courseById(id);
                                        if (selectedCourse != null &&
                                            _needsClassroomSync(
                                              selectedCourse,
                                            )) {
                                          _rememberPendingCourse(
                                            selectedCourse,
                                          );
                                        }
                                      },
                              ),
                            )
                            .toList(),
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 20),
                        WorkspaceCourseDetail(
                          course: selected,
                          classroomSyncing: _syncingClassrooms.contains(
                            selected['id'],
                          ),
                          classroomSyncError:
                              _classroomSyncErrors[selected['id']],
                          disabled: disabled,
                          startingCourseId: _startingCourse,
                          hasStartRequest: _startRequests.containsKey(
                            selected['id'],
                          ),
                          onCompleteClass: () => _run(() async {
                            _replace(
                              await _api.call(
                                'courses',
                                post: true,
                                body: {
                                  'requestId': selected['id'],
                                  'title': selected['title'],
                                  'description': selected['description'] ?? '',
                                  'emails':
                                      selected['intendedEmails'] ?? <String>[],
                                },
                              ),
                            );
                          }),
                          onStartClass: () => _start(selected),
                          onAddStudents: () => _editClass(course: selected),
                          onSync: () =>
                              _syncClassroomCourse(selected['id'] as String),
                          onSchedule: () => _schedule(selected),
                          onSetMeetAccess: _setMeetAccess,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
