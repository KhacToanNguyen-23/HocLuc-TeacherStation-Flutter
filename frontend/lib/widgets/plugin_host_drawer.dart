import 'package:flutter/material.dart';
import '../models/studio_state.dart';
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
        final isOpen = plugin != null && studio.showPluginDrawer && !studio.pluginFloating;
        final drawerWidth = plugin?.manifest.uiDefaultWidth ?? 420.0;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          right: isOpen ? 0 : -(drawerWidth + 20),
          top: 0,
          bottom: 0,
          width: drawerWidth,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xf70e1a15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              border: Border.all(
                color: const Color(0x33ffffff),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x77000000),
                  blurRadius: 18,
                  offset: Offset(-3, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x22ffffff)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.extension,
                        size: 16,
                        color: Color(0xffd4e8a6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          plugin?.manifest.name ?? 'Tiện ích môn học',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffe8eae6),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        tooltip: 'Tách thành cửa sổ nổi',
                        splashRadius: 16,
                        color: const Color(0xffa5b5a8),
                        onPressed: studio.togglePluginFloating,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Đóng',
                        splashRadius: 16,
                        color: const Color(0xffa5b5a8),
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
    // If running with a local server or html file
    final entry = plugin.manifest.uiEntry as String;
    return FlatHost(url: entry);
  }
}
