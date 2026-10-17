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

    // Fallback: Check local development workspace folder (e.g. plugins/<plugin_id> or plugins/<folder> with matching manifest.id)
    final devRoots = [
      Directory('plugins'),
      Directory('../plugins'),
      Directory('../../plugins'),
    ];

    for (final rootDir in devRoots) {
      if (!rootDir.existsSync()) continue;
      final direct = Directory('${rootDir.path}/$pluginId');
      if (direct.existsSync() && File('${direct.path}/manifest.json').existsSync()) {
        return direct;
      }
      try {
        for (final subDir in rootDir.listSync().whereType<Directory>()) {
          final m = loadManifestFromDir(subDir);
          if (m != null && m.id == pluginId) {
            return subDir;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Install or update a plugin by unpacking zip/hlep bytes into AppData.
  Future<Directory> installFromZip(List<int> bytes, {String? customFilename}) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? manifestFile;

    // Scan for manifest.json in archive and guard against Zip Slip
    for (final file in archive) {
      final normPath = file.name.replaceAll('\\', '/');
      if (normPath.contains('..') || normPath.startsWith('/')) {
        throw const FormatException(
          'Gói plugin chứa đường dẫn không an toàn (Zip Slip).',
        );
      }
      if (file.isFile) {
        if (normPath == 'manifest.json' || normPath.endsWith('/manifest.json')) {
          manifestFile = file;
        }
      }
    }

    if (manifestFile == null) {
      throw const FormatException('Gói plugin thiếu tệp manifest.json hợp lệ.');
    }

    final manifestStr = utf8.decode(manifestFile.content as List<int>);
    final manifestJson = jsonDecode(manifestStr) as Map<String, dynamic>;
    final manifest = PluginManifest.fromJson(manifestJson);
    if (manifest.id.contains('..') || manifest.id.contains('/') || manifest.id.contains('\\')) {
      throw const FormatException('ID của plugin trong manifest.json không hợp lệ.');
    }

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
        if (relPath.contains('..') || relPath.startsWith('/')) {
          throw const FormatException('Đường dẫn tệp giải nén không hợp lệ.');
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

  /// Read and parse manifest.json from an in-memory zip archive / .hlep package.
  PluginManifest? loadManifestFromZip(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.isFile) {
          final normPath = file.name.replaceAll('\\', '/');
          if (normPath == 'manifest.json' || normPath.endsWith('/manifest.json')) {
            final manifestStr = utf8.decode(file.content as List<int>);
            final manifestJson = jsonDecode(manifestStr) as Map<String, dynamic>;
            return PluginManifest.fromJson(manifestJson);
          }
        }
      }
    } catch (e) {
      debugPrint('[PluginStorageManager] Error reading manifest from zip: $e');
    }
    return null;
  }
}
