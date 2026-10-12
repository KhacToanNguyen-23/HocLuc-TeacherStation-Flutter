import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../models/plugin_manifest.dart';

class InstalledPlugin {
  InstalledPlugin({
    required this.manifest,
    required this.files,
    this.sourceFilename = '',
  });

  final PluginManifest manifest;
  final Map<String, Uint8List> files;
  final String sourceFilename;

  String? getFileString(String path) {
    final bytes = files[path] ?? files['/$path'];
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  Uint8List? getFileBytes(String path) {
    return files[path] ?? files['/$path'];
  }
}

class PluginManager extends ChangeNotifier {
  PluginManager();

  static final PluginManager instance = PluginManager();

  final Map<String, InstalledPlugin> _plugins = {};

  List<InstalledPlugin> get installedPlugins => _plugins.values.toList();

  InstalledPlugin? getPlugin(String id) => _plugins[id];

  Future<InstalledPlugin> installPluginFromBytes(
    List<int> bytes,
    String filename,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? manifestFile;
    final filesMap = <String, Uint8List>{};

    for (final file in archive) {
      if (file.isFile) {
        final path = file.name.replaceAll('\\', '/');
        final content = file.content as List<int>;
        filesMap[path] = Uint8List.fromList(content);
        if (path == 'manifest.json' || path.endsWith('/manifest.json')) {
          manifestFile = file;
        }
      }
    }

    if (manifestFile == null) {
      throw const FormatException('Gói plugin thiếu tệp manifest.json');
    }

    final manifestJsonStr = utf8.decode(manifestFile.content as List<int>);
    final manifestJson = jsonDecode(manifestJsonStr) as Map<String, dynamic>;
    final manifest = PluginManifest.fromJson(manifestJson);

    final installed = InstalledPlugin(
      manifest: manifest,
      files: filesMap,
      sourceFilename: filename,
    );

    _plugins[manifest.id] = installed;
    notifyListeners();
    return installed;
  }

  Future<InstalledPlugin> installSampleEnglishPlugin() async {
    final archive = Archive();
    final manifestJson = jsonEncode({
      'id': 'com.hocluc.plugin.english',
      'name': 'Trợ giảng Tiếng Anh',
      'version': '1.0.0',
      'author': 'Học Lực Studio',
      'description':
          'Bóc tách S-V-O và bắt lỗi thì/ngữ pháp bằng spaCy & LanguageTool.',
      'main': 'ui/index.html',
      'icon': 'icon.png',
      'placement': 'drawer_panel',
      'default_width': 420,
      'backend': {
        'type': 'python',
        'entry': 'engine/service.py',
        'port': 18888,
        'health_endpoint': '/health',
      },
      'permissions': ['board:insert_annotation', 'board:read_text'],
    });

    const indexHtml = '''<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <title>Trợ giảng Tiếng Anh</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="header">
    <h3>🇬🇧 Trợ Giảng Tiếng Anh</h3>
    <span class="badge">S-V-O + Grammar</span>
  </div>
  <textarea id="inputSentence" placeholder="Nhập câu tiếng Anh cần giảng giải... (ví dụ: The smart student reads a book eagerly in the classroom.)"></textarea>
  <div class="actions">
    <button id="btnAnalyze" class="btn-primary">⚡ Phân tích cú pháp</button>
  </div>
  <div id="results" class="results-box"></div>
  <button id="btnPinToBoard" class="btn-pin" style="display:none;">📌 Ghim lên bảng phấn</button>
  <script src="app.js"></script>
</body>
</html>''';

    const appJs = '''
const input = document.getElementById('inputSentence');
const btnAnalyze = document.getElementById('btnAnalyze');
const btnPin = document.getElementById('btnPinToBoard');
const resultsBox = document.getElementById('results');

let currentAnalysis = null;

btnAnalyze?.addEventListener('click', async () => {
  const text = input.value.trim();
  if (!text) return;
  // Offline / Demo parsing logic
  const words = text.split(/\\s+/);
  const tokens = words.map((w, i) => {
    const clean = w.replace(/[^a-zA-Z]/g, '');
    let role = null;
    if (i === 0 || clean.toLowerCase() === 'student' || clean.toLowerCase() === 'teacher') role = 'subject';
    else if (clean.toLowerCase() === 'reads' || clean.toLowerCase() === 'writes' || clean.toLowerCase() === 'teaches') role = 'verb';
    else if (clean.toLowerCase() === 'book' || clean.toLowerCase() === 'lesson') role = 'object';
    return { text: w, role: role };
  });
  currentAnalysis = {
    text: text,
    tokens: tokens,
    grammarIssue: 'Sentence is grammatically sound.'
  };
  resultsBox.innerHTML = '<p><b>Đã phân tích thành công!</b></p>';
  btnPin.style.display = 'block';
});

btnPin?.addEventListener('click', () => {
  if (!currentAnalysis) return;
  const msg = {
    type: 'INSERT_ANNOTATION',
    action: 'INSERT_ANNOTATION',
    pluginId: 'com.hocluc.plugin.english',
    text: currentAnalysis.text,
    tokens: currentAnalysis.tokens,
    grammarIssue: currentAnalysis.grammarIssue
  };
  if (window.chrome && window.chrome.webview) {
    window.chrome.webview.postMessage(msg);
  }
  if (window.parent) {
    window.parent.postMessage(msg, '*');
  }
});
''';

    archive.addFile(
      ArchiveFile(
        'manifest.json',
        manifestJson.length,
        utf8.encode(manifestJson),
      ),
    );
    archive.addFile(
      ArchiveFile('ui/index.html', indexHtml.length, utf8.encode(indexHtml)),
    );
    archive.addFile(ArchiveFile('ui/app.js', appJs.length, utf8.encode(appJs)));
    archive.addFile(ArchiveFile('icon.png', 4, [0x89, 0x50, 0x4E, 0x47]));

    final zipBytes = ZipEncoder().encode(archive);
    return installPluginFromBytes(zipBytes, 'english_assistant.hlep');
  }

  void uninstallPlugin(String id) {
    if (_plugins.containsKey(id)) {
      _plugins.remove(id);
      notifyListeners();
    }
  }

  String? getFileString(String pluginId, String relativePath) {
    return _plugins[pluginId]?.getFileString(relativePath);
  }

  Uint8List? getFileBytes(String pluginId, String relativePath) {
    return _plugins[pluginId]?.getFileBytes(relativePath);
  }
}
