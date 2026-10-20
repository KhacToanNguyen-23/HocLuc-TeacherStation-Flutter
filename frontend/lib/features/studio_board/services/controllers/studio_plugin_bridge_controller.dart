import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../../plugin_engine/services/host_bridge.dart';
import '../../../plugin_engine/services/plugin_manager.dart';

/// Single-responsibility controller managing Plugin lifecycle,
/// floating window coordinates, dynamic port communications, and webview RPCs.
class StudioPluginBridgeController extends ChangeNotifier {
  InstalledPlugin? activePlugin;
  InstalledPlugin? floatingPlugin;
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

  void Function(String text, String target)? onSnippetCapturedForPlugin;
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

  void openPlugin(InstalledPlugin plugin, {bool openModal = false}) {
    if (plugin.manifest.uiPlacement == 'floating_window') {
      floatingPlugin = plugin;
      pluginFloating = true;
      pluginFloatingSize = Size(
        plugin.manifest.uiDefaultWidth,
        plugin.manifest.uiDefaultHeight,
      );
      if (activePlugin == null ||
          activePlugin!.manifest.uiPlacement == 'floating_window') {
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
    final closingId = floatingPlugin?.id;
    floatingPlugin = null;
    pluginFloating = false;
    if (activePlugin != null &&
        (activePlugin!.id == closingId ||
            activePlugin!.manifest.uiPlacement == 'floating_window')) {
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
