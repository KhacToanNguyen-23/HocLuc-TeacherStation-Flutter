import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../../plugin_engine/services/host_bridge.dart';
import '../../../plugin_engine/services/plugin_manager.dart';
import '../../domain/models/board_sticker.dart';

/// Single-responsibility controller managing Plugin lifecycle,
/// floating window coordinates, dynamic port communications, and webview RPCs.
class StudioPluginBridgeController extends ChangeNotifier {
  InstalledPlugin? activePlugin;
  InstalledPlugin? floatingPlugin;
  BoardSticker? editingSticker;
  bool showPluginDrawer = false;
  bool pluginFloating = false;
  Offset pluginFloatingPosition = const Offset(80, 80);
  Size pluginFloatingSize = const Size(420, 560);

  String? activeSubjectTool;
  bool chalkAnnotationsVisible = true;
  Offset subjectPaletteOffset = const Offset(20, 100);

  bool isSnippingActive = false;
  String snipTarget = 'dgnl';
  bool _wasFloatingBeforeSnip = false;

  void Function(String text, String target, Map<String, dynamic>? analysis)?
  _onSnippetCapturedForPlugin;
  final Map<String, _SnippetReceiver> _snippetReceivers = {};
  final Map<String, _PendingPluginSnippet> _pendingPluginSnippets = {};
  String? _pendingSnippetText;
  String? _pendingSnippetTarget;
  Map<String, dynamic>? _pendingSnippetAnalysis;

  void Function(String text, String target, Map<String, dynamic>? analysis)?
  get onSnippetCapturedForPlugin => _onSnippetCapturedForPlugin;

  set onSnippetCapturedForPlugin(
    void Function(String text, String target, Map<String, dynamic>? analysis)?
    callback,
  ) {
    _onSnippetCapturedForPlugin = callback;
    final text = _pendingSnippetText;
    if (callback == null || text == null) return;

    final target = _pendingSnippetTarget ?? 'dgnl';
    final analysis = _pendingSnippetAnalysis;
    _pendingSnippetText = null;
    _pendingSnippetTarget = null;
    _pendingSnippetAnalysis = null;
    Future<void>.delayed(Duration.zero, () => callback(text, target, analysis));
  }

  void registerSnippetReceiver(
    String pluginId,
    Object viewToken,
    void Function(String text, String target, Map<String, dynamic>? analysis)
    callback,
  ) {
    _snippetReceivers[pluginId] = _SnippetReceiver(viewToken, callback);
    final pending = _pendingPluginSnippets.remove(pluginId);
    if (pending != null) {
      Future<void>.delayed(
        Duration.zero,
        () => callback(pending.text, pending.target, pending.analysis),
      );
    }
  }

  void unregisterSnippetReceiver(String pluginId, Object viewToken) {
    if (identical(_snippetReceivers[pluginId]?.viewToken, viewToken)) {
      _snippetReceivers.remove(pluginId);
    }
  }

  void sendSnippetToPlugin(
    String text,
    String target,
    Map<String, dynamic>? analysis, {
    String? pluginId,
  }) {
    final resolvedPluginId = pluginId ?? activePlugin?.id ?? floatingPlugin?.id;
    if (resolvedPluginId != null) {
      final receiver = _snippetReceivers[resolvedPluginId]?.callback;
      if (receiver != null) {
        receiver(text, target, analysis);
      } else {
        _pendingPluginSnippets[resolvedPluginId] = _PendingPluginSnippet(
          text,
          target,
          analysis,
        );
      }
      return;
    }
    final callback = _onSnippetCapturedForPlugin;
    if (callback != null) {
      callback(text, target, analysis);
      return;
    }
    _pendingSnippetText = text;
    _pendingSnippetTarget = target;
    _pendingSnippetAnalysis = analysis;
  }

  VoidCallback? onSaveHighlightedPdfRequested;
  VoidCallback? onApplyHighlightToPdfRequested;

  final HostBridge hostBridge = HostBridge();

  void setActiveSubjectTool(String? t) {
    activeSubjectTool = t;
    notifyListeners();
  }

  void toggleChalkAnnotationsVisibility() {
    chalkAnnotationsVisible = !chalkAnnotationsVisible;
    notifyListeners();
  }

  void setSubjectPaletteOffset(Offset offset) {
    subjectPaletteOffset = offset;
    notifyListeners();
  }

  void openPlugin(
    InstalledPlugin plugin, {
    bool openModal = false,
    BoardSticker? editingSticker,
  }) {
    this.editingSticker = editingSticker;
    if (plugin.manifest.uiPlacement == 'floating_window' ||
        plugin.manifest.uiPlacement == 'modal') {
      floatingPlugin = plugin;
      pluginFloating = true;
      pluginFloatingSize = Size(
        plugin.manifest.uiDefaultWidth,
        plugin.manifest.uiDefaultHeight,
      );
      if (plugin.manifest.uiPlacement == 'modal') {
        pluginFloatingPosition = const Offset(80, 80);
      }
      if (activePlugin == null ||
          activePlugin!.manifest.uiPlacement == 'floating_window' ||
          activePlugin!.manifest.uiPlacement == 'modal') {
        activePlugin = plugin;
      }
    } else {
      activePlugin = plugin;
      showPluginDrawer = openModal;
      if (floatingPlugin == null) {
        pluginFloating = false;
      }
    }
    notifyListeners();
  }

  void closePlugin() {
    editingSticker = null;
    if (activePlugin != null &&
        floatingPlugin != null &&
        activePlugin!.id == floatingPlugin!.id) {
      floatingPlugin = null;
      pluginFloating = false;
    } else if (floatingPlugin == null) {
      pluginFloating = false;
    }
    activePlugin = null;
    showPluginDrawer = false;
    activeSubjectTool = null;
    notifyListeners();
  }

  void setPluginFloatingPosition(Offset position) {
    pluginFloatingPosition = position;
    notifyListeners();
  }

  void closeFloatingPlugin() {
    editingSticker = null;
    final closingId = floatingPlugin?.id;
    floatingPlugin = null;
    pluginFloating = false;
    if (activePlugin != null &&
        (activePlugin!.id == closingId ||
            activePlugin!.manifest.uiPlacement == 'floating_window' ||
            activePlugin!.manifest.uiPlacement == 'modal')) {
      activePlugin = null;
      showPluginDrawer = false;
      activeSubjectTool = null;
    }
    notifyListeners();
  }

  void togglePluginFloating() {
    pluginFloating = !pluginFloating;
    if (pluginFloating && floatingPlugin == null && activePlugin != null) {
      floatingPlugin = activePlugin;
      pluginFloatingSize = Size(
        activePlugin!.manifest.uiDefaultWidth,
        activePlugin!.manifest.uiDefaultHeight,
      );
    }
    notifyListeners();
  }

  void startSnipping({String target = 'dgnl'}) {
    snipTarget = target;
    isSnippingActive = true;
    _wasFloatingBeforeSnip = pluginFloating;
    if (pluginFloating) {
      pluginFloating = false;
    }
    notifyListeners();
  }

  void endSnipping() {
    isSnippingActive = false;
    if (_wasFloatingBeforeSnip) {
      pluginFloating = true;
      _wasFloatingBeforeSnip = false;
    }
    notifyListeners();
  }
}

class _SnippetReceiver {
  const _SnippetReceiver(this.viewToken, this.callback);

  final Object viewToken;
  final void Function(
    String text,
    String target,
    Map<String, dynamic>? analysis,
  )
  callback;
}

class _PendingPluginSnippet {
  const _PendingPluginSnippet(this.text, this.target, this.analysis);

  final String text;
  final String target;
  final Map<String, dynamic>? analysis;
}
