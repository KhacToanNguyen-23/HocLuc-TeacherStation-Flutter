import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../models/plugin_manifest.dart';

/// Manages physical storage, extraction, on-disk caching and uninstallation of plugins.
class PluginStorageManager {
  static final PluginStorageManager _instance = PluginStorageManager._internal();
  factory PluginStorageManager() => _instance;
  PluginStorageManager._internal();

  static PluginStorageManager get instance => _instance;

  Directory? _customBaseDirectory;

  @visibleForTesting
  void setBaseDirectoryForTesting(Directory dir) {
    _customBaseDirectory = dir;
  }

  /// Resolve root plugins directory in user's AppData or Local directory.
  Directory getPluginsRootDirectory() {
    if (_customBaseDirectory != null) return _customBaseDirectory!;

    if (kIsWeb) {
      return Directory('/plugins');
    }

    String basePath;
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          '${Platform.environment['USERPROFILE']}\\AppData\\Local';
      basePath = '$localAppData\\HocLuc\\plugins';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      basePath = '$home/Library/Application Support/HocLuc/plugins';
    } else {
      final home = Platform.environment['HOME'] ?? '';
      basePath = '$home/.local/share/hocluc/plugins';
    }

    final dir = Directory(basePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Get the installed directory for a specific plugin if it exists.
  Directory? getInstalledDirectory(String pluginId, {String? version}) {
    if (kIsWeb) return null;

    final root = getPluginsRootDirectory();
    final pluginFolder = Directory('${root.path}/$pluginId');

    if (pluginFolder.existsSync()) {
      if (version != null) {
        final versionFolder = Directory('${pluginFolder.path}/v$version');
        if (versionFolder.existsSync()) return versionFolder;
      }

      // Check subdirectories for version folders or manifest
      final manifestInRoot = File('${pluginFolder.path}/manifest.json');
      if (manifestInRoot.existsSync()) return pluginFolder;

      final subDirs = pluginFolder.listSync().whereType<Directory>().toList();
      if (subDirs.isNotEmpty) {
        // Return latest version folder
        subDirs.sort((a, b) => b.path.compareTo(a.path));
        return subDirs.first;
      }
    }

    // Fallback: Check local development workspace folder (e.g. plugins/<plugin_id>)
    final devCandidates = [
      Directory('plugins/$pluginId'),
      Directory('../plugins/$pluginId'),
      Directory('../../plugins/$pluginId'),
    ];

    for (final d in devCandidates) {
      if (d.existsSync() && File('${d.path}/manifest.json').existsSync()) {
        return d;
      }
    }

    return null;
  }

  /// Install or update a plugin by unpacking zip/hlep bytes into AppData.
  Future<Directory> installFromZip(List<int> bytes, {String? customFilename}) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? manifestFile;

    // Scan for manifest.json in archive
    for (final file in archive) {
      if (file.isFile) {
        final normPath = file.name.replaceAll('\\', '/');
        if (normPath == 'manifest.json' || normPath.endsWith('/manifest.json')) {
          manifestFile = file;
          break;
        }
      }
    }

    if (manifestFile == null) {
      throw const FormatException('Gói plugin thiếu tệp manifest.json hợp lệ.');
    }

    final manifestStr = utf8.decode(manifestFile.content as List<int>);
    final manifestJson = jsonDecode(manifestStr) as Map<String, dynamic>;
    final manifest = PluginManifest.fromJson(manifestJson);

    final root = getPluginsRootDirectory();
    final targetDir = Directory('${root.path}/${manifest.id}/v${manifest.version}');

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    // Extract all files to disk
    for (final file in archive) {
      if (file.isFile) {
        var relPath = file.name.replaceAll('\\', '/');
        // Strip top-level directory if archive has wrapper root
        if (relPath.startsWith('${manifest.id}/')) {
          relPath = relPath.substring('${manifest.id}/'.length);
        }

        final outPath = '${targetDir.path}/$relPath';
        final outFile = File(outPath);
        if (!outFile.parent.existsSync()) {
          outFile.parent.createSync(recursive: true);
        }
        outFile.writeAsBytesSync(file.content as List<int>);
      }
    }

    debugPrint('[PluginStorageManager] Extracted ${manifest.id} v${manifest.version} to ${targetDir.path}');
    return targetDir;
  }

  /// Uninstall a plugin by completely removing its directory from disk.
  Future<void> uninstall(String pluginId) async {
    final root = getPluginsRootDirectory();
    final pluginFolder = Directory('${root.path}/$pluginId');
    if (pluginFolder.existsSync()) {
      await pluginFolder.delete(recursive: true);
      debugPrint('[PluginStorageManager] Deleted plugin directory: ${pluginFolder.path}');
    }
  }

  /// Read and parse manifest.json from a physical directory.
  PluginManifest? loadManifestFromDir(Directory dir) {
    try {
      final manifestFile = File('${dir.path}/manifest.json');
      if (!manifestFile.existsSync()) return null;
      final jsonStr = manifestFile.readAsStringSync();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PluginManifest.fromJson(map);
    } catch (e) {
      debugPrint('[PluginStorageManager] Error reading manifest from ${dir.path}: $e');
      return null;
    }
  }
}
