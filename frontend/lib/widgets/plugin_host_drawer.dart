import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/studio_state.dart';
import '../services/plugin_manager.dart';
import '../services/process_supervisor.dart';
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
        final isOpen =
            plugin != null && studio.showPluginDrawer && !studio.pluginFloating;
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
                      const Icon(
                        Icons.extension,
                        size: 16,
                        color: AppColors.overlayAccent,
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
                      // Quick Scan Paragraph on PDF
                      Tooltip(
                        message:
                            'Kéo chụp đoạn văn trên đề để highlight Ngữ pháp & Từ vựng (PrtSc)',
                        child: InkWell(
                          onTap: () => studio.startSnipping(target: 'dgnl'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.overlaySelected,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.overlaySelected,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.crop_free,
                                  size: 13,
                                  color: AppColors.overlayAccent,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Quét đoạn văn',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.overlayText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
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
                    child: _buildPluginContent(plugin),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPluginContent(dynamic plugin) {
    if (plugin == null) return const SizedBox.shrink();
    final entry = plugin.manifest.uiEntry as String;
    String targetUrl = entry;

    if (plugin is InstalledPlugin && plugin.installDirectory != null) {
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

    void Function(String)? executeJs;
    return FlatHost(
      url: targetUrl,
      onMessage: (msg) => studio.handlePluginMessage(msg, executeJs: executeJs),
      onControllerReady: (sendJs) {
        executeJs = sendJs;
        studio.onSnippetCapturedForPlugin = (text, target) {
          sendJs(
            "window.onSnippetCaptured && window.onSnippetCaptured(${jsonEncode(text)}, ${jsonEncode(target)});",
          );
        };
      },
    );
  }
}
