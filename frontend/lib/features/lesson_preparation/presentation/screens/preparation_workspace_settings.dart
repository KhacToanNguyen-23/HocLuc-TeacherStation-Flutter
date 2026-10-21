part of 'preparation_workspace_screen.dart';

extension _WorkspaceSettings on _WorkspaceState {
  Future<void> _openPdf(PreparationMap source) => _perform(() async {
    await c.openBoard(() async {
      final local = LocalService();
      try {
        final legacy = await local.getPlanningContent(widget.planningId);
        if (legacy == null) {
          throw StateError('Chưa đọc được bảng của bài soạn.');
        }
        final state = StudioState();
        state.restoreFromJson(legacy);
        state.title = c.document.title;
        state.addImportedDoc(
          '${source['name']}',
          null,
          await c.api.bytes('${source['id']}'),
        );
        final snapshot = state.exportLessonJson();
        final saved = await local.updatePlanning(
          id: widget.planningId,
          content: snapshot,
        );
        if (saved == null) {
          state.dispose();
          throw StateError(
            local.planningSaveError ?? 'Chưa lưu được PDF vào bài soạn.',
          );
        }
        state.boardRevision = (snapshot['boardRevision'] as num?)?.toInt() ?? 0;
        if (!mounted) {
          state.dispose();
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => StudioScreen(
              initialState: state,
              isPlanningMode: true,
              planningId: widget.planningId,
              lessonTitle: c.document.title,
            ),
          ),
        );
      } finally {
        local.client.close();
      }
    });
  });
  Future<void> _settings() async {
    final config = Map<String, dynamic>.from(
      c.capabilities['configuration'] is Map
          ? c.capabilities['configuration'] as Map
          : {},
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('AI và thành phần Soạn bài'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PreparationCapabilitiesStatus(capabilities: c.capabilities),
                  const Divider(height: 32),
                  PreparationComponentInstaller(
                    api: c.api,
                    onInstalled: () async {
                      c.capabilities = Map<String, dynamic>.from(
                        await c.api.get('capabilities') as Map,
                      );
                      config
                        ..clear()
                        ..addAll(
                          Map<String, dynamic>.from(
                            c.capabilities['configuration'] is Map
                                ? c.capabilities['configuration'] as Map
                                : {},
                          ),
                        );
                      if (ctx.mounted) update(() {});
                    },
                  ),
                  const Divider(height: 32),
                  const SizedBox(height: 16),
                  const Text(
                    'STT, dịch và giọng đọc dùng model trên máy. AI sinh giáo án dùng API bên thứ ba và cần xác nhận trước mỗi lần gửi.',
                  ),
                  for (final item in const [
                    ('pythonPath', 'Python'),
                    ('ffmpegPath', 'FFmpeg'),
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.$2),
                      subtitle: Text('${config[item.$1] ?? 'Chưa chọn'}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        onPressed: () async {
                          final value = await FilePicker.pickFiles();
                          if ((value.isNotEmpty ? value.single.path : null) !=
                              null) {
                            update(() => config[item.$1] = value.single.path);
                          }
                        },
                      ),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Thư mục ba model speech'),
                    subtitle: Text(
                      '${config['modelRoot'] ?? 'Dùng cấu hình hiện tại'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.folder_open_outlined),
                      onPressed: () async {
                        final directory = await FilePicker.getDirectoryPath();
                        if (directory != null) {
                          update(() => config['modelRoot'] = directory);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 32),
                  const Text('API sinh giáo án · OpenAI-compatible'),
                  PreparationField(
                    label: 'API base URL (HTTPS, thường kết thúc bằng /v1)',
                    value: '${config['authoringBaseUrl'] ?? ''}',
                    onChanged: (v) => config['authoringBaseUrl'] = v.trim(),
                  ),
                  PreparationField(
                    label: 'Model ID do nhà cung cấp hỗ trợ',
                    value: '${config['authoringModel'] ?? ''}',
                    onChanged: (v) => config['authoringModel'] = v.trim(),
                  ),
                  const Text(
                    'Chỉ dùng API tương thích Chat Completions. Quản trị viên cấu hình HOCLUC_AUTHORING_API_KEY và HOCLUC_AUTHORING_ALLOWED_HOSTS ở backend; không nhập API key trong app. Lưu cấu hình không gửi yêu cầu sinh nội dung.',
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Chi tiết kiểm tra'),
                    children: [
                      SelectableText(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(c.capabilities),
                      ),
                    ],
                  ),
                  const Text(
                    'Chưa chọn nhà cung cấp? Để trống API và model; vẫn có thể soạn thủ công, chia cảnh từ script và dùng STT/dịch/giọng đọc local.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _perform(() async {
                  await c.api.put('configuration', config);
                  c.capabilities = Map<String, dynamic>.from(
                    await c.api.get('capabilities') as Map,
                  );
                });
              },
              child: const Text('Lưu và kiểm tra'),
            ),
          ],
        ),
      ),
    );
  }
}
