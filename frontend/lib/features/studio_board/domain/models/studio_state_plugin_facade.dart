part of 'studio_state.dart';

extension StudioStatePluginFacadeExt on StudioState {
  InstalledPlugin? get activePlugin => pluginBridge.activePlugin;
  set activePlugin(InstalledPlugin? plugin) =>
      pluginBridge.activePlugin = plugin;

  InstalledPlugin? get floatingPlugin => pluginBridge.floatingPlugin;
  set floatingPlugin(InstalledPlugin? plugin) =>
      pluginBridge.floatingPlugin = plugin;

  bool get showPluginDrawer => pluginBridge.showPluginDrawer;
  set showPluginDrawer(bool value) => pluginBridge.showPluginDrawer = value;
  bool get pluginFloating => pluginBridge.pluginFloating;
  set pluginFloating(bool value) => pluginBridge.pluginFloating = value;

  void setGlassPreset(GlassPreset preset) {
    if (glassPreset == preset) return;
    glassPreset = preset;
    final pluginIds = {
      if (activePlugin != null) activePlugin!.id,
      if (floatingPlugin != null) floatingPlugin!.id,
    };
    for (final pluginId in pluginIds) {
      HostBridge.instance.notifyGlassPreset(pluginId: pluginId, preset: preset);
    }
    change(() {}, persist: false);
  }

  bool get activeToolCapturesBoardInput {
    final plugin = activePlugin;
    final target = activeSubjectTool;
    if (plugin == null || target == null) return false;
    return plugin.manifest.contributesTools.any(
      (tool) =>
          tool.capturesBoardInput && (tool.target ?? tool.id) == target,
    );
  }

  Offset get pluginFloatingPosition => pluginBridge.pluginFloatingPosition;
  Size get pluginFloatingSize => pluginBridge.pluginFloatingSize;
  String? get activeSubjectTool => pluginBridge.activeSubjectTool;
  set activeSubjectTool(String? value) =>
      pluginBridge.activeSubjectTool = value;
  void setActiveSubjectTool(String? tool) =>
      pluginBridge.setActiveSubjectTool(tool);
  bool get chalkAnnotationsVisible => pluginBridge.chalkAnnotationsVisible;
  void toggleChalkAnnotationsVisibility() =>
      pluginBridge.toggleChalkAnnotationsVisibility();
  Offset get subjectPaletteOffset => pluginBridge.subjectPaletteOffset;
  void setSubjectPaletteOffset(Offset offset) =>
      pluginBridge.setSubjectPaletteOffset(offset);

  void openPlugin(InstalledPlugin plugin, {bool openModal = false}) {
    showQuestionsDrawer = false;
    pluginBridge.openPlugin(plugin, openModal: openModal);
    unawaited(_startPluginSidecar(plugin));
  }

  Future<void> _startPluginSidecar(InstalledPlugin plugin) async {
    final directory = plugin.installDirectory;
    if (directory == null || !plugin.manifest.hasSidecar) return;
    final instance = await ProcessSupervisor.instance.startSidecar(
      manifest: plugin.manifest,
      pluginDirectory: directory.path,
    );
    if (instance != null && activePlugin?.id == plugin.id) {
      change(() {}, persist: false);
    }
  }

  void closePlugin() {
    final closingId = activePlugin?.id;
    pluginBridge.closePlugin();
    if (closingId != null) {
      unawaited(ProcessSupervisor.instance.stopSidecar(closingId));
    }
  }

  void setPluginFloatingPosition(Offset position) =>
      pluginBridge.setPluginFloatingPosition(position);

  void closeFloatingPlugin() {
    final closingId = floatingPlugin?.id;
    pluginBridge.closeFloatingPlugin();
    if (closingId != null) {
      unawaited(ProcessSupervisor.instance.stopSidecar(closingId));
    }
  }

  void togglePluginFloating() => pluginBridge.togglePluginFloating();
  bool get isSnippingActive => pluginBridge.isSnippingActive;
  String get snipTarget => pluginBridge.snipTarget;
  void startSnipping({String target = 'dgnl'}) =>
      pluginBridge.startSnipping(target: target);
  void endSnipping() => pluginBridge.endSnipping();
  void stopSnipping() => pluginBridge.endSnipping();

  void Function(String text, String target)? get onSnippetCapturedForPlugin =>
      pluginBridge.onSnippetCapturedForPlugin;
  set onSnippetCapturedForPlugin(
    void Function(String text, String target)? callback,
  ) => pluginBridge.onSnippetCapturedForPlugin = callback;

  VoidCallback? get onSaveHighlightedPdfRequested =>
      pluginBridge.onSaveHighlightedPdfRequested;
  set onSaveHighlightedPdfRequested(VoidCallback? callback) =>
      pluginBridge.onSaveHighlightedPdfRequested = callback;
  VoidCallback? get onApplyHighlightToPdfRequested =>
      pluginBridge.onApplyHighlightToPdfRequested;
  set onApplyHighlightToPdfRequested(VoidCallback? callback) =>
      pluginBridge.onApplyHighlightToPdfRequested = callback;

  void sendSnippetToPlugin(String text, {String? target}) {
    final resolvedTarget = target ?? snipTarget;
    stopSnipping();
    final clean = text.trim();
    if (clean.isNotEmpty) {
      onSnippetCapturedForPlugin?.call(clean, resolvedTarget);
      change(() {}, persist: false);
    }
  }

  void insertPluginCard(Map<String, dynamic> cardData) =>
      coordinator.insertPluginCard(cardData);

  void handlePluginMessage(
    dynamic message, {
    void Function(String jsScript)? executeJs,
    PluginManifest? manifest,
    String? viewToken,
    int? navigationGeneration,
    Rect? webViewBounds,
  }) {
    HostBridge.instance.handleMessage(
      rawMessage: message,
      studio: this,
      manifest: manifest ?? activePlugin?.manifest ?? floatingPlugin?.manifest,
      executeJs: executeJs,
      viewToken: viewToken,
      navigationGeneration: navigationGeneration,
      webViewBounds: webViewBounds,
    );
  }
}
