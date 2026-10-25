// ignore_for_file: invalid_use_of_protected_member
part of 'classroom_dashboard_screen.dart';

extension _ClassroomDashboardRoomsAndHistoryExt
    on _ClassroomDashboardScreenState {
  Widget _buildRoomListCard() {
    final hasOngoing =
        _activeRoom != null && _activeRoom!['status'] == 'ONGOING';

    if (!hasOngoing) {
      return DashboardEmptyCard(
        title: 'Phòng học',
        dropdownValue: _selectedRoomFilter,
        dropdownItems: const ['Tất cả', 'Đang diễn ra', 'Đã lên lịch'],
        onDropdownChanged: (val) {
          if (val != null) _cubit.setRoomFilter(val);
        },
        illustrationType: 'rooms',
        emptyText: 'Chưa có phòng học',
        actionButton: ElevatedButton(
          onPressed: _startClassroom,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
          ),
          child: const Text(
            'Bắt đầu',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final title = _activeRoom!['title']?.toString() ?? 'Phòng học trực tuyến';
    final meetUrl = _activeRoom!['meetingUrl']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Phòng học',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 8,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Đang diễn ra',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.selected,
                          borderRadius: BorderRadius.circular(AppRadii.control),
                        ),
                        child: const Icon(
                          Icons.video_call_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meetUrl,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejoinClassroom(meetUrl),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text(
                            'Vào lại phòng',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.control,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _startClassroom,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate700,
                          side: const BorderSide(color: AppColors.inputBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                        ),
                        child: const Text(
                          'Tạo mới',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownloadHistoryHandout(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    final title = item['title']?.toString() ?? 'Tài liệu buổi học';
    if (id == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final content = await _localService.getClassroomContent(id);
    if (!mounted) return;

    if (content == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Buổi học này chưa lưu slide hoặc ghi chú để xuất Handout.',
          ),
          backgroundColor: AppColors.textMuted,
        ),
      );
      return;
    }

    final studio = StudioState();
    studio.title = title;
    studio.restoreFromJson(content);
    await PdfAnnotationExporter.exportHandoutWithNotesToPdf(context, studio);
  }

  Future<void> _handleDownloadHistorySlides(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    final title = item['title']?.toString() ?? 'Slide buổi học';
    if (id == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final content = await _localService.getClassroomContent(id);
    if (!mounted) return;

    if (content == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Buổi học này chưa có slide để xuất PDF.'),
          backgroundColor: AppColors.textMuted,
        ),
      );
      return;
    }

    final studio = StudioState();
    studio.title = title;
    studio.restoreFromJson(content);
    await PdfAnnotationExporter.exportChalkboardSlidesToPdf(context, studio);
  }

  Future<void> _handleDeleteHistoryItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    final title = item['title']?.toString() ?? 'Buổi học';
    if (id == null) return;

    final confirmed = await showAppModalDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Xóa lịch sử buổi học',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa "$title" khỏi lịch sử? Bản lưu bài giảng và ghi chú liên quan cũng sẽ bị xóa.',
          style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _localService.deleteClassroomHistory(id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa buổi học khỏi lịch sử.'),
            duration: Duration(seconds: 2),
          ),
        );
        await _loadRoomsAndHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa buổi học. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleClearAllHistory() async {
    if (_historyList.isEmpty) return;

    final confirmed = await showAppModalDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Xóa tất cả lịch sử',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ danh sách lịch sử buổi học đã dạy? Toàn bộ slide và ghi chú đã lưu trước đây sẽ bị xóa hoàn toàn.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _localService.clearAllClassroomHistory();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa toàn bộ lịch sử buổi học.'),
            duration: Duration(seconds: 2),
          ),
        );
        await _loadRoomsAndHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa lịch sử. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildHistoryCard() {
    if (_historyList.isEmpty) {
      return const DashboardEmptyCard(
        title: 'Lịch sử',
        illustrationType: 'history',
        emptyText: 'Chưa có lịch sử',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Lịch sử buổi học đã dạy',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_historyList.length} buổi học',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              AppPressable(
                tooltip: 'Xóa toàn bộ lịch sử buổi học',
                onTap: _handleClearAllHistory,
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_sweep_outlined,
                        size: 15,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Xóa tất cả',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _historyList.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 14, color: AppColors.surfaceMuted),
              itemBuilder: (context, index) {
                final item = _historyList[index] as Map<String, dynamic>;
                final title =
                    item['title']?.toString() ?? 'Phòng học trực tuyến';
                final hasContent = item['hasContent'] == true;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: hasContent
                            ? AppColors.sky50
                            : AppColors.surfaceMuted,
                        child: Icon(
                          hasContent
                              ? Icons.auto_stories_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 17,
                          color: hasContent
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Builder(
                              builder: (context) {
                                final start = _parseHistoryDateTime(
                                  item['startedAt'] ?? item['createdAt'],
                                );
                                final end = _parseHistoryDateTime(
                                  item['endedAt'],
                                );
                                final timeRange = _buildHistoryTimeRange(
                                  start,
                                  end,
                                );
                                final durStr = _buildHistoryDurationText(
                                  item,
                                  start,
                                  end,
                                );

                                return Tooltip(
                                  message: _buildHistoryTooltip(item),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        if (timeRange.isNotEmpty) ...[
                                          TextSpan(
                                            text: timeRange,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const TextSpan(text: ' · '),
                                        ],
                                        if (durStr.isNotEmpty) ...[
                                          TextSpan(text: durStr),
                                          const TextSpan(text: ' · '),
                                        ],
                                        const TextSpan(
                                          text: 'Đã hoàn thành',
                                          style: TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action 1: Tải Handout PDF (Slide kèm Ghi chú)
                      AppPressable(
                        tooltip: 'Tải tài liệu Handout (Slide kèm Ghi chú) PDF',
                        onTap: () => _handleDownloadHistoryHandout(item),
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Action 2: Tải Slide PDF
                      AppPressable(
                        tooltip: 'Tải Slide bảng dạng PDF',
                        onTap: () => _handleDownloadHistorySlides(item),
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.slideshow_rounded,
                            size: 18,
                            color: AppColors.slate600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Action 3: Xóa mục lịch sử
                      AppPressable(
                        tooltip: 'Xóa buổi học này khỏi lịch sử',
                        onTap: () => _handleDeleteHistoryItem(item),
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final settings = ClassroomSettingsService.instance;
    await settings.load();
    if (!context.mounted) return;
    await showAppModalDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.panel),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings_outlined, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Cài đặt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.videocam_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Tự động bật camera khi vào lớp',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  trailing: Switch(
                    value: settings.autoCamera,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) async {
                      await settings.setAutoCamera(value);
                      setDialogState(() {});
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.mic_none_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Khử tiếng ồn micro thông minh',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  trailing: Switch(
                    value: settings.noiseSuppression,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) async {
                      await settings.setNoiseSuppression(value);
                      setDialogState(() {});
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.draw_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Tối ưu hóa bút vẽ & cảm ứng',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  trailing: Switch(
                    value: settings.boardOptimization,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) async {
                      await settings.setBoardOptimization(value);
                      setDialogState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Đóng',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseHistoryDateTime(dynamic val) {
    if (val == null) return null;
    if (val is num && val > 0) {
      return DateTime.fromMillisecondsSinceEpoch(val.toInt()).toLocal();
    }
    if (val is String) {
      final ms = int.tryParse(val);
      if (ms != null && ms > 0) {
        return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      }
      return DateTime.tryParse(val)?.toLocal();
    }
    return null;
  }

  String _formatHm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatHms(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDmy(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  String _buildHistoryDurationText(
    Map<String, dynamic> item,
    DateTime? start,
    DateTime? end,
  ) {
    if (start != null && end != null) {
      final diff = end.difference(start);
      if (diff.inHours >= 1) {
        final rem = diff.inMinutes % 60;
        return rem > 0
            ? '${diff.inHours} giờ $rem phút'
            : '${diff.inHours} giờ';
      } else if (diff.inMinutes >= 1) {
        return '${diff.inMinutes} phút';
      } else if (diff.inSeconds > 0) {
        return '${diff.inSeconds} giây';
      } else {
        return '< 1 phút';
      }
    }
    final duration = item['durationMinutes'];
    if (duration is num && duration > 0) {
      return '${duration.toInt()} phút';
    }
    return '';
  }

  String _buildHistoryTimeRange(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      final startStr = _formatHm(start);
      final endStr = _formatHm(end);
      final isSameDay =
          start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;
      if (isSameDay) {
        return '$startStr – $endStr (${_formatDmy(start)})';
      } else {
        return '$startStr (${start.day}/${start.month}) – $endStr (${_formatDmy(end)})';
      }
    } else if (start != null) {
      return 'Bắt đầu: ${_formatHm(start)} (${_formatDmy(start)})';
    }
    return '';
  }

  String _buildHistoryTooltip(Map<String, dynamic> item) {
    final start = _parseHistoryDateTime(item['startedAt'] ?? item['createdAt']);
    final end = _parseHistoryDateTime(item['endedAt']);
    final duration = item['durationMinutes'];

    final buffer = StringBuffer();
    final title = item['title']?.toString();
    if (title != null && title.isNotEmpty) {
      buffer.writeln(title);
    }
    if (start != null) {
      buffer.writeln('Bắt đầu: ${_formatHms(start)} ngày ${_formatDmy(start)}');
    }
    if (end != null) {
      buffer.writeln('Kết thúc: ${_formatHms(end)} ngày ${_formatDmy(end)}');
    }
    final dur = _buildHistoryDurationText(item, start, end);
    if (dur.isNotEmpty) {
      buffer.writeln('Thời lượng: $dur');
    } else if (duration is num && duration > 0) {
      buffer.writeln('Thời lượng: ${duration.toInt()} phút');
    }
    buffer.write('Trạng thái: Đã hoàn thành');
    return buffer.toString();
  }
}
