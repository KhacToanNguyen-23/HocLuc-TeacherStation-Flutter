import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/features/auth/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';

part 'select_classroom_sections.dart';

/// Dialog to select a class before launching teaching from a prepared lesson plan.
class SelectClassroomDialog extends StatefulWidget {
  const SelectClassroomDialog({
    super.key,
    required this.plan,
    this.googleApi,
    this.onLaunch,
  });

  final PlanningMeta plan;
  final GoogleWorkspaceApi? googleApi;
  final Future<void> Function(TeachingTarget)? onLaunch;

  static final RegExp _meetCodeRegex = RegExp(
    r'(?:https?:\/\/)?(?:meet\.google\.com\/)?([a-z]{3}-[a-z]{4}-[a-z]{3})',
    caseSensitive: false,
  );

  static bool isRealGoogleMeetUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return _meetCodeRegex.hasMatch(url.trim());
  }

  static String? extractRealGoogleMeetUrl(String? text) {
    if (text == null) return null;
    final match = _meetCodeRegex.firstMatch(text.trim());
    if (match != null) {
      return 'https://meet.google.com/${match.group(1)!.toLowerCase()}';
    }
    return null;
  }

  static Future<void> show(
    BuildContext context, {
    required PlanningMeta plan,
    GoogleWorkspaceApi? googleApi,
    Future<void> Function(TeachingTarget)? onLaunch,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SelectClassroomDialog(
        plan: plan,
        googleApi: googleApi,
        onLaunch: onLaunch,
      ),
    );
  }

  @override
  State<SelectClassroomDialog> createState() => _SelectClassroomDialogState();
}

enum _ClassSourceType { googleCourse, presetClass, customClass }

class _SelectClassroomDialogState extends State<SelectClassroomDialog> {
  final _authService = GoogleMeetAuthService();
  final _customClassController = TextEditingController();
  final _meetUrlController = TextEditingController();

  _ClassSourceType _sourceType = _ClassSourceType.presetClass;
  String _selectedPreset = '12A1';
  Map<String, dynamic>? _selectedGoogleCourse;

  List<Map<String, dynamic>> _googleCourses = [];
  bool _loadingCourses = false;
  bool _isLaunching = false;
  String? _errorMessage;

  final List<String> _presetClasses = const [
    '12A1',
    '12A2',
    '12A3',
    '11A1',
    '11A2',
    '10A1',
    '10A2',
  ];

  @override
  void initState() {
    super.initState();
    _loadGoogleCourses();
  }

  @override
  void dispose() {
    _customClassController.dispose();
    _meetUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadGoogleCourses() async {
    final email = _authService.teacherEmail;
    if (email == null || email.isEmpty) return;

    setState(() => _loadingCourses = true);
    final api = widget.googleApi ?? GoogleWorkspaceApi(email: email);
    try {
      final status = await api.call('status');
      if (!mounted) return;
      if (status['connected'] == true) {
        final result = await api.call('courses');
        if (!mounted) return;
        final list = (result['courses'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        setState(() {
          _googleCourses = list;
          if (list.isNotEmpty) {
            _sourceType = _ClassSourceType.googleCourse;
            _selectedGoogleCourse = list.first;
          }
        });
      }
    } catch (_) {
      // Offline or Google service not connected - keep preset class default
    } finally {
      if (widget.googleApi == null) api.close();
      if (mounted) setState(() => _loadingCourses = false);
    }
  }

  Color _getSubjectColor(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('anh') || lower.contains('english')) {
      return AppColors.primary;
    } else if (lower.contains('toán') || lower.contains('math')) {
      return AppColors.warning;
    } else if (lower.contains('văn') || lower.contains('việt')) {
      return AppColors.success;
    } else if (lower.contains('lý') ||
        lower.contains('hóa') ||
        lower.contains('sinh')) {
      return const Color(0xFF7C3AED);
    }
    return AppColors.textSecondary;
  }

  Color _getSubjectBg(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('anh') || lower.contains('english')) {
      return AppColors.sky50;
    } else if (lower.contains('toán') || lower.contains('math')) {
      return AppColors.warningSurface;
    } else if (lower.contains('văn') || lower.contains('việt')) {
      return AppColors.successSurface;
    } else if (lower.contains('lý') ||
        lower.contains('hóa') ||
        lower.contains('sinh')) {
      return const Color(0xFFF5F3FF);
    }
    return AppColors.surfaceMuted;
  }

  String _getTargetClassName() {
    switch (_sourceType) {
      case _ClassSourceType.googleCourse:
        return _selectedGoogleCourse?['title'] as String? ?? 'Lớp Google Meet';
      case _ClassSourceType.presetClass:
        return 'Lớp $_selectedPreset';
      case _ClassSourceType.customClass:
        final text = _customClassController.text.trim();
        return text.isNotEmpty ? text : 'Lớp học';
    }
  }

  Future<void> _handleConfirm() async {
    final className = _getTargetClassName();
    if (_sourceType == _ClassSourceType.customClass &&
        _customClassController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tên lớp học.');
      return;
    }

    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    try {
      TeachingTarget target;
      if (_sourceType == _ClassSourceType.googleCourse &&
          _selectedGoogleCourse != null) {
        final course = _selectedGoogleCourse!;
        final email = _authService.teacherEmail ?? '';
        String? meetingUrl = course['meetingUrl'] as String?;

        // If course doesn't have meetingUrl yet, trigger start on Google with polling
        if (meetingUrl == null || meetingUrl.isEmpty) {
          final api = widget.googleApi ?? GoogleWorkspaceApi(email: email);
          try {
            final startReq = GoogleWorkspaceApi.requestId();
            for (var attempt = 0; attempt < 10; attempt++) {
              final ready = await api.call(
                'courses/${course['id']}/start',
                post: true,
                body: {'requestId': startReq},
              );
              if (ready['calendarStatus'] == 'READY' &&
                  ready['meetingUrl'] is String &&
                  (ready['meetingUrl'] as String).isNotEmpty) {
                meetingUrl = ready['meetingUrl'] as String;
                break;
              }
              if (!{'PENDING', 'CREATING'}.contains(ready['calendarStatus']) ||
                  attempt >= 9) {
                final warnings = (ready['warnings'] as List? ?? []).join('\n');
                throw StateError(
                  warnings.isEmpty
                      ? 'Chưa chuẩn bị xong phòng Meet. Vui lòng thử lại.'
                      : warnings,
                );
              }
              await Future<void>.delayed(const Duration(seconds: 1));
            }
          } finally {
            if (widget.googleApi == null) api.close();
          }
        }

        target = TeachingTarget(
          title: '$className · ${widget.plan.title}',
          meetingUrl: meetingUrl,
          courseId: course['id'] as String?,
          teacherEmail: email.isNotEmpty ? email : null,
          planningId: widget.plan.id,
        );
      } else {
        final rawMeetUrl = _meetUrlController.text.trim();
        String? meetingUrl;
        if (rawMeetUrl.isNotEmpty) {
          final extracted = SelectClassroomDialog.extractRealGoogleMeetUrl(
            rawMeetUrl,
          );
          if (extracted == null) {
            setState(() {
              _isLaunching = false;
              _errorMessage =
                  'Link Google Meet không hợp lệ (cần dạng https://meet.google.com/xxx-yyyy-zzz).';
            });
            return;
          }
          meetingUrl = extracted;
        }

        target = TeachingTarget(
          title: '$className · ${widget.plan.title}',
          meetingUrl: meetingUrl,
          planningId: widget.plan.id,
        );
      }

      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();

      if (widget.onLaunch != null) {
        await widget.onLaunch!(target);
      } else {
        if (!context.mounted) return;
        await TeachingLauncher.open(context, target);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLaunching = false;
          _errorMessage = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slate = AppColors.textPrimary;
    final sky = AppColors.primary;
    final subColor = _getSubjectColor(widget.plan.subject);
    final subBg = _getSubjectBg(widget.plan.subject);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            _buildDialogHeader(
              slate: slate,
              sky: sky,
              subColor: subColor,
              subBg: subBg,
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // 2. Class Selection Body
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGoogleCoursesSection(slate: slate, sky: sky),
                    _buildPresetClassesSection(sky: sky),
                    _buildCustomClassSection(sky: sky),
                    _buildSummaryAndErrorBanners(sky: sky),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Actions
            _buildDialogActions(sky: sky),
          ],
        ),
      ),
    );
  }
}


