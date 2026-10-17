import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/studio_state.dart';
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
        final plugin = studio.activePlugin;
        if (plugin == null || !studio.pluginFloating) {
          return const SizedBox.shrink();
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
                          const Icon(
                            Icons.extension,
                            size: 15,
                            color: AppColors.overlayAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plugin.manifest.name,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.overlayText,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                            onPressed: studio.closePlugin,
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
                      child: Builder(
                        builder: (context) {
                          final entry = plugin.manifest.uiEntry;
                          String targetUrl = entry;

                          if (plugin.installDirectory != null) {
                            final f = File('${plugin.installDirectory!.path}/$entry');
                            if (f.existsSync()) {
                              targetUrl = f.absolute.uri.toString();
                            }
                          }

                          final port = ProcessSupervisor.instance.getPort(plugin.manifest.id);
                          if (port != null) {
                            targetUrl = targetUrl.contains('?') ? '$targetUrl&port=$port' : '$targetUrl?port=$port';
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
                        },
                      ),
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
