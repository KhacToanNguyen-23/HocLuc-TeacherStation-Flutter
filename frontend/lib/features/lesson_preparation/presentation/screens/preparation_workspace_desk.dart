part of 'preparation_workspace_screen.dart';

extension _WorkspaceDesk on _WorkspaceState {
  Future<void> _compareVersions() async {
    final remote = await c.remoteCopy();
    if (remote == null || !mounted) return;
    String readable(PreparationDocument doc) => [
      doc.title,
      for (final row in doc.rows('sections'))
        '${row['title'] ?? ''}\n${row['body'] ?? ''}\nLời nhắc riêng: ${row['teacherNotes'] ?? ''}',
      for (final cue in doc.rows('teacherCues'))
        'Lời nhắc trang: ${cue['text'] ?? ''}',
    ].join('\n\n');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('So sánh trước khi thay bài đang sửa'),
        content: SizedBox(
          width: 950,
          height: 420,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in [
                ('Bản đang sửa trên máy', c.document),
                ('Bản đã lưu trên máy chủ', remote),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(readable(item.$2)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Giữ bản đang sửa'),
          ),
          TextButton(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: readable(c.document))),
            child: const Text('Sao chép nội dung đang sửa'),
          ),
          FilledButton(
            onPressed: () async {
              if (await c.reloadDiscardingChanges() && ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Dùng bản máy chủ'),
          ),
        ],
      ),
    );
  }

  void _insertText(String text) {
    if (text.trim().isEmpty) return;
    final rows = c.document.rows('sections');
    if (rows.isEmpty) {
      _addSection(text);
      return;
    }
    if (_selection >= rows.length) _selection = rows.length - 1;
    final old = '${rows[_selection]['body'] ?? ''}';
    _editRow('sections', 'body', old.isEmpty ? text : '$old\n\n$text');
    _refreshWorkspace(() => _view = 0);
  }

  Widget _deskToolbar() => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          IgnorePointer(
            ignoring: !c.loaded,
            child: Opacity(
              opacity: c.loaded ? 1 : .5,
              child: PreparationField(
                label: 'Tên bài giảng / thuyết trình',
                value: c.document.title,
                onChanged: (value) => c.change((d) => d.data['title'] = value),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_view != 0)
                  TextButton.icon(
                    onPressed: () => _refreshWorkspace(() {
                      _view = 0;
                      _selection = 0;
                    }),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Về bài đang soạn'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: c.loaded ? _chooseSource : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm nội dung'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: c.loaded
                      ? () => _perform(() async {
                          await c.openBoard(widget.onOpenBoard);
                        })
                      : null,
                  icon: const Icon(Icons.dashboard_outlined),
                  label: const Text('Chuẩn bị bảng trình chiếu'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: c.loaded ? _editPageCues : null,
                  icon: const Icon(Icons.speaker_notes_outlined),
                  label: const Text('Lời nhắc theo trang'),
                ),
                TextButton.icon(
                  onPressed: () => _refreshWorkspace(() => _view = 4),
                  icon: const Icon(Icons.folder_outlined),
                  label: Text(
                    'Tài liệu đã tạo (${c.document.rows('artifacts').length})',
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Công cụ bổ sung',
                  onSelected: (value) => _refreshWorkspace(() {
                    _view = value;
                    _selection = 0;
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 2, child: Text('Video có giọng đọc')),
                  ],
                ),
              ],
            ),
          ),
          if (c.jobs.any(
            (j) => j['status'] == 'running' || j['status'] == 'queued',
          ))
            ListTile(
              dense: true,
              leading: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: const Text(
                'Đang xử lý nội dung — bạn có thể tiếp tục soạn',
              ),
              trailing: TextButton(
                onPressed: () => _refreshWorkspace(() => _view = 4),
                child: const Text('Xem tiến độ'),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _loadFailure() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Chưa mở được bài đã lưu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              c.authRequired
                  ? 'Đăng nhập lại qua màn hình đăng nhập của app, sau đó thử mở bài. Các thay đổi đang giữ sẽ không bị tự xóa.'
                  : 'Kiểm tra kết nối backend và thử lại. Chỉ bắt đầu chỉnh sửa khi đọc được bài.',
            ),
            TextButton(onPressed: c.load, child: const Text('Thử mở lại')),
            if (c.hasLocalDraft)
              TextButton(
                onPressed: c.recoverLocalDraft,
                child: const Text('Khôi phục bản nháp trên máy'),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _lessonDesk() {
    final rows = c.document.rows('sections');
    if (rows.isEmpty) return _startDesk();
    if (_selection >= rows.length) _selection = rows.length - 1;
    final selected = rows[_selection];
    final outline = ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            'Dàn ý bài giảng',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        for (var i = 0; i < rows.length; i++)
          ListTile(
            selected: i == _selection,
            leading: Text('${i + 1}'),
            title: Text('${rows[i]['title'] ?? 'Chưa đặt tên'}', maxLines: 2),
            subtitle: (rows[i]['minutes'] as num? ?? 0) > 0
                ? Text('${rows[i]['minutes']} phút')
                : null,
            onTap: () => _refreshWorkspace(() => _selection = i),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add),
            label: const Text('Thêm phần'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tổng thời gian dự kiến: ${rows.fold<int>(0, (n, r) => n + ((r['minutes'] as num?)?.toInt() ?? 0))} phút',
          ),
        ),
      ],
    );
    final notes = _privateNotes(selected);
    Widget editor({bool inlineNotes = false}) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nội dung của phần đang chọn',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Viết nội dung giảng hoặc hướng dẫn người học. Lời nhắc và đáp án riêng đặt trong Hỗ trợ giáo viên.',
          ),
          const SizedBox(height: 20),
          PreparationSectionEditor(
            key: ValueKey(selected['id']),
            section: selected,
            showTeacherNotes: false,
            onChange: (field, value) => _editRow('sections', field, value),
            onDelete: () => _deleteRow('sections'),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _chooseSource,
                icon: const Icon(Icons.attach_file),
                label: const Text('Thêm nội dung vào phần này'),
              ),
              TextButton.icon(
                onPressed: () => _workspaceAction('questions'),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Chèn câu hỏi đã duyệt'),
              ),
              IconButton(
                tooltip: 'Đưa phần lên',
                onPressed: _selection > 0
                    ? () => _moveRow('sections', -1)
                    : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Đưa phần xuống',
                onPressed: _selection < rows.length - 1
                    ? () => _moveRow('sections', 1)
                    : null,
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Tài liệu tham chiếu (tùy chọn)'),
            children: [
              PreparationSourceEvidence(
                item: selected,
                sources: c.document.rows('sources'),
                onProbe: (source) async => Map<String, dynamic>.from(
                  await c.api.post('${c.path}/sources/${source['id']}/probe')
                      as Map,
                ),
                onChanged: (refs) => _editRow('sections', 'sourceRefs', refs),
                onPreview: (source, second) =>
                    _preview(source, initialPosition: second),
              ),
            ],
          ),
          PreparationQuestionImages(section: selected),
          if (inlineNotes) notes,
        ],
      ),
    );
    return LayoutBuilder(
      builder: (_, size) {
        if (size.maxWidth < 760) {
          return Column(
            children: [
              SizedBox(height: 160, child: outline),
              const Divider(height: 1),
              Expanded(child: editor(inlineNotes: true)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 210, child: outline),
            const VerticalDivider(width: 1),
            Expanded(child: editor(inlineNotes: size.maxWidth < 1180)),
            if (size.maxWidth >= 1180) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: notes,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _privateNotes(PreparationMap section) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Row(
        children: [
          Icon(Icons.lock_outline, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hỗ trợ giáo viên',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text('Riêng tư · ${section['title'] ?? 'Phần đang chọn'}'),
      const SizedBox(height: 8),
      const Text('Tự hiện khi dạy đến phần này. Không đưa vào PDF học sinh.'),
      const SizedBox(height: 16),
      PreparationField(
        key: ValueKey('note-${section['id']}'),
        label: 'Lời nhắc, ví dụ hoặc đáp án riêng',
        value: '${section['teacherNotes'] ?? ''}',
        lines: 5,
        onChanged: (value) => _editRow('sections', 'teacherNotes', value),
      ),
      const Text(
        'Ví dụ: Dừng lại hỏi cả lớp; chờ 20 giây; nhắc lỗi thường gặp trước khi giải đáp.',
      ),
    ],
  );

  Widget _startDesk() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chuẩn bị bài giảng tiếp theo',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Soạn một tiết học, một buổi seminar hoặc thuyết trình. Bắt đầu từ nội dung bạn đang có; không cần điền đủ một mẫu giáo án.',
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Tự soạn nội dung'),
              subtitle: const Text(
                'Thêm phần đầu tiên rồi viết nội dung và lời nhắc riêng.',
              ),
              onTap: _addSection,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Dùng tài liệu có sẵn'),
              subtitle: const Text(
                'Thêm PDF, hình ảnh hoặc bản ghi. PDF được chuẩn bị trên bảng, không tự trích chữ.',
              ),
              onTap: _pickFile,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Dùng lại bài cũ'),
              subtitle: const Text(
                'Chọn bài đã có, nhân bản hoặc tạo biến thể theo lớp.',
              ),
              onTap: _reusePlanning,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _previewLesson() async {
    final student = c.document.studentProjection();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 1000,
          height: 650,
          child: Column(
            children: [
              ListTile(
                title: const Text('Xem trước nội dung — bản tóm tắt'),
                subtitle: const Text(
                  'Đối chiếu nội dung theo đối tượng. Bản PDF thực tế còn áp dụng mẫu trường/khoa.',
                ),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Học sinh'),
                          Tab(text: 'Giáo viên — riêng tư'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            for (final teacher in [false, true])
                              ListView(
                                padding: const EdgeInsets.all(24),
                                children: [
                                  Text(
                                    c.document.title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  for (final section
                                      in teacher
                                          ? c.document.rows('sections')
                                          : preparationRows(
                                              student['sections'],
                                            )) ...[
                                    const SizedBox(height: 20),
                                    Text(
                                      '${section['title'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText('${section['body'] ?? ''}'),
                                    ..._previewSectionExtras(section, teacher),
                                    if (teacher &&
                                        '${section['teacherNotes'] ?? ''}'
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          '🔒 Lời nhắc riêng: ${section['teacherNotes']}',
                                        ),
                                      ),
                                  ],
                                  if (teacher)
                                    for (final cue in c.document.rows(
                                      'teacherCues',
                                    ))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          'Lời nhắc trang (riêng tư): ${cue['text'] ?? ''}',
                                        ),
                                      ),
                                  if (c.document.rows('sections').isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 24),
                                      child: Text(
                                        'Chưa có phần nội dung. Tài liệu PDF/bảng được xem từ Chuẩn bị bảng trình chiếu.',
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _workspaceAction('export_template');
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Xem trước PDF xuất thật'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _previewSectionExtras(PreparationMap section, bool teacher) => [
    if ('${section['objective'] ?? ''}'.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Mục tiêu: ${section['objective']}'),
      ),
    for (final activity in preparationRows(section['activities']))
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${activity['title'] ?? 'Hoạt động'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('${activity['studentAction'] ?? ''}'),
            if (teacher && '${activity['teacherAction'] ?? ''}'.isNotEmpty)
              Text('Riêng giáo viên: ${activity['teacherAction']}'),
          ],
        ),
      ),
    for (final card in preparationRows(section['supportCards']))
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ('${card['publicText'] ?? ''}'.isNotEmpty)
              Text('${card['publicText']}'),
            if (teacher && '${card['teacherText'] ?? ''}'.isNotEmpty)
              Text('Hỗ trợ riêng giáo viên: ${card['teacherText']}'),
          ],
        ),
      ),
    PreparationQuestionImages(section: section, teacherAudience: teacher),
  ];
}
