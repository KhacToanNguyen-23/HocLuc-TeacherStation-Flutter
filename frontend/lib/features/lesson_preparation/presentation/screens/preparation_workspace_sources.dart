part of 'preparation_workspace_screen.dart';

extension _WorkspaceSources on _WorkspaceState {
  Future<void> _authorWithApi() async {
    final selectedText = _input.trim();
    if (selectedText.isEmpty) return;
    final author = c.capabilities['authoring'] is Map
        ? Map<String, dynamic>.from(c.capabilities['authoring'] as Map)
        : <String, dynamic>{};
    if (author['ready'] != true) {
      await _settings();
      return;
    }
    final confirmed = await PreparationAuthoringConsent.confirm(
      context,
      capabilities: c.capabilities,
      text: selectedText,
    );
    if (!confirmed || !mounted) return;
    await _run(
      'author',
      options: {
        'text': selectedText,
        'inputMode': 'prompt',
        'language': 'en',
        'cloudConfirmed': true,
        'expectedAuthoringBaseUrl': author['baseUrl'],
        'expectedAuthoringModel': author['model'],
      },
    );
  }

  Future<void> _extractFrame(PreparationMap source) async {
    final second = await showDialog<double>(
      context: context,
      builder: (_) => PreparationFrameDialog(
        onPreview: (second) => _preview(source, initialPosition: second),
      ),
    );
    if (second == null || !mounted) return;
    await _perform(() async {
      await c.api.post('${c.path}/frames', {
        'sourceAssetId': source['id'],
        'second': second,
      });
      final fresh = await c.api.get(c.path) as Map;
      final doc = fresh['document'] is Map ? fresh['document'] as Map : fresh;
      c.document.data['sources'] = doc['sources'];
      c.emit();
    });
  }

  Future<void> _transcribeSource(PreparationMap source) async {
    final range = await showDialog<PreparationMap>(
      context: context,
      builder: (_) => PreparationTranscriptionDialog(
        sourceName: '${source['name'] ?? 'Nguồn đã chọn'}',
        onPreview: (seconds) => _preview(source, initialPosition: seconds),
      ),
    );
    if (range == null || !mounted) return;
    await _run(
      'transcribe',
      options: {'sourceId': source['id'], 'language': 'vi', ...range},
    );
  }

  Future<void> _deleteSource(PreparationMap source) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nguồn chưa dùng?'),
        content: Text(
          'Xóa ${source['name'] ?? 'file'} khỏi bài và ổ đĩa. File đang dùng trong bài, phiên bản hoặc tác vụ sẽ được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa nguồn'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _perform(() async {
      await c.save();
      if (c.dirty || c.conflict) {
        throw StateError('Cần lưu bài trước khi xóa nguồn.');
      }
      await c.api.request(
        'assets/${Uri.encodeComponent('${source['id']}')}',
        'DELETE',
      );
      final fresh = await c.api.get(c.path) as Map;
      final document = fresh['document'] is Map
          ? fresh['document'] as Map
          : fresh;
      c.document.data['sources'] = document['sources'];
      c.emit();
    });
  }

  Widget _sources() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Thêm nội dung vào bài',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn loại nội dung bạn đang có. Văn bản có thể đưa vào phần đang soạn; PDF chuẩn bị trên bảng; bản ghi có thể chép lời rồi duyệt.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in const [
                  (0, 'Văn bản'),
                  (1, 'Tài liệu / bản ghi'),
                  (2, 'Ghi âm'),
                  (3, 'AI gợi ý'),
                ])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: _sourceMode == item.$1,
                    onSelected: (_) =>
                        _refreshWorkspace(() => _sourceMode = item.$1),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_sourceMode == 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Chọn tài liệu, hình ảnh hoặc bản ghi'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final source in c.document.rows('sources'))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${source['name'] ?? source['id']}'),
                  subtitle: Text('${source['mimeType'] ?? ''}'),
                  onTap: () => _preview(source),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (source['mimeType'] == 'video/mp4')
                        IconButton(
                          tooltip: 'Trích ảnh tại mốc video',
                          icon: const Icon(Icons.photo_camera_outlined),
                          onPressed: _busy ? null : () => _extractFrame(source),
                        ),
                      if ('${source['mimeType']}'.contains('pdf') ||
                          '${source['mimeType']}'.startsWith('video/') ||
                          '${source['mimeType']}'.startsWith('audio/'))
                        IconButton(
                          tooltip: '${source['mimeType']}'.contains('pdf')
                              ? 'Đưa PDF lên bảng chuẩn bị'
                              : 'Chép lời bản ghi tiếng Việt',
                          icon: Icon(
                            '${source['mimeType']}'.contains('pdf')
                                ? Icons.edit_document
                                : Icons.transcribe,
                          ),
                          onPressed: () =>
                              '${source['mimeType']}'.contains('pdf')
                              ? _openPdf(source)
                              : _transcribeSource(source),
                        ),
                      IconButton(
                        tooltip: 'Xóa nguồn chưa dùng',
                        onPressed: _busy ? null : () => _deleteSource(source),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
            ],
            if (_sourceMode == 2)
              PreparationRecordingControl(controller: c, onRecorded: _update),
            if (_sourceMode == 0 || _sourceMode == 3) ...[
              const Divider(height: 32),
              PreparationField(
                label: 'Văn bản có sẵn hoặc ý tưởng bài giảng',
                value: _input,
                lines: 6,
                onChanged: (v) {
                  c.change((d) => d.data['sourceScript'] = v);
                },
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _input.trim().isEmpty
                        ? null
                        : () => _insertText(_input),
                    child: const Text('Đưa văn bản vào bài'),
                  ),
                  OutlinedButton(
                    onPressed: () => _addScene(_input),
                    child: const Text('Tạo một cảnh video từ văn bản'),
                  ),
                  OutlinedButton(
                    onPressed: () => _run(
                      'author',
                      options: {
                        'text': _input,
                        'inputMode': 'script',
                        'language': 'en',
                      },
                    ),
                    child: const Text('Chia văn bản thành các cảnh video'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _authorWithApi,
                    child: const Text('AI đề xuất bài / storyboard'),
                  ),
                  OutlinedButton(
                    onPressed: () => _run(
                      'translate',
                      options: {'text': _input, 'language': 'vi'},
                    ),
                    child: const Text('Dịch Việt → Anh'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (_transcript.isNotEmpty ||
                c.document.rows('transcriptSegments').isNotEmpty) ...[
              if (c.document.rows('transcriptSegments').isNotEmpty)
                PreparationTranscriptEditor(
                  segments: c.document.rows('transcriptSegments'),
                  onChanged: (rows) =>
                      c.change((d) => d.data['transcriptSegments'] = rows),
                  onSeek: (seconds) {
                    final rows = c.document.rows('sources');
                    final id = c.document.data['transcriptSourceId'];
                    final source = rows.where((r) => r['id'] == id).firstOrNull;
                    if (source != null) {
                      _preview(source, initialPosition: seconds);
                    }
                  },
                ),
              PreparationField(
                label: 'Lời chép từ bản ghi — kiểm tra và sửa trước khi dùng',
                value: _transcript.isNotEmpty
                    ? _transcript
                    : '${c.document.data['transcriptText'] ?? ''}',
                lines: 7,
                onChanged: (v) {
                  c.change((d) => d.data['transcriptText'] = v);
                },
              ),
              TextButton(
                onPressed: () => _insertText(
                  _transcript.isNotEmpty
                      ? _transcript
                      : '${c.document.data['transcriptText'] ?? ''}',
                ),
                child: const Text('Đưa lời chép đã sửa vào bài'),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'AI sinh giáo án gửi nội dung đã xác nhận đến API bên thứ ba. STT, dịch, giọng đọc và chia script thành cảnh vẫn xử lý trên máy.',
            ),
          ],
        ),
      ),
    ),
  );
}
