import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/models/subject_plugin.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';

/// Right-side Activities & Marketplace Panel matching Google Meet Add-ons & VS Code Extensions UX.
/// Supports browsing Backend Marketplace catalog, 1-click install/update, local icon rendering,
/// and developer `.hlep` sideloading.
class StudioPluginsMarketplacePanel extends StatefulWidget {
  const StudioPluginsMarketplacePanel({
    super.key,
    required this.onClose,
    this.pluginManager,
    this.onOpenPlugin,
    this.autoSyncOnOpen = true,
  });

  final VoidCallback onClose;
  final PluginManager? pluginManager;
  final ValueChanged<SubjectPlugin>? onOpenPlugin;
  final bool autoSyncOnOpen;

  @override
  State<StudioPluginsMarketplacePanel> createState() =>
      _StudioPluginsMarketplacePanelState();
}

class _StudioPluginsMarketplacePanelState
    extends State<StudioPluginsMarketplacePanel> {
  PluginManager get _manager => widget.pluginManager ?? PluginManager();

  @override
  void initState() {
    super.initState();
    if (widget.autoSyncOnOpen && _manager.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _manager.syncMarketplaceCatalog();
        }
      });
    }
  }

  Future<void> _sideloadLocalHlep() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Chọn gói tiện ích (.hlep)',
        type: FileType.custom,
        allowedExtensions: const ['hlep', 'zip'],
      );
      if (files.isEmpty) return;

      final picked = files.first;
      final bytes = await picked.readAsBytes();

      final installed = await _manager.installPluginFromBytes(
        bytes,
        picked.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nạp tiện ích "${installed.name}" thành công.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể nạp gói .hlep: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = _manager;

    return Container(
      width: 320,
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar (Google Meet Activities + Marketplace actions)
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.extension_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Hoạt động & Tiện ích',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('marketplace_sideload_button'),
                  icon: const Icon(
                    Icons.folder_open_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Nạp gói .hlep từ máy (Dev Sideload)',
                  visualDensity: VisualDensity.compact,
                  onPressed: _sideloadLocalHlep,
                ),
                IconButton(
                  key: const Key('marketplace_sync_button'),
                  icon: const Icon(
                    Icons.sync_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Đồng bộ từ Marketplace',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => manager.syncMarketplaceCatalog(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Đóng tiện ích',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Content Body
          Expanded(
            child: ListenableBuilder(
              listenable: manager,
              builder: (context, _) {
                final plugins = manager.availablePlugins;

                if (plugins.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: plugins.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plugin = plugins[index];
                    final isInstalled = manager.isInstalled(plugin.id);
                    return _buildPluginCard(
                      context,
                      manager,
                      plugin,
                      isInstalled,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.extension_outlined,
                size: 28,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có tiện ích bổ sung',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Hệ thống Extension Microkernel sẵn sàng kết nối tiện ích bộ môn THPT và kỳ thi ĐGNL.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPluginAvatar(SubjectPlugin plugin) {
    if (plugin is InstalledPlugin) {
      final iconFile = plugin.iconFile;
      if (iconFile != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Image.file(
            iconFile,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackIcon(plugin),
          ),
        );
      }
    }
    return _buildFallbackIcon(plugin);
  }

  Widget _buildFallbackIcon(SubjectPlugin plugin) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: plugin.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Icon(plugin.icon, color: plugin.color, size: 22),
    );
  }

  Widget _buildPluginCard(
    BuildContext context,
    PluginManager manager,
    SubjectPlugin plugin,
    bool isInstalled,
  ) {
    final isDownloading = manager.isDownloading(plugin.id);
    final hasUpdate = manager.hasUpdate(plugin.id);
    final installedPlugin = plugin is InstalledPlugin ? plugin : null;
    final placementLabel = installedPlugin != null
        ? (installedPlugin.manifest.uiPlacement == 'floating_window'
              ? 'Cửa sổ nổi'
              : 'Gắn bài giảng')
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPluginAvatar(plugin),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plugin.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (plugin.summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    plugin.summary,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (installedPlugin != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v${installedPlugin.manifest.version}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (placementLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: plugin.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            placementLabel,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: plugin.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (!isInstalled)
            ElevatedButton(
              onPressed: () => manager.install(plugin.id),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Cài đặt',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else ...[
            if (hasUpdate)
              IconButton(
                key: Key('update_plugin_${plugin.id}'),
                icon: const Icon(
                  Icons.system_update_alt_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                tooltip: 'Cập nhật phiên bản mới',
                visualDensity: VisualDensity.compact,
                onPressed: () => manager.install(plugin.id, forceUpdate: true),
              ),
            ElevatedButton(
              onPressed: () {
                manager.openPlugin(plugin);
                widget.onOpenPlugin?.call(plugin);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Mở',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              tooltip: 'Gỡ tiện ích',
              visualDensity: VisualDensity.compact,
              onPressed: () => manager.uninstall(plugin.id),
            ),
          ],
        ],
      ),
    );
  }
}


