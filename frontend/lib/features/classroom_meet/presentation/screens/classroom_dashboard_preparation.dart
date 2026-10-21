part of 'classroom_dashboard_screen.dart';

extension _DashboardPreparation on _ClassroomDashboardScreenState {
  Widget _buildDashboardTabs() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _buildTabButton(
          index: 0,
          title: 'Phòng học',
          icon: Icons.meeting_room_outlined,
          badgeCount: _activeRoom != null ? 1 : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildTabButton(
          index: 1,
          title: 'Kế hoạch giảng dạy',
          icon: Icons.menu_book_outlined,
          badgeCount: _plannings.isNotEmpty ? _plannings.length : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildTabButton(
          index: 2,
          title: 'Soạn bài',
          icon: Icons.edit_note_rounded,
          badgeCount: _plannings.isNotEmpty ? _plannings.length : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildTabButton(
          index: 3,
          title: 'Lịch sử',
          icon: Icons.history_rounded,
          badgeCount: _historyList.isNotEmpty ? _historyList.length : null,
        ),
      ],
    ),
  );

  Widget _buildDashboardTabContent() {
    if (_selectedTabIndex == 0) return _buildRoomListCard();
    if (_selectedTabIndex == 3) return _buildHistoryCard();
    final preparation = _selectedTabIndex == 2;
    return PlanningListCard(
      preparationMode: preparation,
      plannings: _plannings,
      isLoading: _loadingPlannings,
      selectedSubject: preparation
          ? _preparationSubjectFilter
          : _selectedSubjectFilter,
      subjectOptions: _subjectOptions,
      onSubjectChanged: (value) {
        if (value == null) return;
        _changePlanningSubject(value, preparation: preparation);
      },
      onCreateNew: () => _handleCreateNewPlanning(preparation: preparation),
      onEdit: preparation ? _handleEditPlanning : _editPlanningBoard,
      onLaunch: _handleLaunchFromPlanning,
      onDelete: _handleDeletePlanning,
      onDuplicate: preparation ? _duplicatePlanning : null,
    );
  }

  Future<void> _editPlanningBoard(PlanningMeta plan) async {
    await _openPlanningBoard(plan);
    await _loadPlannings();
  }

  Future<void> _duplicatePlanning(PlanningMeta plan) async {
    final api = PreparationApi();
    try {
      await api.post('plannings/${plan.id}/duplicate');
      if (mounted) await _loadPlannings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      api.dispose();
    }
  }

  Future<void> _openVariantById(String id) async {
    final api = PreparationApi();
    try {
      final value =
          await api.get('plannings/${Uri.encodeComponent(id)}') as Map;
      final document = value['document'] is Map
          ? value['document'] as Map
          : value;
      final plan = PlanningMeta.fromJson({
        ...Map<String, dynamic>.from(document),
        'id': id,
      });
      if (mounted) await _handleEditPlanning(plan);
    } finally {
      api.dispose();
    }
  }

  Future<void> _launchBoundPlanning(PlanningMeta plan) async {
    final content = await _localService.getPlanningContent(plan.id);
    if (!mounted) return;
    if (content == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa đọc được bài để xác định lớp. Hãy thử lại.'),
        ),
      );
      return;
    }
    final preparation = content['preparation'];
    final variant = preparation is Map ? preparation['variant'] : null;
    final target = variant is Map && variant['targetClass'] is Map
        ? variant['targetClass'] as Map
        : null;
    await SelectClassroomDialog.show(
      context,
      plan: plan,
      preferredCourseId: target?['kind'] == 'google'
          ? '${target?['id']}'
          : null,
      preferredClassName: target?['name']?.toString(),
    );
  }
}
