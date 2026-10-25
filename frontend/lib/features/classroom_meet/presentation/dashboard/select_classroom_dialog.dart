import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/core/ui/hocluc_brand_mark.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_workspace_api.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';

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
    return showAppModalDialog<void>(
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

class _SelectClassroomDialogState extends State<SelectClassroomDialog> {
  final _authService = GoogleMeetAuthService();
  final _searchController = TextEditingController();

  Map<String, dynamic>? _selectedGoogleCourse;
  String? _selectionBeforeSearch;

  List<Map<String, dynamic>> _googleCourses = [];
  bool _loadingCourses = false;
  bool _isLaunching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGoogleCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGoogleCourses() async {
    final email = _authService.teacherEmail ?? widget.googleApi?.email;
    if (email == null || email.isEmpty) return;

    setState(() => _loadingCourses = true);
    final api = widget.googleApi ?? GoogleWorkspaceApi(email: email);
    try {
      final status = await api.call('status');
      if (!mounted) return;
      if (status['connected'] == true) {
        final result = await api.call('courses');
        if (!mounted) return;
        final list =
            (result['courses'] as List? ?? []).cast<Map<String, dynamic>>()
              ..sort((a, b) {
                final countOrder = _studentCount(b).compareTo(_studentCount(a));
                if (countOrder != 0) return countOrder;
                return (a['title'] as String? ?? '').toLowerCase().compareTo(
                  (b['title'] as String? ?? '').toLowerCase(),
                );
              });
        Map<String, dynamic>? firstWithStudents;
        for (final course in list) {
          if (_studentCount(course) > 0) {
            firstWithStudents = course;
            break;
          }
        }
        setState(() {
          _googleCourses = list;
          if (firstWithStudents != null) {
            _selectedGoogleCourse = firstWithStudents;
          }
        });
      }
    } catch (_) {
      // Offline or Google service not connected; the empty state explains it.
    } finally {
      if (widget.googleApi == null) api.close();
      if (mounted) setState(() => _loadingCourses = false);
    }
  }

  int _studentCount(Map<String, dynamic> course) =>
      (course['students'] as List? ?? []).length;

  String _getTargetClassName() =>
      _selectedGoogleCourse?['title'] as String? ?? 'Lớp Google Classroom';

  List<Map<String, dynamic>> get _filteredCourses {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _googleCourses;
    return _googleCourses.where((course) {
      final title = (course['title'] as String? ?? '').toLowerCase();
      return title.contains(query);
    }).toList();
  }

  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        if (_selectedGoogleCourse == null && _selectionBeforeSearch != null) {
          for (final course in _googleCourses) {
            if (course['id'] == _selectionBeforeSearch) {
              _selectedGoogleCourse = course;
              break;
            }
          }
        }
        _selectionBeforeSearch = null;
        return;
      }

      final selected = _selectedGoogleCourse;
      final selectedTitle = selected?['title']?.toString().toLowerCase() ?? '';
      if (selected != null && !selectedTitle.contains(query)) {
        _selectionBeforeSearch ??= selected['id']?.toString();
        _selectedGoogleCourse = null;
      }
    });
  }

  Future<void> _handleConfirm() async {
    final course = _selectedGoogleCourse;
    if (course == null || _studentCount(course) == 0) {
      setState(() => _errorMessage = 'Vui lòng chọn một lớp có học sinh.');
      return;
    }
    final className = _getTargetClassName();
    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    try {
      final email = _authService.teacherEmail ?? widget.googleApi?.email ?? '';
      String? meetingUrl = course['meetingUrl'] as String?;

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

      final target = TeachingTarget(
        title: '$className · ${widget.plan.title}',
        meetingUrl: meetingUrl,
        courseId: course['id'] as String?,
        teacherEmail: email.isNotEmpty ? email : null,
        planningId: widget.plan.id,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.onLaunch != null) {
        await widget.onLaunch!(target);
      } else if (context.mounted) {
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
    final filteredCourses = _filteredCourses;
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 32,
        vertical: compact ? 18 : 32,
      ),
      child: Container(
        width: 560,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        padding: EdgeInsets.all(compact ? 18 : 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentDark.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  alignment: Alignment.center,
                  child: const HocLucBrandMark(size: 34),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn lớp để bắt đầu dạy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
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
                              color: AppColors.shellSidebarActive,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.plan.subject,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentDark,
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDim,
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
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // 2. Class Selection Body
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      enabled: !_isLaunching,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tìm lớp theo tên',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textDim,
                        ),
                        hintStyle: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceInput,
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Xóa tìm kiếm',
                                onPressed: _isLaunching
                                    ? null
                                    : () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          borderSide: const BorderSide(
                            color: AppColors.inputBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          borderSide: const BorderSide(
                            color: AppColors.inputBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          borderSide: const BorderSide(
                            color: AppColors.sky,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Google Classroom courses
                    const Row(
                      children: [
                        Icon(
                          Icons.school_rounded,
                          size: 16,
                          color: AppColors.sky,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'LỚP TỪ GOOGLE CLASSROOM',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHeadingMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingCourses)
                      Column(
                        children: List.generate(
                          3,
                          (_) => Container(
                            height: 58,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: AppColors.skeletonHighlight,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 12,
                                        width: 170,
                                        decoration: BoxDecoration(
                                          color: AppColors.skeletonHighlight,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Container(
                                        height: 9,
                                        width: 110,
                                        decoration: BoxDecoration(
                                          color: AppColors.skeletonHighlight,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (_googleCourses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text(
                            'Chưa có lớp Google Classroom để hiển thị.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else if (filteredCourses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text(
                            'Không tìm thấy lớp phù hợp.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredCourses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final course = filteredCourses[index];
                          final isSelected =
                              _selectedGoogleCourse?['id'] == course['id'];
                          final studentCount = _studentCount(course);
                          final isEmpty = studentCount == 0;

                          return InkWell(
                            onTap: _isLaunching || isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _selectedGoogleCourse = course;
                                      _selectionBeforeSearch = null;
                                      _errorMessage = null;
                                    });
                                  },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isEmpty
                                    ? AppColors.lockSoft
                                    : isSelected
                                    ? AppColors.shellSidebarActive
                                    : AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.sky
                                      : isEmpty
                                      ? AppColors.border
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isEmpty
                                        ? Icons.lock_outline_rounded
                                        : isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    size: 18,
                                    color: isEmpty
                                        ? AppColors.lock
                                        : isSelected
                                        ? AppColors.sky
                                        : AppColors.textDim,
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
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isEmpty
                                                ? AppColors.textDim
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          isEmpty
                                              ? '0 học sinh · Không thể chọn'
                                              : '$studentCount học sinh',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textDim,
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
                  onPressed: _isLaunching || _selectedGoogleCourse == null
                      ? null
                      : _handleConfirm,
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
                    backgroundColor: AppColors.accentDark,
                    disabledBackgroundColor: AppColors.lockSoft,
                    disabledForegroundColor: AppColors.textDim,
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


