import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/subject_plugin.dart';
import '../../services/plugin_manager.dart';

/// Right-side Activities Panel matching Google Meet Add-ons UX.
/// Displays unified list of available and installed subject plugins with zero mock data.
class StudioPluginsMarketplacePanel extends StatelessWidget {
  const StudioPluginsMarketplacePanel({
    super.key,
    required this.onClose,
    this.pluginManager,
  });

  final VoidCallback onClose;
  final PluginManager? pluginManager;

  @override
  Widget build(BuildContext context) {
    final manager = pluginManager ?? PluginManager();

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar (Google Meet Activities style)
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Đóng tiện ích',
                  onPressed: onClose,
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
              decoration: BoxDecoration(
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

  Widget _buildPluginCard(
    BuildContext context,
    PluginManager manager,
    SubjectPlugin plugin,
    bool isInstalled,
  ) {
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: plugin.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(plugin.icon, color: plugin.color, size: 22),
          ),
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isInstalled)
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
            ElevatedButton(
              onPressed: () => manager.openPlugin(plugin),
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
              onPressed: () => manager.uninstall(plugin.id),
            ),
          ],
        ],
      ),
    );
  }
}
