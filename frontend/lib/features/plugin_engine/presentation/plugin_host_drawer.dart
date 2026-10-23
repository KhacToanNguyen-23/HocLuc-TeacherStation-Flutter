import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import '../services/plugin_manager.dart';
import '../services/plugin_web_server.dart';
import '../services/process_supervisor.dart';
import '../services/plugin_event_hub.dart';
import '../services/host_bridge.dart';
import 'flat_host.dart';

class PluginHostDrawer extends StatelessWidget {
  const PluginHostDrawer({super.key, required this.studio});

  final StudioState studio;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final plugin = studio.activePlugin;
        final isSameAsFloating =
            studio.pluginFloating &&
            (studio.floatingPlugin == null ||
                studio.floatingPlugin?.id == plugin?.id);
        final isOpen =
            plugin != null && studio.showPluginDrawer && !isSameAsFloating;
        final drawerWidth = plugin?.manifest.uiDefaultWidth ?? 420.0;

        return AnimatedPositioned(
          duration: AppMotion.duration(context, milliseconds: 220),
          curve: Curves.easeOutCubic,
          right: isOpen ? 0 : -(drawerWidth + 20),
          top: 0,
          bottom: 0,
          width: drawerWidth,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.overlaySurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              border: Border.all(color: AppColors.overlayBorder, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x77000000),
                  blurRadius: 8,
                  offset: Offset(-3, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.overlayBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        plugin?.icon ?? Icons.extension,
                        size: 16,
                        color: plugin?.color ?? AppColors.overlayAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          plugin?.manifest.name ?? 'Tiện ích môn học',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.overlayText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        tooltip: 'Tách thành cửa sổ nổi',
                        splashRadius: 16,
                        color: AppColors.overlayMuted,
                        onPressed: studio.togglePluginFloating,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Đóng',
                        splashRadius: 16,
                        color: AppColors.overlayMuted,
                        onPressed: studio.closePlugin,
                      ),
                    ],
                  ),
                ),

                // Plugin Viewport
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                    ),
                    child: _buildPluginContent(plugin, visible: isOpen),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPluginContent(dynamic plugin, {required bool visible}) {
    if (plugin == null) return const SizedBox.shrink();
    final entry = plugin.manifest.uiEntry as String;
    String targetUrl =
        PluginWebServer.instance.getUrl(plugin.manifest.id, entry) ?? entry;

    if (targetUrl == entry &&
        plugin is InstalledPlugin &&
        plugin.installDirectory != null) {
      final f = File('${plugin.installDirectory!.path}/$entry');
      if (f.existsSync()) {
        targetUrl = f.absolute.uri.toString();
      }
    }

    final port = ProcessSupervisor.instance.getPort(plugin.manifest.id);
    if (port != null) {
      targetUrl = targetUrl.contains('?')
          ? '$targetUrl&port=$port'
          : '$targetUrl?port=$port';
    }

    return FlatHost(
      url: targetUrl,
      visible: visible,
      transparentBackground: plugin.manifest.transparentBackground,
      glassPreset: studio.glassPreset,
      onPluginMessage: (message) => studio.handlePluginMessage(
        message.data,
        executeJs: message.executeJs,
        manifest: plugin.manifest,
        viewToken: message.viewToken,
        navigationGeneration: message.navigationGeneration,
        webViewBounds: message.webViewBounds,
      ),
      onControllerReady: (sendJs) {
        HostBridge.instance.registerPluginView(
          pluginId: plugin.manifest.id,
          preset: studio.glassPreset,
          sender: sendJs,
        );
        studio.onSnippetCapturedForPlugin = (text, target) {
          sendJs(
            "window.onSnippetCaptured && window.onSnippetCaptured(${jsonEncode(text)}, ${jsonEncode(target)});",
          );
        };
      },
      onControllerDisposed: (sender) {
        PluginEventHub.instance.unregister(plugin.manifest.id, sender);
      },
    );
  }
}
