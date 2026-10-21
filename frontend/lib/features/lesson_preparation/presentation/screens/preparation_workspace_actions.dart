part of 'preparation_workspace_screen.dart';

extension _WorkspaceActions on _WorkspaceState {
  Future<void> _reusePlanning() => _perform(() async {
    if (!await _saveBeforeLeave() || !mounted || c.dirty || c.conflict) return;
    final local = LocalService();
    List<PreparationMap> library;
    try {
      library = widget.loadPlanningLibrary != null
          ? await widget.loadPlanningLibrary!()
          : [
              for (final plan in await local.getPlannings())
                {'id': plan.id, 'title': plan.title, 'subject': plan.subject},
            ];
    } finally {
      local.client.close();
    }
    final available = library
        .where((plan) => '${plan['id']}' != widget.planningId)
        .toList();
    if (!mounted) return;
    _refreshWorkspace(() => _busy = false);
    final source = await showDialog<PreparationMap>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Chọn bài để tạo bản soạn mới'),
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'App tạo một bản sao độc lập. Bài gốc và bài đang mở được giữ nguyên.',
            ),
          ),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Chưa có bài khác trong thư viện để dùng lại.'),
            ),
          for (final plan in available)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, plan),
              child: ListTile(
                title: Text('${plan['title'] ?? 'Chưa đặt tên'}'),
                subtitle: Text('${plan['subject'] ?? ''}'),
                trailing: const Icon(Icons.copy_outlined),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    _refreshWorkspace(() => _busy = true);
    final result = Map<String, dynamic>.from(
      await c.api.post(
            'plannings/${Uri.encodeComponent('${source['id']}')}/duplicate',
          )
          as Map,
    );
    final id = '${result['planningId'] ?? ''}';
    if (id.isEmpty) {
      throw PreparationFailure(
        'Máy chủ chưa trả về mã bản sao. Hãy kiểm tra thư viện trước khi thử lại.',
        502,
      );
    }
    if (!mounted) return;
    if (widget.onOpenVariant != null) {
      await widget.onOpenVariant!(id);
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bản sao đã được tạo'),
          content: Text(
            'Đã tạo bản sao của “${source['title']}”. Quay lại danh sách Soạn bài để mở bản sao; bài gốc vẫn được giữ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Về danh sách bài'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    }
  });

  Future<void> _sheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        SizedBox(height: MediaQuery.sizeOf(context).height * .88, child: child),
  );

  Future<void> _workspaceAction(String action) async {
    if (_busy || c.loading) return;
    if (action == 'pdf' || action == 'teacher_pdf') {
      await _run(
        'export_pdf',
        options: {'audience': action == 'teacher_pdf' ? 'teacher' : 'student'},
      );
    } else if (action == 'render') {
      await _run(
        'render',
        options: {'voice': c.document.data['voice'] ?? 'af_heart'},
      );
    } else if (action == 'tools') {
      await _sheet(
        PreparationToolsSheet(controller: c, onOpenDraft: widget.onOpenVariant),
      );
    } else if (action == 'export_template') {
      await _sheet(
        PreparationExportSettingsSheet(controller: c, onPreview: _preview),
      );
    } else if (action == 'publish') {
      await _sheet(PreparationPublishSheet(controller: c, onPreview: _preview));
    } else if (action == 'questions') {
      final inserted = await showDialog<bool>(
        context: context,
        builder: (_) => PreparationQuestionPicker(controller: c),
      );
      if (inserted == true && mounted) {
        _view = 0;
        _selection = c.document.rows('sections').length - 1;
        _update();
      }
    } else if (action == 'variant') {
      if (!await _saveBeforeLeave() || !mounted) return;
      if (c.dirty || c.conflict) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần lưu bài trước khi tạo biến thể.')),
        );
        return;
      }
      String? created;
      await _sheet(
        PreparationVariantSheet(
          api: c.api,
          planningId: c.planId,
          document: c.document,
          onCreated: (id) => created = id,
        ),
      );
      if (created != null && mounted) {
        if (widget.onOpenVariant != null) {
          await widget.onOpenVariant!(created!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tạo biến thể. Mở lại từ danh sách Soạn bài.'),
            ),
          );
        }
      }
    } else if (action == 'teach') {
      await _perform(() async {
        if (!await _saveBeforeLeave()) return;
        if (c.dirty || c.conflict) throw StateError('Bài chưa lưu.');
        await widget.onTeach();
      });
    }
  }

  Widget _variantBanner() {
    final variant = c.document.data['variant'] as Map;
    final target = variant['targetClass'] is Map
        ? variant['targetClass'] as Map
        : {};
    return ListTile(
      dense: true,
      leading: const Icon(Icons.account_tree_outlined),
      title: Text('Biến thể cho lớp ${target['name'] ?? target['id'] ?? ''}'),
      subtitle: Text(
        'Từ bài ${variant['parentPlanningId']} · phiên bản ${variant['parentRevision']}\n${variant['adaptationNotes'] ?? ''}',
      ),
    );
  }
}
