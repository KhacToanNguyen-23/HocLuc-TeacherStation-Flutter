import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/subject_plugin.dart';
import 'plugin_marketplace_service.dart';
import 'plugin_storage_manager.dart';
import 'plugin_web_server.dart';
import 'process_supervisor.dart';

class InstalledPlugin extends SubjectPlugin {
  InstalledPlugin({
    required this.manifest,
    this.installDirectory,
    this.sourceFilename = '',
    this.sourceFile,
    this.catalogItem,
    this.isDevelopmentSource = false,
  });

  final PluginManifest manifest;
  final Directory? installDirectory;
  final String sourceFilename;
  final File? sourceFile;
  final PluginCatalogItem? catalogItem;
  final bool isDevelopmentSource;

  /// Returns local icon file from extracted plugin folder if available.
  File? get iconFile {
    if (installDirectory == null || manifest.iconPath.isEmpty) return null;
    final cleanIcon = manifest.iconPath.startsWith('/')
        ? manifest.iconPath.substring(1)
        : manifest.iconPath;
    final f = File('${installDirectory!.path}/$cleanIcon');
    return f.existsSync() ? f : null;
  }

  @override
  String get id => manifest.id;

  @override
  String get name => manifest.name;

  @override
  String get summary => manifest.description;

  @override
  IconData get icon {
    switch (manifest.category.toLowerCase()) {
      case 'math':
        return Icons.calculate_rounded;
      case 'languages':
        return Icons.translate_rounded;
      case 'science':
        return Icons.science_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  @override
  Color get color {
    switch (manifest.category.toLowerCase()) {
      case 'math':
        return const Color(0xFF10B981);
      case 'languages':
        return const Color(0xFF6366F1);
      case 'science':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF0284C7);
    }
  }

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
    return null;
  }

  Uint8List? getFileBytes(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (installDirectory != null) {
      final f = File('${installDirectory!.path}/$cleanPath');
      if (f.existsSync()) return f.readAsBytesSync();
    }
    return null;
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
  final Map<String, PluginCatalogItem> _remoteCatalog = {};
  final Set<String> _installedPluginIds = {};
  final Set<String> _downloadingIds = {};
  SubjectPlugin? _activePlugin;
  bool _isInitialized = false;
  bool _isSyncingCatalog = false;

  bool get isInitialized => _isInitialized;
  bool get isSyncingCatalog => _isSyncingCatalog;
  SubjectPlugin? get activePlugin => _activePlugin;

  List<SubjectPlugin> get availablePlugins => _registry.values.toList();

  List<SubjectPlugin> get installedPlugins => _registry.values
      .where((p) => _installedPluginIds.contains(p.id))
      .toList();

  InstalledPlugin? getPlugin(String id) => _installedPackages[id];
  PluginCatalogItem? getCatalogItem(String id) => _remoteCatalog[id];
  bool isDownloading(String id) => _downloadingIds.contains(id);

  /// Returns true if the remote Marketplace catalog has a newer version than the locally installed plugin.
  bool hasUpdate(String id) {
    final installed = _installedPackages[id];
    final remote = _remoteCatalog[id];
    if (installed == null || remote == null) return false;
    return installed.manifest.version != remote.version;
  }

  /// Initialize manager, restore saved installed plugin IDs, scan local cache and discover available packages.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_kInstalledPluginsKey) ?? [];
      _installedPluginIds
        ..clear()
        ..addAll(savedIds);

      // 1. Auto restore previously installed plugins in AppData cache
      for (final id in savedIds) {
        final dir = PluginStorageManager.instance.getInstalledDirectory(id);
        if (dir != null) {
          final manifest = PluginStorageManager.instance.loadManifestFromDir(
            dir,
          );
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

      // 2. Dynamically scan search directories for all available plugins (.hlep or directory)
      await discoverAvailablePlugins();

      // 3. Start internal loopback server for zero-CORS plugin web assets
      if (!kIsWeb) {
        try {
          await PluginWebServer.instance.start();
        } catch (e) {
          debugPrint('[PluginManager] Error starting PluginWebServer: $e');
        }
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[PluginManager] Error initializing: $e');
    }
  }

  /// Syncs the available plugin catalog from the Backend Marketplace API (`GET /api/marketplace/plugins`).
  /// Merges remote items with locally installed plugins without overwriting active local directories.
  Future<List<PluginCatalogItem>> syncMarketplaceCatalog({
    PluginMarketplaceService? marketplaceService,
  }) async {
    final service = marketplaceService ?? PluginMarketplaceService.instance;
    _isSyncingCatalog = true;
    notifyListeners();
    try {
      final items = await service.fetchCatalog();
      for (final item in items) {
        _remoteCatalog[item.id] = item;
        final existing = _registry[item.id];
        if (existing is InstalledPlugin && existing.installDirectory != null) {
          _registry[item.id] = InstalledPlugin(
            manifest: existing.manifest,
            installDirectory: existing.installDirectory,
            sourceFile: existing.sourceFile,
            sourceFilename: existing.sourceFilename,
            catalogItem: item,
            isDevelopmentSource: existing.isDevelopmentSource,
          );
          if (_installedPackages.containsKey(item.id)) {
            _installedPackages[item.id] = _registry[item.id] as InstalledPlugin;
          }
        } else if (existing == null) {
          final installedDir = PluginStorageManager.instance
              .getInstalledDirectory(item.id);
          final localManifest = installedDir != null
              ? PluginStorageManager.instance.loadManifestFromDir(installedDir)
              : null;
          final plugin = InstalledPlugin(
            manifest: localManifest ?? item.toManifest(),
            installDirectory: installedDir,
            catalogItem: item,
          );
          _registry[item.id] = plugin;
          if (installedDir != null && _installedPluginIds.contains(item.id)) {
            _installedPackages[item.id] = plugin;
          }
        }
      }
      return items;
    } finally {
      _isSyncingCatalog = false;
      notifyListeners();
    }
  }

  /// Dynamically discover plugins from workspace/bundled plugin directories.
  /// In debug mode, unpacked plugin sources override archives so UI and
  /// manifest edits can be exercised without rebuilding a `.hlep` package.
  Future<void> discoverAvailablePlugins({
    @visibleForTesting List<Directory>? standardDirectories,
  }) async {
    final searchDirs = <Directory>[
      if (standardDirectories != null)
        ...standardDirectories
      else ...[
        Directory('plugins'),
        Directory('../plugins'),
        Directory('../../plugins'),
        Directory('../../../plugins'),
        Directory('../../../../plugins'),
        Directory('../../../../../plugins'),
        ..._resolveExecutablePluginDirectories(),
      ],
    ];

    for (final dir in searchDirs) {
      if (!dir.existsSync()) continue;

      // Scan packaged .hlep archives
      try {
        final hlepFiles = dir.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.hlep'),
        );

        for (final hlep in hlepFiles) {
          try {
            final hlepBytes = hlep.readAsBytesSync();
            final manifest = PluginStorageManager.instance.loadManifestFromZip(
              hlepBytes,
            );
            if (manifest != null) {
              if (_registry[manifest.id] is InstalledPlugin &&
                  (_registry[manifest.id] as InstalledPlugin)
                      .isDevelopmentSource) {
                continue;
              }
              final existing = _registry[manifest.id];
              final isNewerVersion =
                  existing is InstalledPlugin &&
                  existing.manifest.version != manifest.version;

              final filename = hlep.uri.pathSegments
                  .where((s) => s.isNotEmpty)
                  .last;
              Directory? installedDir = PluginStorageManager.instance
                  .getInstalledDirectory(
                    manifest.id,
                    version: manifest.version,
                  );

              bool isBundleModified = false;
              if (installedDir != null) {
                try {
                  final cachedManifest = File(
                    '${installedDir.path}/manifest.json',
                  );
                  if (!cachedManifest.existsSync() ||
                      hlep.lastModifiedSync().isAfter(
                        cachedManifest.lastModifiedSync(),
                      )) {
                    isBundleModified = true;
                  }
                } catch (_) {}
              }

              if (existing == null || isNewerVersion || isBundleModified) {
                if ((_installedPluginIds.contains(manifest.id) ||
                        installedDir != null) &&
                    (installedDir == null || isBundleModified)) {
                  installedDir = await PluginStorageManager.instance
                      .installFromZip(hlepBytes, customFilename: filename);
                }
                installedDir ??= PluginStorageManager.instance
                    .getInstalledDirectory(manifest.id);

                final plugin = InstalledPlugin(
                  manifest: manifest,
                  installDirectory: installedDir,
                  sourceFile: hlep,
                  sourceFilename: filename,
                );
                _registry[manifest.id] = plugin;
                if (installedDir != null &&
                    _installedPluginIds.contains(manifest.id)) {
                  _installedPackages[manifest.id] = plugin;
                }
              }
            }
          } catch (e) {
            debugPrint(
              '[PluginManager] Error inspecting hlep package ${hlep.path}: $e',
            );
          }
        }
      } catch (e) {
        debugPrint('[PluginManager] Error scanning hlep in ${dir.path}: $e');
      }

      // Scan unpacked plugin directories with manifest.json
      try {
        final subDirs = dir.listSync().whereType<Directory>();
        for (final subDir in subDirs) {
          try {
            final manifest = PluginStorageManager.instance.loadManifestFromDir(
              subDir,
            );
            final existing = manifest == null ? null : _registry[manifest.id];
            final preferDevelopmentSource =
                kDebugMode &&
                manifest != null &&
                existing != null &&
                (existing is! InstalledPlugin || !existing.isDevelopmentSource);
            if (manifest != null &&
                (existing == null || preferDevelopmentSource)) {
              final segments = subDir.uri.pathSegments
                  .where((s) => s.isNotEmpty)
                  .toList();
              final dirname = segments.isNotEmpty ? segments.last : 'plugin';
              final installedDir =
                  PluginStorageManager.instance.getInstalledDirectory(
                    manifest.id,
                  ) ??
                  subDir;
              final plugin = InstalledPlugin(
                manifest: manifest,
                installDirectory: installedDir,
                sourceFilename: dirname,
                isDevelopmentSource: kDebugMode,
              );
              _registry[manifest.id] = plugin;
              if (_installedPluginIds.contains(manifest.id)) {
                _installedPackages[manifest.id] = plugin;
              }
            }
          } catch (e) {
            debugPrint(
              '[PluginManager] Error inspecting directory ${subDir.path}: $e',
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[PluginManager] Error scanning directories in ${dir.path}: $e',
        );
      }
    }
  }

  List<Directory> _resolveExecutablePluginDirectories() {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      return [
        Directory('${exeDir.path}/plugins'),
        Directory('${exeDir.path}/../plugins'),
        Directory('${exeDir.path}/../../plugins'),
        Directory('${exeDir.path}/../../../plugins'),
        Directory('${exeDir.path}/../../../../plugins'),
        Directory('${exeDir.path}/../../../../../plugins'),
      ];
    } catch (_) {
      return const [];
    }
  }

  void registerPlugin(SubjectPlugin plugin) {
    _registry[plugin.id] = plugin;
    notifyListeners();
  }

  bool isInstalled(String id) => _installedPluginIds.contains(id);

  Future<void> install(String id, {bool forceUpdate = false}) async {
    final plugin = _registry[id];
    final remoteItem = _remoteCatalog[id];
    if (plugin == null && remoteItem == null) return;
    if (_installedPluginIds.contains(id) && !forceUpdate) return;
    if (_downloadingIds.contains(id)) return;

    _downloadingIds.add(id);
    notifyListeners();

    try {
      if (plugin is InstalledPlugin &&
          plugin.sourceFile != null &&
          !forceUpdate) {
        try {
          final targetDir = await PluginStorageManager.instance.installFromZip(
            plugin.sourceFile!.readAsBytesSync(),
            customFilename: plugin.sourceFilename,
          );
          final installed = InstalledPlugin(
            manifest: plugin.manifest,
            installDirectory: targetDir,
            sourceFile: plugin.sourceFile,
            sourceFilename: plugin.sourceFilename,
            catalogItem: plugin.catalogItem ?? remoteItem,
          );
          _installedPackages[id] = installed;
          _registry[id] = installed;
        } catch (e) {
          debugPrint(
            '[PluginManager] Error extracting package on install for $id: $e',
          );
        }
      } else if (remoteItem != null &&
          (forceUpdate ||
              (plugin is InstalledPlugin && plugin.installDirectory == null))) {
        final downloaded = await PluginMarketplaceService.instance
            .downloadAndInstall(remoteItem, manager: this);
        final enriched = InstalledPlugin(
          manifest: downloaded.manifest,
          installDirectory: downloaded.installDirectory,
          sourceFilename: downloaded.sourceFilename,
          catalogItem: remoteItem,
        );
        _installedPackages[id] = enriched;
        _registry[id] = enriched;
      } else if (plugin is InstalledPlugin) {
        _installedPackages[id] = plugin;
      }

      _installedPluginIds.add(id);
      await _persistInstalledIds();
      if (plugin != null) {
        try {
          await plugin.onInstall();
        } catch (e) {
          debugPrint('[PluginManager] onInstall error for $id: $e');
        }
      }
    } finally {
      _downloadingIds.remove(id);
      notifyListeners();
    }
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

    final manifest = PluginStorageManager.instance.loadManifestFromDir(
      targetDir,
    );
    if (manifest == null) {
      throw const FormatException(
        'Không thể đọc tệp manifest.json sau khi giải nén.',
      );
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
  Future<InstalledPlugin> installSamplePlugin({String? targetCategory}) async {
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

        if (targetCategory != null) {
          for (final hlep in hlepFiles) {
            final manifest = PluginStorageManager.instance.loadManifestFromZip(
              hlep.readAsBytesSync(),
            );
            if (manifest != null &&
                manifest.category.toLowerCase() ==
                    targetCategory.toLowerCase()) {
              final filename = hlep.uri.pathSegments
                  .where((s) => s.isNotEmpty)
                  .last;
              return installPluginFromBytes(hlep.readAsBytesSync(), filename);
            }
          }
        }

        if (hlepFiles.isNotEmpty) {
          final target = hlepFiles.first;
          final filename = target.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last;
          return installPluginFromBytes(target.readAsBytesSync(), filename);
        }

        final subDirs = dir.listSync().whereType<Directory>().toList();
        for (final d in subDirs) {
          final manifest = PluginStorageManager.instance.loadManifestFromDir(d);
          if (manifest != null) {
            if (targetCategory != null &&
                manifest.category.toLowerCase() !=
                    targetCategory.toLowerCase()) {
              continue;
            }
            final segments = d.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .toList();
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
  Future<InstalledPlugin> installSampleEnglishPlugin() =>
      installSamplePlugin(targetCategory: 'languages');

  Future<void> uninstallPlugin(String id) async {
    _installedPackages.remove(id);
    final remoteItem = _remoteCatalog[id];
    if (remoteItem != null) {
      _registry[id] = InstalledPlugin(
        manifest: remoteItem.toManifest(),
        catalogItem: remoteItem,
      );
    } else {
      _registry.remove(id);
    }
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
    _remoteCatalog.clear();
    _installedPluginIds.clear();
    _downloadingIds.clear();
    _activePlugin = null;
    _isInitialized = false;
    _isSyncingCatalog = false;
  }

  Future<void> _persistInstalledIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kInstalledPluginsKey,
        _installedPluginIds.toList(),
      );
    } catch (e) {
      debugPrint('[PluginManager] Error persisting installed plugins: $e');
    }
  }
}
