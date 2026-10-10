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
