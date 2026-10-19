import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import '../services/plugin_web_server.dart';
import '../services/process_supervisor.dart';
import 'flat_host.dart';

class FloatingPluginWindow extends StatelessWidget {
  const FloatingPluginWindow({super.key, required this.studio});

  final StudioState studio;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final plugin =
            studio.floatingPlugin ??
            (studio.pluginFloating ? studio.activePlugin : null);
        if (plugin == null || !studio.pluginFloating) {
          return const SizedBox.shrink();
        }

        final isFrameless = plugin.manifest.frameless;
        final webViewContent = Builder(
          builder: (context) {
            final entry = plugin.manifest.uiEntry;
            String targetUrl =
                PluginWebServer.instance.getUrl(plugin.manifest.id, entry) ??
                entry;

            if (targetUrl == entry && plugin.installDirectory != null) {
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
              onMessage: (msg) => studio.handlePluginMessage(
                msg,
                executeJs: executeJs,
                manifest: plugin.manifest,
              ),
              onControllerReady: (sendJs) {
                executeJs = sendJs;
                studio.onSnippetCapturedForPlugin = (text, target) {
                  sendJs(
                    "window.onSnippetCaptured && window.onSnippetCaptured(${jsonEncode(text)}, ${jsonEncode(target)});",
                  );
                };
              },
            );
          },
        );

        if (isFrameless) {
          return Positioned(
            left: studio.pluginFloatingPosition.dx,
            top: studio.pluginFloatingPosition.dy,
            width: studio.pluginFloatingSize.width,
            height: studio.pluginFloatingSize.height,
            child: Container(
              key: const Key('frameless_floating_plugin_container'),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: webViewContent),
                    // Gờ nắm kéo & nút đóng (×) tích hợp sát mép trên thân máy
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 26,
                      child: GestureDetector(
                        key: const Key('frameless_plugin_drag_bezel'),
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (details) {
                          studio.setPluginFloatingPosition(
                            studio.pluginFloatingPosition + details.delta,
                          );
                        },
                        child: Row(
                          children: [
                            const SizedBox(width: 34),
                            Expanded(
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 10, top: 2),
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.25),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  key: const Key('frameless_plugin_close_button'),
                                  customBorder: const CircleBorder(),
                                  onTap: studio.closeFloatingPlugin,
                                  child: const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Positioned(
          left: studio.pluginFloatingPosition.dx,
          top: studio.pluginFloatingPosition.dy,
          width: studio.pluginFloatingSize.width,
          height: studio.pluginFloatingSize.height,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.overlaySurface,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.overlayBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x77000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Draggable Header
                  GestureDetector(
                    onPanUpdate: (details) {
                      studio.setPluginFloatingPosition(
                        studio.pluginFloatingPosition + details.delta,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.overlayRaised,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                        border: Border(
                          bottom: BorderSide(color: AppColors.overlayBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            plugin.icon,
                            size: 16,
                            color: plugin.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plugin.manifest.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.overlayText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (plugin.manifest.uiPlacement != 'floating_window')
                            IconButton(
                              icon: const Icon(Icons.vertical_split, size: 15),
                              tooltip: 'Gắn lại vào ngăn kéo',
                              splashRadius: 16,
                              color: AppColors.overlayMuted,
                              onPressed: studio.togglePluginFloating,
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 15),
                            tooltip: 'Đóng',
                            splashRadius: 16,
                            color: AppColors.overlayMuted,
                            onPressed: studio.closeFloatingPlugin,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(11),
                        bottomRight: Radius.circular(11),
                      ),
                      child: webViewContent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

