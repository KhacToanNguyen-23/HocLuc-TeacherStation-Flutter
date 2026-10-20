// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of 'select_classroom_dialog.dart';

extension SelectClassroomSections on _SelectClassroomDialogState {
  Widget _buildDialogHeader({
    required Color slate,
    required Color sky,
    required Color subColor,
    required Color subBg,
  }) {
    return Row(
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
          onPressed: _isLaunching ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildGoogleCoursesSection({
    required Color slate,
    required Color sky,
  }) {
    if (_googleCourses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.school_rounded, size: 16, color: AppColors.primary),
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
            final studentCount = (course['students'] as List? ?? []).length;

            return InkWell(
              onTap: _isLaunching
                  ? null
                  : () {
                      setState(() {
                        _sourceType = _ClassSourceType.googleCourse;
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
                  color: isSelected ? AppColors.sky50 : AppColors.surfaceMuted,
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
                      color: isSelected ? sky : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course['title'] as String? ?? 'Lớp học',
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
    );
  }

  Widget _buildPresetClassesSection({required Color sky}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                          _sourceType = _ClassSourceType.presetClass;
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
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? sky : AppColors.slate700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCustomClassSection({required Color sky}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildSummaryAndErrorBanners({required Color sky}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }

  Widget _buildDialogActions({required Color sky}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isLaunching ? null : () => Navigator.of(context).pop(),
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
            _isLaunching ? 'Đang tạo phòng...' : 'Xác nhận & Bắt đầu dạy',
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
    );
  }
}
