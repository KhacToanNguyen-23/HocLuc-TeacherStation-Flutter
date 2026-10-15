import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../services/google_meet_auth_service.dart';
import '../services/google_workspace_api.dart';
import '../services/google_connection_flow.dart';
import '../services/url_opener.dart';
import '../models/teaching_target.dart';
import '../services/teaching_launcher.dart';
import '../services/meet_automation_service.dart';

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

class _GoogleWorkspaceScreenState extends State<GoogleWorkspaceScreen> {
  late GoogleWorkspaceApi _api;
  final _auth = GoogleMeetAuthService();
  Map<String, dynamic> _connection = {};
  List<Map<String, dynamic>> _courses = [];
  String? _selected, _error;
  bool _busy = true, _polling = false;
  final Map<String, String> _startRequests = {};
  String? _startingCourse;
  int _connectGeneration = 0;
  static const _teal = Color(0xff087f83);

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? GoogleWorkspaceApi(email: _auth.teacherEmail ?? '');
    _auth.addListener(_accountChanged);
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
        };
        _courses = [];
        _selected = null;
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _polling) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
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
          'HocLuc sẽ thu hồi quyền kết nối. Lớp và lịch đã tạo trên Google vẫn được giữ lại.',
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

  void _replace(Map<String, dynamic> course) {
    if (!mounted) return;
    setState(() {
      _selected = course['id'] as String;
      _courses = [..._courses.where((c) => c['id'] != course['id']), course];
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
          title: const Text('Gỡ quyền vào Meet?'),
          content: Text(
            'Gỡ ${student['email']} khỏi danh sách mời của buổi Calendar hiện tại hoặc membership cũ do HocLuc quản lý. Không đuổi người đang trong cuộc gọi và không xóa học sinh khỏi Classroom.',
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

  Widget _meetAccessAction(
    Map<String, dynamic> course,
    Map<String, dynamic> student,
    bool disabled,
  ) => TextButton(
    onPressed: disabled ? null : () => _setMeetAccess(course, student),
    child: Text(
      student['meetAllowed'] == true ? 'Gỡ quyền Meet' : 'Cấp quyền Meet',
    ),
  );

  Future<void> _editClass({Map<String, dynamic>? course}) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final emails = TextEditingController();
    final form = GlobalKey<FormState>();
    final requestId = GoogleWorkspaceApi.requestId();
    bool saving = false;
    String? error;
    final dialogRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(course == null ? 'Tạo lớp học' : 'Mời học sinh'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (course == null) ...[
                        TextFormField(
                          controller: title,
                          enabled: !saving,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            labelText: 'Tên lớp',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nhập tên lớp.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: description,
                          enabled: !saving,
                          maxLength: 2000,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả lớp (không bắt buộc)',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: emails,
                        enabled: !saving,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Email học sinh',
                          hintText: 'Mỗi dòng một email, tối đa 50 email',
                        ),
                        validator: (v) {
                          try {
                            final parsed = GoogleWorkspaceApi.parseEmails(
                              v ?? '',
                            );
                            return parsed.isEmpty
                                ? 'Nhập ít nhất một email.'
                                : null;
                          } catch (e) {
                            return _message(e);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Thêm email vào danh sách lớp. Chuẩn bị phòng Calendar để gửi lời mời Meet; không cần học sinh chấp nhận Classroom.',
                        style: TextStyle(
                          color: AppColors.slate600,
                          height: 1.5,
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (saving)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final result = await _api.call(
                            course == null
                                ? 'courses'
                                : 'courses/${course['id']}/invite',
                            post: true,
                            body: {
                              if (course == null) ...{
                                'requestId': requestId,
                                'title': title.text.trim(),
                                'description': description.text.trim(),
                              },
                              'emails': GoogleWorkspaceApi.parseEmails(
                                emails.text,
                              ),
                            },
                          );
                          _replace(result);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            update(() {
                              error = _message(e);
                              saving = false;
                            });
                          }
                        }
                      },
                child: Text(
                  course == null ? 'Tạo lớp và mời học sinh' : 'Gửi lời mời',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context).push(dialogRoute);
    await dialogRoute.completed;
    title.dispose();
    description.dispose();
    emails.dispose();
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
    final start = selectedDate;
    final requestId = GoogleWorkspaceApi.requestId();
    final duration = TextEditingController(text: '90');
    bool saving = false;
    String? error;
    final dialogRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              now ? 'Chuẩn bị phòng Calendar' : 'Lên lịch và tạo phòng Meet',
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${course['title']} · ${_date(start.toIso8601String())}',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: duration,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Thời lượng (phút)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tạo một buổi Calendar có phòng Meet mới và gửi lời mời tới các email đã chọn trong lớp. Link cũ sẽ được thay bằng link buổi này. Thời gian theo múi giờ máy của bạn.',
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final minutes = int.tryParse(duration.text);
                        if (minutes == null || minutes < 1 || minutes > 1440) {
                          update(() => error = 'Thời lượng từ 1–1440 phút.');
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final result = await _api.call(
                            'courses/${course['id']}/schedule',
                            post: true,
                            body: {
                              'requestId': requestId,
                              'start': start.toUtc().toIso8601String(),
                              'end': start
                                  .add(Duration(minutes: minutes))
                                  .toUtc()
                                  .toIso8601String(),
                            },
                          );
                          _replace(result);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            update(() {
                              error = _message(e);
                              saving = false;
                            });
                          }
                        }
                      },
                child: const Text('Tạo phòng và gửi lời mời'),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context).push(dialogRoute);
    await dialogRoute.completed;
    duration.dispose();
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

  @override
  Widget build(BuildContext context) {
    final connected = _connection['connected'] == true;
    final needsConsent = _connection['state'] == 'REAUTH_REQUIRED';
    final retryConnection =
        _connection['state'] == 'TEMPORARY_ERROR' ||
        _connection['state'] == 'CONFIG_ERROR';
    final disabled = _busy || _polling;
    final selected = _courses.where((c) => c['id'] == _selected).firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Lớp học & kết nối Google'),
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
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(
                                Icons.hub_outlined,
                                color: _teal,
                                size: 32,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    connected
                                        ? 'Google đã kết nối'
                                        : needsConsent
                                        ? 'Google cần cấp quyền lại'
                                        : retryConnection
                                        ? 'Chưa kiểm tra được kết nối'
                                        : 'Kết nối Google',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    _api.email.isEmpty
                                        ? 'Chọn tài khoản Google để sử dụng HocLuc.'
                                        : _api.email,
                                  ),
                                ],
                              ),
                              if (!_polling)
                                FilledButton.icon(
                                  onPressed:
                                      disabled ||
                                          _connection['configured'] != true
                                      ? null
                                      : connected || retryConnection
                                      ? () => _run(_load)
                                      : () => _connect(repair: needsConsent),
                                  icon: const Icon(Icons.link),
                                  label: Text(
                                    connected
                                        ? 'Kiểm tra kết nối'
                                        : needsConsent
                                        ? 'Cấp quyền lại'
                                        : retryConnection
                                        ? 'Thử lại'
                                        : 'Kết nối Google',
                                  ),
                                ),
                              if (!_polling &&
                                  _connection['configured'] == true)
                                TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () => _connect(changeAccount: true),
                                  child: const Text('Đổi tài khoản'),
                                ),
                              if (connected && !_polling)
                                TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () => _connect(repair: true),
                                  child: const Text('Cấp quyền lại'),
                                ),
                              if (_api.email.isNotEmpty &&
                                  _connection['state'] != 'DISCONNECTED' &&
                                  _connection['configured'] == true)
                                TextButton(
                                  onPressed: disabled ? null : _disconnect,
                                  child: const Text('Ngắt kết nối'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Đăng xuất HocLuc giữ quyền đã cấp. Ngắt kết nối Google sẽ thu hồi quyền API của tài khoản này.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate600,
                            ),
                          ),
                          const Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              Chip(
                                avatar: Icon(Icons.school_outlined, size: 18),
                                label: Text('Classroom · Lớp và thành viên'),
                              ),
                              Chip(
                                avatar: Icon(Icons.videocam_outlined, size: 18),
                                label: Text('Meet · Phòng học'),
                              ),
                              Chip(
                                avatar: Icon(Icons.event_outlined, size: 18),
                                label: Text('Calendar · Lịch và lời mời'),
                              ),
                            ],
                          ),
                          if (_connection['configured'] == false)
                            _notice(
                              'Ứng dụng chưa được cấu hình kết nối Google. Người cài đặt HocLuc cần hoàn tất cấu hình; giáo viên không cần tạo Client ID.',
                            ),
                          if (_polling)
                            Row(
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Chọn tài khoản và cấp quyền trong trình duyệt, rồi trở về HocLuc.',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _connectGeneration++;
                                    setState(() => _polling = false);
                                  },
                                  child: const Text('Hủy'),
                                ),
                              ],
                            ),
                          if (!connected && !_polling)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                '1. Chọn tài khoản Google   →   2. Đồng ý cấp quyền   →   3. Tạo lớp trong HocLuc',
                                style: TextStyle(color: AppColors.slate600),
                              ),
                            ),
                        ],
                      ),
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
                                    : (_) => setState(
                                        () =>
                                            _selected = course['id'] as String,
                                      ),
                              ),
                            )
                            .toList(),
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 20),
                        _classDetail(selected, disabled),
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

  Widget _classDetail(Map<String, dynamic> course, bool disabled) {
    final students = (course['students'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final joined = students
        .where((s) => s['classroomStatus'] == 'JOINED')
        .length;
    final warnings = [
      ...(course['warnings'] as List? ?? []),
      ...(course['classroomWarnings'] as List? ?? []),
    ].cast<String>();
    final events = (course['events'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course['title'] as String,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$joined đã tham gia · ${students.where((s) => s['classroomStatus'] == 'INVITED').length} chờ chấp nhận · ${students.length} trong danh sách',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (course['courseId'] == null)
                    FilledButton.icon(
                      onPressed: disabled
                          ? null
                          : () => _run(() async {
                              _replace(
                                await _api.call(
                                  'courses',
                                  post: true,
                                  body: {
                                    'requestId': course['id'],
                                    'title': course['title'],
                                    'description': course['description'] ?? '',
                                    'emails':
                                        course['intendedEmails'] ?? <String>[],
                                  },
                                ),
                              );
                            }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Hoàn tất tạo lớp'),
                    ),
                  FilledButton.icon(
                    onPressed: disabled ? null : () => _start(course),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      _startingCourse == course['id']
                          ? 'Đang chuẩn bị phòng…'
                          : TeachingLauncher.hasStudio &&
                                MeetAutomationService().meetingUrl ==
                                    course['meetingUrl']
                          ? 'Tiếp tục dạy'
                          : _startRequests.containsKey(course['id'])
                          ? 'Thử lại'
                          : 'Bắt đầu dạy',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: disabled
                        ? null
                        : () => _editClass(course: course),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Thêm email học sinh'),
                  ),
                  PopupMenuButton<String>(
                    enabled: !disabled,
                    tooltip: 'Thao tác khác',
                    onSelected: (_) => _run(
                      () async => _replace(
                        await _api.call(
                          'courses/${course['id']}/sync',
                          post: true,
                        ),
                      ),
                    ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'sync',
                        child: Text('Đồng bộ'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz),
                  ),
                  OutlinedButton.icon(
                    onPressed: disabled ? null : () => _schedule(course),
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Lên lịch học'),
                  ),
                  if (course['classroomUrl'] case final String url
                      when url.isNotEmpty)
                    TextButton(
                      onPressed: () => openExternalUrl(url),
                      child: const Text('Mở Classroom'),
                    ),
                  if (course['meetingUrl'] case final String url
                      when url.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép link Meet.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Sao chép link Meet'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course['syncedAt'] == null
                    ? 'Chưa đồng bộ thành viên.'
                    : 'Đồng bộ gần nhất: ${_date(course['syncedAt'] as String)}',
                style: const TextStyle(color: AppColors.slate500),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nhập email học sinh một lần, sau đó bấm Bắt đầu dạy. HocLuc tự chuẩn bị phòng và gửi lời mời cho buổi học. Học sinh dùng link của buổi này và đúng email được mời.',
                style: TextStyle(color: AppColors.slate600),
              ),
            ],
          ),
        ),
        for (final warning in warnings) _notice(warning, error: true),
        if (course['accessNotice'] != null)
          _notice(course['accessNotice'] as String),
        const SizedBox(height: 16),
        _panel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1000) {
                return Column(
                  children: students
                      .map(
                        (student) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'] as String? ??
                                    student['email'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(student['email'] as String),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _status(
                                    student['classroomStatus'] as String? ?? '',
                                  ),
                                  _status(
                                    student['meetStatus'] as String? ?? '',
                                  ),
                                ],
                              ),
                              _meetAccessAction(course, student, disabled),
                              if (student['classroomError'] != null)
                                Text('Classroom: ${student['classroomError']}'),
                              if (student['error'] != null)
                                Text(
                                  student['error'] as String,
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              }
              return SizedBox(
                width: double.infinity,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Học sinh / Email')),
                    DataColumn(label: Text('Classroom')),
                    DataColumn(label: Text('Quyền vào Meet')),
                    DataColumn(label: Text('Thao tác')),
                  ],
                  rows: students
                      .map(
                        (s) => DataRow(
                          cells: [
                            DataCell(
                              Tooltip(
                                message:
                                    s['error'] as String? ??
                                    s['email'] as String,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['name'] as String? ??
                                          s['email'] as String,
                                    ),
                                    Text(
                                      s['email'] as String,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              _status(s['classroomStatus'] as String? ?? ''),
                            ),
                            DataCell(_status(s['meetStatus'] as String? ?? '')),
                            DataCell(_meetAccessAction(course, s, disabled)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 20),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Các buổi Calendar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                for (final event in events.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_available_outlined,
                      color: _teal,
                    ),
                    title: Text(_date(event['start'] as String)),
                    subtitle: Text(
                      'Đã yêu cầu Google gửi lịch cho ${event['inviteeCount']} học sinh',
                    ),
                    trailing: event['url'] == null || event['url'] == ''
                        ? null
                        : IconButton(
                            tooltip: 'Mở lịch Google',
                            onPressed: () =>
                                openExternalUrl(event['url'] as String),
                            icon: const Icon(Icons.open_in_new),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _status(String status) {
    const labels = {
      'JOINED': 'Đã tham gia',
      'INVITED': 'Chờ chấp nhận',
      'INVITE_FAILED': 'Mời thất bại',
      'NOT_INVITED': 'Chưa mời',
      'LEFT': 'Đã rời lớp',
      'INVITATION_CLOSED': 'Lời mời đã đóng',
      'GRANTED': 'Đã lưu membership',
      'CALENDAR_INVITED': 'Có trong lời mời Calendar',
      'VERIFYING': 'Đang xác nhận',
      'VERIFY_FAILED': 'Chưa xác nhận quyền',
      'EXTERNAL_ACCESS': 'Quyền ngoài HocLuc',
      'NOT_GRANTED': 'Chưa cấp quyền',
      'GRANT_FAILED': 'Cấp quyền thất bại',
      'REVOKE_FAILED': 'Chưa gỡ được quyền',
    };
    final success = status == 'JOINED' || status == 'GRANTED';
    final failed = status.endsWith('FAILED');
    final color = success
        ? _teal
        : failed
        ? Colors.red.shade700
        : AppColors.slate600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        labels[status] ?? 'Chưa xác định',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.slate200),
    ),
    child: child,
  );
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
          color: error ? Colors.red.shade700 : _teal,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
  static String _date(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }
}
