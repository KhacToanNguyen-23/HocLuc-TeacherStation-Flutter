import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plugin_manifest.dart';
import '../models/subject_plugin.dart';

class InstalledPlugin extends SubjectPlugin {
  InstalledPlugin({
    required this.manifest,
    required this.files,
    this.sourceFilename = '',
  });

  final PluginManifest manifest;
  final Map<String, Uint8List> files;
  final String sourceFilename;

  @override
  String get id => manifest.id;

  @override
  String get name => manifest.name;

  @override
  String get summary => manifest.description;

  @override
  IconData get icon => Icons.extension_rounded;

  @override
  Color get color => const Color(0xFF0284C7);

  @override
  Widget buildWidget(BuildContext context) {
    return const SizedBox.shrink();
  }

  String? getFileString(String path) {
    final bytes = files[path] ?? files['/$path'];
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  Uint8List? getFileBytes(String path) {
    return files[path] ?? files['/$path'];
  }
}

/// Central Microkernel Registry & Lifecycle Manager for Subject Plugins & Packages.
class PluginManager extends ChangeNotifier {
  static final PluginManager _instance = PluginManager._internal();
  factory PluginManager() => _instance;
  PluginManager._internal();

  static PluginManager get instance => _instance;

  static const _kInstalledPluginsKey = 'installed_subject_plugin_ids';

  final Map<String, SubjectPlugin> _registry = {};
  final Map<String, InstalledPlugin> _installedPackages = {};
  final Set<String> _installedPluginIds = {};
  SubjectPlugin? _activePlugin;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  SubjectPlugin? get activePlugin => _activePlugin;

  /// All registered plugins available for installation
  List<SubjectPlugin> get availablePlugins => _registry.values.toList();

  /// Plugins currently installed by the teacher
  List<SubjectPlugin> get installedPlugins =>
      _registry.values.where((p) => _installedPluginIds.contains(p.id)).toList();

  InstalledPlugin? getPlugin(String id) => _installedPackages[id];

  /// Initialize manager and load saved installed plugin IDs
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_kInstalledPluginsKey) ?? [];
      _installedPluginIds
        ..clear()
        ..addAll(savedIds);
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[PluginManager] Error initializing: $e');
    }
  }

  /// Register a real SubjectPlugin into the system
  void registerPlugin(SubjectPlugin plugin) {
    _registry[plugin.id] = plugin;
    notifyListeners();
  }

  /// Check if a plugin is currently installed
  bool isInstalled(String id) => _installedPluginIds.contains(id);

  /// Install a plugin by ID
  Future<void> install(String id) async {
    final plugin = _registry[id];
    if (plugin == null || _installedPluginIds.contains(id)) return;

    _installedPluginIds.add(id);
    await _persistInstalledIds();
    try {
      await plugin.onInstall();
    } catch (e) {
      debugPrint('[PluginManager] onInstall error for $id: $e');
    }
    notifyListeners();
  }

  /// Uninstall a plugin by ID
  Future<void> uninstall(String id) async {
    final plugin = _registry[id];
    if (!_installedPluginIds.contains(id)) return;

    _installedPluginIds.remove(id);
    if (_activePlugin?.id == id) {
      _activePlugin = null;
    }
    await _persistInstalledIds();
    if (plugin != null) {
      try {
        await plugin.onUninstall();
      } catch (e) {
        debugPrint('[PluginManager] onUninstall error for $id: $e');
      }
    }
    notifyListeners();
  }

  /// Open/Launch a plugin to be active in the studio
  void openPlugin(SubjectPlugin plugin) {
    _activePlugin = plugin;
    notifyListeners();
  }

  /// Close currently active plugin
  void closeActivePlugin() {
    _activePlugin = null;
    notifyListeners();
  }

  /// Install a package from in-memory zip bytes (.hlep)
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

    _installedPackages[manifest.id] = installed;
    _registry[manifest.id] = installed;
    _installedPluginIds.add(manifest.id);
    notifyListeners();
    return installed;
  }

  Future<InstalledPlugin> installSampleEnglishPlugin() async {
    final archive = Archive();
    final manifestJson = jsonEncode({
      'id': 'com.hocluc.plugin.english',
      'name': 'Trợ giảng Tiếng Anh',
      'version': '1.1.0',
      'author': 'Học Lực Studio',
      'description':
          'Bóc tách Cú pháp S-V-O, Phân tích Ngữ liệu chuẩn đề ĐGNL và Tạo bài tập Cloze Test.',
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

    // Check if real ui/index.html & ui/app.js can be read from disk
    String? indexHtmlContent;
    String? appJsContent;
    String? styleCssContent;

    if (!kIsWeb) {
      final htmlCandidates = [
        File('../plugins/english_assistant/ui/index.html'),
        File('plugins/english_assistant/ui/index.html'),
      ];
      for (final f in htmlCandidates) {
        if (f.existsSync()) {
          indexHtmlContent = f.readAsStringSync();
          break;
        }
      }

      final jsCandidates = [
        File('../plugins/english_assistant/ui/app.js'),
        File('plugins/english_assistant/ui/app.js'),
      ];
      for (final f in jsCandidates) {
        if (f.existsSync()) {
          appJsContent = f.readAsStringSync();
          break;
        }
      }

      final cssCandidates = [
        File('../plugins/english_assistant/ui/style.css'),
        File('plugins/english_assistant/ui/style.css'),
      ];
      for (final f in cssCandidates) {
        if (f.existsSync()) {
          styleCssContent = f.readAsStringSync();
          break;
        }
      }
    }

    const defaultIndexHtml = '''<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <title>Trợ giảng Tiếng Anh</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="header">
    <h3>🇬🇧 Trợ Giảng Tiếng Anh</h3>
    <span class="badge">S-V-O & ĐGNL 1.1.0</span>
  </div>
  <div class="tabs-nav">
    <button id="tabBtnSvo" class="tab-button active">🔤 Cú pháp S-V-O</button>
    <button id="tabBtnDgnl" class="tab-button">🎯 Ôn thi ĐGNL & Cloze</button>
  </div>
  <textarea id="inputSentence" placeholder="Nhập câu tiếng Anh cần giảng giải..."></textarea>
  <div class="actions">
    <button id="btnAnalyze" class="btn-primary">⚡ Phân tích</button>
  </div>
  <div id="results" class="results-box"></div>
  <button id="btnPinToBoard" class="btn-pin" style="display:none;">📌 Ghim lên bảng phấn</button>
  <script src="app.js"></script>
</body>
</html>''';

    final finalIndexHtml = indexHtmlContent ?? defaultIndexHtml;
    final finalAppJs = appJsContent ?? '// english assistant app.js';
    final finalStyleCss = styleCssContent ?? 'body { font-family: sans-serif; }';

    archive.addFile(
      ArchiveFile(
        'manifest.json',
        manifestJson.length,
        utf8.encode(manifestJson),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'ui/index.html',
        finalIndexHtml.length,
        utf8.encode(finalIndexHtml),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'ui/app.js',
        finalAppJs.length,
        utf8.encode(finalAppJs),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'ui/style.css',
        finalStyleCss.length,
        utf8.encode(finalStyleCss),
      ),
    );
    archive.addFile(ArchiveFile('icon.png', 4, [0x89, 0x50, 0x4E, 0x47]));

    final zipBytes = ZipEncoder().encode(archive);
    return installPluginFromBytes(zipBytes, 'english_assistant.hlep');
  }

  void uninstallPlugin(String id) {
    _installedPackages.remove(id);
    _registry.remove(id);
    _installedPluginIds.remove(id);
    if (_activePlugin?.id == id) {
      _activePlugin = null;
    }
    notifyListeners();
  }

  String? getFileString(String pluginId, String relativePath) {
    return _installedPackages[pluginId]?.getFileString(relativePath);
  }

  Uint8List? getFileBytes(String pluginId, String relativePath) {
    return _installedPackages[pluginId]?.getFileBytes(relativePath);
  }

  @visibleForTesting
  void resetForTesting() {
    _registry.clear();
    _installedPackages.clear();
    _installedPluginIds.clear();
    _activePlugin = null;
    _isInitialized = false;
  }

  Future<void> _persistInstalledIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kInstalledPluginsKey, _installedPluginIds.toList());
    } catch (e) {
      debugPrint('[PluginManager] Error persisting installed plugins: $e');
    }
  }
}
