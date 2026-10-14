import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/studio_state.dart';
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
            color: const Color(0xf70e1a15),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33ffffff), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x77000000),
                    blurRadius: 18,
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
                        color: Color(0x18ffffff),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0x22ffffff)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.extension,
                            size: 15,
                            color: Color(0xffd4e8a6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plugin.manifest.name,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xffe8eae6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Quick Scan Paragraph on PDF
                          Tooltip(
                            message: 'Kéo chụp đoạn văn trên đề để highlight Ngữ pháp & Từ vựng (PrtSc)',
                            child: InkWell(
                              onTap: () => studio.startSnipping(target: 'dgnl'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x3d89b4fa),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0x8889b4fa),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.crop_free,
                                      size: 13,
                                      color: Color(0xff89b4fa),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Quét đoạn văn',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xffcdd6f4),
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
                            color: const Color(0xffa5b5a8),
                            onPressed: studio.togglePluginFloating,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 15),
                            tooltip: 'Đóng',
                            splashRadius: 16,
                            color: const Color(0xffa5b5a8),
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
                      child: FlatHost(
                        url: plugin.manifest.uiEntry,
                        onMessage: studio.handlePluginMessage,
                        onControllerReady: (sendJs) {
                          studio.onSnippetCapturedForPlugin = (text, target) {
                            sendJs(
                              "window.onSnippetCaptured && window.onSnippetCaptured(${jsonEncode(text)}, ${jsonEncode(target)});",
                            );
                          };
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
