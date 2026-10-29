import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import '../services/plugin_web_server.dart';
import '../services/process_supervisor.dart';
import '../services/plugin_event_hub.dart';
import '../services/host_bridge.dart';
import 'flat_host.dart';

class FloatingPluginWindow extends StatefulWidget {
  const FloatingPluginWindow({super.key, required this.studio});

  final StudioState studio;

  @override
  State<FloatingPluginWindow> createState() => _FloatingPluginWindowState();
}

class _FloatingPluginWindowState extends State<FloatingPluginWindow> {
  StudioState get studio => widget.studio;

  final AdaptiveGlassmorphismController _adaptiveController =
      AdaptiveGlassmorphismController(
        enterPdfThreshold: 0.20,
        exitPdfThreshold: 0.05,
      );

  bool _evaluateIsPdfGlass() {
    if (studio.pdf.pdfModeOverride != null) {
      return studio.pdf.pdfModeOverride!;
    }
    final bounds = Rect.fromLTWH(
      studio.pluginFloatingPosition.dx,
      studio.pluginFloatingPosition.dy,
      studio.pluginFloatingSize.width,
      studio.pluginFloatingSize.height,
    );
    final overlap = studio.getPdfOverlapRatio(bounds);
    _adaptiveController.updateOverlap(overlap);
    return _adaptiveController.isPdfGlass;
  }

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
        final isPdfGlass = _evaluateIsPdfGlass();
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

            final editing = studio.editingSticker;
            if (editing != null) {
              final editParams = <String, String>{'editId': editing.id};
              final meta = editing.metadata;
              if (meta != null) {
                if (meta['formula'] != null) {
                  editParams['formula'] = meta['formula'].toString();
                }
                if (meta['a'] != null) {
                  editParams['a'] = meta['a'].toString();
                }
                if (meta['b'] != null) {
                  editParams['b'] = meta['b'].toString();
                }
                if (meta['view'] != null) {
                  editParams['view'] = meta['view'].toString();
                }
              } else if (editing.title != null) {
                final clean = editing.title!
                    .replaceAll(RegExp(r'^(Đồ thị:\s*|y\s*=\s*)'), '')
                    .trim();
                if (clean.isNotEmpty) editParams['formula'] = clean;
              }
              final queryParts = editParams.entries
                  .map(
                    (e) =>
                        '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
                  )
                  .join('&');
              targetUrl = targetUrl.contains('?')
                  ? '$targetUrl&$queryParts'
                  : '$targetUrl?$queryParts';
            }

            return FlatHost(
              key: ValueKey(
                'flat_host_${plugin.manifest.id}_${studio.editingSticker?.id ?? "default"}',
              ),
              url: targetUrl,
              transparentBackground: plugin.manifest.transparentBackground,
              glassPreset: studio.glassPreset,
              isPdfMode: isPdfGlass,
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
                  isPdfMode: isPdfGlass,
                  sender: sendJs,
                );
                final curEditing = studio.editingSticker;
                if (curEditing != null) {
                  final editData = {
                    'stickerId': curEditing.id,
                    'title': curEditing.title,
                    'metadata': curEditing.metadata,
                    'formula':
                        curEditing.metadata?['formula'] ??
                        curEditing.title
                            ?.replaceAll(RegExp(r'^(Đồ thị:\s*|y\s*=\s*)'), '')
                            .trim(),
                    'a': curEditing.metadata?['a'],
                    'b': curEditing.metadata?['b'],
                    'view': curEditing.metadata?['view'],
                  };
                  sendJs(
                    "window.__hocluc_load_edit && window.__hocluc_load_edit(${jsonEncode(editData)});",
                  );
                }
                studio.pluginBridge.registerSnippetReceiver(
                  plugin.manifest.id,
                  sendJs,
                  (text, target, analysis) {
                    sendJs(
                      "window.onSnippetCaptured && window.onSnippetCaptured(${jsonEncode(text)}, ${jsonEncode(target)}, ${jsonEncode(analysis)});",
                    );
                  },
                );
              },
              onControllerDisposed: (sender) {
                PluginEventHub.instance.unregister(plugin.manifest.id, sender);
                studio.pluginBridge.unregisterSnippetReceiver(
                  plugin.manifest.id,
                  sender,
                );
              },
            );
          },
        );

        if (plugin.manifest.uiPlacement == 'modal') {
          return Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availW = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.of(context).size.width;
                final availH = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : MediaQuery.of(context).size.height;

                final maxSafeW = (availW - 48.0).clamp(400.0, 2000.0);
                final maxSafeH = (availH - 64.0).clamp(300.0, 1400.0);
                final dialogW = studio.pluginFloatingSize.width.clamp(
                  400.0,
                  maxSafeW,
                );
                final dialogH = studio.pluginFloatingSize.height.clamp(
                  300.0,
                  maxSafeH,
                );

                final centerLeft = (availW - dialogW) / 2.0;
                final centerTop = (availH - dialogH) / 2.0;

                return Stack(
                  children: [
                    // Backdrop overlay: Soft dark scrim exactly like NoteRenderer / Image 2
                    Positioned.fill(
                      child: GestureDetector(
                        key: const Key('modal_plugin_backdrop'),
                        behavior: HitTestBehavior.opaque,
                        onTap: studio.closeFloatingPlugin,
                        child: Container(color: const Color(0x66000000)),
                      ),
                    ),
                    // Fixed, dead-centered elevated modal dialog card
                    Positioned(
                      left: centerLeft,
                      top: centerTop,
                      width: dialogW,
                      height: dialogH,
                      child: Material(
                        elevation: 32,
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          key: const Key('modal_plugin_container'),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 40,
                                offset: Offset(0, 16),
                              ),
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: webViewContent,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }

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
                          final wasPdf = _adaptiveController.isPdfGlass;
                          final nowPdf = _evaluateIsPdfGlass();
                          if (wasPdf != nowPdf) {
                            setState(() {});
                          }
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
                                  key: const Key(
                                    'frameless_plugin_close_button',
                                  ),
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
            color: isPdfGlass
                ? const Color(0xf2111a16)
                : AppColors.overlaySurface,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPdfGlass
                      ? AppColors.overlayAccent.withValues(alpha: 0.45)
                      : AppColors.overlayBorder,
                  width: 1.2,
                ),
                boxShadow: isPdfGlass
                    ? const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 16,
                          offset: Offset(0, 5),
                        ),
                      ]
                    : const [
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
                      final wasPdf = _adaptiveController.isPdfGlass;
                      final nowPdf = _evaluateIsPdfGlass();
                      if (wasPdf != nowPdf) {
                        setState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isPdfGlass
                            ? const Color(0xeb182620)
                            : AppColors.overlayRaised,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isPdfGlass
                                ? Colors.white.withValues(alpha: 0.28)
                                : AppColors.overlayBorder,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(plugin.icon, size: 16, color: plugin.color),
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
