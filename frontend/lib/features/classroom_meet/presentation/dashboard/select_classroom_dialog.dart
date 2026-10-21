import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';
import '../widgets/preparation_class_confirmation.dart';
part '../widgets/select_classroom_binding.dart';

/// Dialog to select a class before launching teaching from a prepared lesson plan.
class SelectClassroomDialog extends StatefulWidget {
  const SelectClassroomDialog({
    super.key,
    required this.plan,
    this.googleApi,
    this.onLaunch,
    this.preferredCourseId,
    this.preferredClassName,
  });

  final PlanningMeta plan;
  final GoogleWorkspaceApi? googleApi;
  final Future<void> Function(TeachingTarget)? onLaunch;
  final String? preferredCourseId, preferredClassName;

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
    String? preferredCourseId,
    String? preferredClassName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SelectClassroomDialog(
        plan: plan,
        googleApi: googleApi,
        onLaunch: onLaunch,
        preferredCourseId: preferredCourseId,
        preferredClassName: preferredClassName,
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
    if (widget.preferredCourseId != null) {
      _sourceType = _ClassSourceType.googleCourse;
    } else if (widget.preferredClassName != null) {
      _sourceType = _ClassSourceType.customClass;
      _customClassController.text = widget.preferredClassName!;
    }
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
          if (widget.preferredCourseId != null) {
            final matches = list.where(
              (course) => '${course['id']}' == widget.preferredCourseId,
            );
            _selectedGoogleCourse = matches.firstOrNull;
            _sourceType = _ClassSourceType.googleCourse;
            if (_selectedGoogleCourse == null) {
              _errorMessage =
                  'Chưa tìm thấy lớp đã gắn với biến thể. Kiểm tra kết nối hoặc chủ động chọn lớp khác.';
            }
          } else if (list.isNotEmpty && widget.preferredClassName == null) {
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

  Future<void> _handleConfirm() async {
    final className = _getTargetClassName();
    if (_sourceType == _ClassSourceType.googleCourse &&
        _selectedGoogleCourse == null) {
      setState(
        () => _errorMessage = 'Chọn lớp Google Classroom trước khi dạy.',
      );
      return;
    }
    if (!await confirmPreparationClass(
          context,
          preferredCourseId: widget.preferredCourseId,
          preferredName: widget.preferredClassName,
          selectedCourseId: _sourceType == _ClassSourceType.googleCourse
              ? (_selectedGoogleCourse ?? {})['id']?.toString()
              : null,
          selectedName: className,
        ) ||
        !mounted) {
      return;
    }
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.sky50,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Center(
                    child: Icon(Icons.videocam_rounded, color: sky, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn lớp để bắt đầu dạy',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: slate,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: subBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.plan.subject,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: subColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.plan.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onPressed: _isLaunching
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
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
                    // Option A: Google Classroom Courses (if available or connected)
                    if (_googleCourses.isNotEmpty) ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'LỚP TỪ GOOGLE CLASSROOM',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _googleCourses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final course = _googleCourses[index];
                          final isSelected =
                              _sourceType == _ClassSourceType.googleCourse &&
                              _selectedGoogleCourse?['id'] == course['id'];
                          final studentCount =
                              (course['students'] as List? ?? []).length;

                          return InkWell(
                            onTap: _isLaunching
                                ? null
                                : () {
                                    setState(() {
                                      _sourceType =
                                          _ClassSourceType.googleCourse;
                                      _selectedGoogleCourse = course;
                                    });
                                  },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.sky50
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? sky : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? sky
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course['title'] as String? ??
                                              'Lớp học',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: slate,
                                          ),
                                        ),
                                        Text(
                                          '$studentCount học sinh · Sẵn sàng phòng Meet',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Option B: Standard / Preset Classes
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 16,
                          color: AppColors.slate600,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LỚP HỌC TIÊU CHUẨN',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_loadingCourses) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetClasses.map((cls) {
                        final isSelected =
                            _sourceType == _ClassSourceType.presetClass &&
                            _selectedPreset == cls;
                        return ChoiceChip(
                          label: Text('Lớp $cls'),
                          selected: isSelected,
                          onSelected: _isLaunching
                              ? null
                              : (selected) {
                                  if (selected) {
                                    setState(() {
                                      _sourceType =
                                          _ClassSourceType.presetClass;
                                      _selectedPreset = cls;
                                    });
                                  }
                                },
                          selectedColor: AppColors.sky50,
                          backgroundColor: AppColors.surfaceMuted,
                          side: BorderSide(
                            color: isSelected ? sky : AppColors.inputBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? sky : AppColors.slate700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Option C: Custom Class Name
                    InkWell(
                      onTap: _isLaunching
                          ? null
                          : () {
                              setState(() {
                                _sourceType = _ClassSourceType.customClass;
                              });
                            },
                      child: Row(
                        children: [
                          Icon(
                            _sourceType == _ClassSourceType.customClass
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 18,
                            color: _sourceType == _ClassSourceType.customClass
                                ? sky
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Hoặc nhập tên lớp khác:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customClassController,
                      enabled: !_isLaunching,
                      onTap: () {
                        if (_sourceType != _ClassSourceType.customClass) {
                          setState(() {
                            _sourceType = _ClassSourceType.customClass;
                          });
                        }
                      },
                      onChanged: (val) {
                        if (_sourceType != _ClassSourceType.customClass) {
                          setState(() {
                            _sourceType = _ClassSourceType.customClass;
                          });
                        } else {
                          setState(() {});
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: 12 Chuyên Toán, Lớp Ôn Thi ĐH...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          borderSide: BorderSide(color: sky, width: 1.5),
                        ),
                      ),
                    ),
                    if (_sourceType != _ClassSourceType.googleCourse) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(
                            Icons.video_call_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'LINK GOOGLE MEET (TÙY CHỌN)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _meetUrlController,
                        enabled: !_isLaunching,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'https://meet.google.com/xxx-yyyy-zzz (hoặc để trống để tạo tự động)',
                          hintStyle: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.content_paste_rounded,
                              size: 18,
                            ),
                            tooltip: 'Dán từ clipboard',
                            onPressed: _isLaunching
                                ? null
                                : () async {
                                    final data = await Clipboard.getData(
                                      Clipboard.kTextPlain,
                                    );
                                    final text = data?.text?.trim();
                                    if (text != null && text.isNotEmpty) {
                                      final extracted =
                                          SelectClassroomDialog.extractRealGoogleMeetUrl(
                                            text,
                                          );
                                      setState(() {
                                        _meetUrlController.text =
                                            extracted ?? text;
                                      });
                                    }
                                  },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                            borderSide: BorderSide(color: sky, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Information summary card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: sky,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _sourceType == _ClassSourceType.googleCourse
                                  ? 'Nhấn xác nhận để nhân bản bài giảng "${widget.plan.title}" và kết nối phòng Google Meet từ Google Classroom ${_getTargetClassName()}.'
                                  : (_meetUrlController.text.trim().isNotEmpty
                                        ? 'Nhấn xác nhận để nhân bản bài giảng "${widget.plan.title}" và bắt đầu dạy với link Google Meet đã nhập.'
                                        : 'Nhấn xác nhận để nhân bản bài giảng "${widget.plan.title}" và tự động tạo phòng Google Meet mới cho ${_getTargetClassName()}.'),
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.slate600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.errorSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLaunching
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isLaunching ? null : _handleConfirm,
                  icon: _isLaunching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.videocam_rounded, size: 18),
                  label: Text(
                    _isLaunching
                        ? 'Đang tạo phòng...'
                        : 'Xác nhận & Bắt đầu dạy',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sky,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
