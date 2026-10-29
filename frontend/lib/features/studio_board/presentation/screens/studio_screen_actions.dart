// ignore_for_file: invalid_use_of_protected_member
part of 'studio_screen.dart';

extension _StudioScreenActionsExt on _StudioScreenState {
  Future<void> save() async {
    if (widget.isPlanningMode) {
      if (studio.saving) return;
      studio.change(() => studio.saving = true, persist: false);
      String? errorMessage;
      try {
        final lessonSnapshot = studio.exportLessonJson();
        final targetId = _currentPlanningId ?? widget.planningId;
        FrontendLogger.write(
          '[StudioScreen] Starting save planning | target_id=$targetId page=${studio.pdfPage}',
        );

        bool success = false;
        final planningRepo = PlanningRepository(localService: studio.service);
        if (targetId != null) {
          final res = await planningRepo.updatePlanning(
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
          final res = await planningRepo.createPlanning(
            title: studio.title,
            subject: studio.subject,
            content: lessonSnapshot,
          );
          success = res != null;
          if (res != null) {
            _currentPlanningId = res.id;
            FrontendLogger.write('[StudioScreen] Saved new planning');
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
      } catch (e) {
        FrontendLogger.write(
          '[StudioScreen] Save planning failed | cause=${e.runtimeType}',
        );
        if (mounted) message('Lỗi khi lưu bài giảng: $e');
      } finally {
        studio.change(() => studio.saving = false, persist: false);
      }
      return;
    }

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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
    await save();
    if (!mounted) return;
    final id = _currentPlanningId ?? widget.planningId;
    if (id == null || studio.dirty) {
      message('Lưu bài giảng trước khi chọn lớp để dạy.');
      return;
    }
    final meta = PlanningMeta(
      id: id,
      title: studio.title,
      subject: studio.subject,
      pageCount: studio.pages.length,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await SelectClassroomDialog.show(context, plan: meta);
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
      try {
        await _ensureTeachingSessionRecorded();
      } catch (e) {
        if (mounted) message('Chưa thể tạm rời phòng: $e');
        return;
      }
      _tutorSession.controller.setEnabled(false);
      if (widget.teachingTarget != null) {
        await MeetAutomationService().stopScreenSharing();
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
      final local = LocalService();
      try {
        final session = await _ensureTeachingSessionRecorded();
        final active = await local.getActiveClassroom(strict: true);
        if (active['status'] == 'ONGOING') {
          final snapshot = studio.exportLessonJson();
          if (!await local.endClassroom(
            classroomId: _sessionId ?? active['id'] as String?,
            content: snapshot,
          )) {
            throw StateError(
              'Chưa lưu được buổi học vào lịch sử. Vui lòng thử lại.',
            );
          }
        } else if (session != null) {
          throw StateError(
            'Không tìm thấy buổi học đang mở để lưu vào lịch sử.',
          );
        }
      } catch (e) {
        message('Buổi học vẫn mở trong Studio: $e');
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

  Future<void> openInspector({int? initialTab}) async {
    if (showInspectorModal) return;
    setState(() {
      showInspectorModal = true;
      if (initialTab != null) _inspectorInitialTab = initialTab;
    });
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SizedBox(
          height: 520,
          child: StudioInspectorPanel(
            tutor: _tutorSession.controller,
            initialTab: _inspectorInitialTab,
            studio: studio,
            notesController: notes,
            questionController: question,
            endpointController: endpoint,
            onPreview: preview,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => showInspectorModal = false);
    }
  }

  Widget fittedStage({bool interactive = true}) {
    if (studio.view == 'question') {
      return StudioQuestionView(studio: studio, interactive: interactive);
    }
    return StageContainer(studio: studio, interactive: interactive);
  }
}
