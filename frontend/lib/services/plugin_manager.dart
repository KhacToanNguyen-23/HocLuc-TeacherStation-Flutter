import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plugin_manifest.dart';
import '../models/subject_plugin.dart';
import 'plugin_storage_manager.dart';
import 'process_supervisor.dart';

class InstalledPlugin extends SubjectPlugin {
  InstalledPlugin({
    required this.manifest,
    this.installDirectory,
    this.sourceFilename = '',
    Map<String, Uint8List>? files,
  }) : files = files ?? const {};

  final PluginManifest manifest;
  final Directory? installDirectory;
  final String sourceFilename;
  final Map<String, Uint8List> files;

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
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (installDirectory != null) {
      final f = File('${installDirectory!.path}/$cleanPath');
      if (f.existsSync()) return f.readAsStringSync();
    }
    final bytes = files[cleanPath] ?? files['/$cleanPath'];
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  Uint8List? getFileBytes(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (installDirectory != null) {
      final f = File('${installDirectory!.path}/$cleanPath');
      if (f.existsSync()) return f.readAsBytesSync();
    }
    return files[cleanPath] ?? files['/$cleanPath'];
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

  List<SubjectPlugin> get availablePlugins => _registry.values.toList();

  List<SubjectPlugin> get installedPlugins =>
      _registry.values.where((p) => _installedPluginIds.contains(p.id)).toList();

  InstalledPlugin? getPlugin(String id) => _installedPackages[id];

  /// Initialize manager, restore saved installed plugin IDs and scan local cache.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_kInstalledPluginsKey) ?? [];
      _installedPluginIds
        ..clear()
        ..addAll(savedIds);

      // Auto discover previously installed plugins in AppData cache
      for (final id in savedIds) {
        final dir = PluginStorageManager.instance.getInstalledDirectory(id);
        if (dir != null) {
          final manifest = PluginStorageManager.instance.loadManifestFromDir(dir);
          if (manifest != null) {
            final installed = InstalledPlugin(
              manifest: manifest,
              installDirectory: dir,
            );
            _installedPackages[id] = installed;
            _registry[id] = installed;
          }
        }
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[PluginManager] Error initializing: $e');
    }
  }

  void registerPlugin(SubjectPlugin plugin) {
    _registry[plugin.id] = plugin;
    notifyListeners();
  }

  bool isInstalled(String id) => _installedPluginIds.contains(id);

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

  Future<void> uninstall(String id) async {
    final plugin = _registry[id];
    if (!_installedPluginIds.contains(id)) return;

    await uninstallPlugin(id);
    if (plugin != null) {
      try {
        await plugin.onUninstall();
      } catch (e) {
        debugPrint('[PluginManager] onUninstall error for $id: $e');
      }
    }
    notifyListeners();
  }

  /// Open/Launch a plugin to be active in the studio, starting sidecar if needed.
  void openPlugin(SubjectPlugin plugin) {
    _activePlugin = plugin;

    if (plugin is InstalledPlugin && plugin.installDirectory != null) {
      if (plugin.manifest.hasSidecar) {
        ProcessSupervisor.instance.startSidecar(
          manifest: plugin.manifest,
          pluginDirectory: plugin.installDirectory!.path,
        );
      }
    }
    notifyListeners();
  }

  /// Close currently active plugin and shut down its sidecar process.
  void closeActivePlugin() {
    if (_activePlugin != null) {
      final id = _activePlugin!.id;
      _activePlugin = null;
      ProcessSupervisor.instance.stopSidecar(id);
      notifyListeners();
    }
  }

  /// Install a package by unpacking zip bytes (.hlep) directly to local storage.
  Future<InstalledPlugin> installPluginFromBytes(
    List<int> bytes,
    String filename,
  ) async {
    final targetDir = await PluginStorageManager.instance.installFromZip(
      bytes,
      customFilename: filename,
    );

    final manifest = PluginStorageManager.instance.loadManifestFromDir(targetDir);
    if (manifest == null) {
      throw const FormatException('Không thể đọc tệp manifest.json sau khi giải nén.');
    }

    final installed = InstalledPlugin(
      manifest: manifest,
      installDirectory: targetDir,
      sourceFilename: filename,
    );

    _installedPackages[manifest.id] = installed;
    _registry[manifest.id] = installed;
    _installedPluginIds.add(manifest.id);
    await _persistInstalledIds();
    notifyListeners();
    return installed;
  }

  /// Install sample package found in local directory or plugins/
  Future<InstalledPlugin> installSamplePlugin() async {
    final searchDirs = [
      Directory('plugins'),
      Directory('../plugins'),
      Directory('../../plugins'),
    ];

    for (final dir in searchDirs) {
      if (dir.existsSync()) {
        final hlepFiles = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.hlep'))
            .toList();
        if (hlepFiles.isNotEmpty) {
          final target = hlepFiles.first;
          final filename = target.uri.pathSegments.where((s) => s.isNotEmpty).last;
          return installPluginFromBytes(target.readAsBytesSync(), filename);
        }

        final subDirs = dir.listSync().whereType<Directory>().toList();
        for (final d in subDirs) {
          final manifest = PluginStorageManager.instance.loadManifestFromDir(d);
          if (manifest != null) {
            final segments = d.uri.pathSegments.where((s) => s.isNotEmpty).toList();
            final dirname = segments.isNotEmpty ? segments.last : 'plugin';
            final installed = InstalledPlugin(
              manifest: manifest,
              installDirectory: d,
              sourceFilename: dirname,
            );
            _installedPackages[manifest.id] = installed;
            _registry[manifest.id] = installed;
            _installedPluginIds.add(manifest.id);
            await _persistInstalledIds();
            notifyListeners();
            return installed;
          }
        }
      }
    }

    throw StateError('Không tìm thấy gói hoặc thư mục plugin mẫu.');
  }

  /// Alias for backward compatibility
  Future<InstalledPlugin> installSampleEnglishPlugin() => installSamplePlugin();

  Future<void> uninstallPlugin(String id) async {
    _installedPackages.remove(id);
    _registry.remove(id);
    _installedPluginIds.remove(id);
    if (_activePlugin?.id == id) {
      _activePlugin = null;
    }
    notifyListeners();

    try {
      await ProcessSupervisor.instance.stopSidecar(id);
      await PluginStorageManager.instance.uninstall(id);
      await _persistInstalledIds();
    } catch (e) {
      debugPrint('[PluginManager] Error during async uninstall for $id: $e');
    }
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
