import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject_plugin.dart';

/// Central Microkernel Registry & Lifecycle Manager for Subject Plugins.
/// Handles plugin registration, installation persistence, and active states.
class PluginManager extends ChangeNotifier {
  static final PluginManager _instance = PluginManager._internal();
  factory PluginManager() => _instance;
  PluginManager._internal();

  static const _kInstalledPluginsKey = 'installed_subject_plugin_ids';

  final Map<String, SubjectPlugin> _registry = {};
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

  @visibleForTesting
  void resetForTesting() {
    _registry.clear();
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

