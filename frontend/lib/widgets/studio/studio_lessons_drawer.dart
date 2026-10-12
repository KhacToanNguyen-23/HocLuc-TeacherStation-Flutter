import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../../services/plugin_manager.dart';

class StudioLessonsDrawer extends StatelessWidget {
  const StudioLessonsDrawer({
    super.key,
    required this.studio,
    required this.onClose,
    this.onPluginMessage,
    this.onOpenPluginsMarketplace,
  });

  final StudioState studio;
  final VoidCallback onClose;
  final void Function(String message)? onPluginMessage;
  final VoidCallback? onOpenPluginsMarketplace;

  @override
  Widget build(BuildContext context) {
    const pine = AppColors.pine;
    const muted = AppColors.muted;
    const lime = AppColors.lime;
    const line = AppColors.line;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: line)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        children: [
          Row(
            children: [
              const Icon(Icons.layers_outlined, size: 15, color: pine),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'CÁC TRANG BẢNG',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: pine,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'P.${studio.page + 1}/3',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: muted,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 14, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (index, label) in [
            (0, 'Khám phá hàm số'),
            (1, 'Giải thích bảng'),
            (2, 'Luyện tập'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: InkWell(
                onTap: () => studio.change(() {
                  studio.page = index;
                  studio.view = 'board';
                }),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: studio.page == index && studio.view == 'board'
                        ? const Color(0xfff0f4e8)
                        : Colors.white,
                    border: Border.all(
                      color: studio.page == index && studio.view == 'board'
                          ? const Color(0xffadc38c)
                          : line,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: studio.page == index && studio.view == 'board'
                              ? pine
                              : const Color(0xfff0f2eb),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  studio.page == index && studio.view == 'board'
                                  ? lime
                                  : muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                studio.page == index && studio.view == 'board'
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: pine,
                          ),
                        ),
                      ),
                      Icon(
                        index == 0 ? Icons.show_chart : Icons.draw_outlined,
                        size: 13,
                        color: studio.page == index && studio.view == 'board'
                            ? pine
                            : muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: line),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.extension_outlined, size: 13, color: muted),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'TIỆN ÍCH MÔN HỌC',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xffedf2e5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Plugins',
                  style: TextStyle(
                    fontSize: 8,
                    color: pine,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: PluginManager(),
            builder: (context, _) {
              final installed = PluginManager().installedPlugins;
              if (installed.isEmpty) return const SizedBox.shrink();

              return Column(
                children: [
                  for (final p in installed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () => PluginManager().openPlugin(p),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xffdbe2d4)),
                          ),
                          child: Row(
                            children: [
                              Icon(p.icon, size: 14, color: p.color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              );
            },
          ),
          InkWell(
            onTap: () {
              if (onOpenPluginsMarketplace != null) {
                onOpenPluginsMarketplace!();
              } else {
                onPluginMessage?.call(
                  'Hệ thống Extension Microkernel: Sẵn sàng kết nối plugin bộ môn (Tiếng Anh, Toán, Khoa học…).',
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xfff8f9f5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xffdbe2d4),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline, size: 15, color: pine),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cài thêm tiện ích môn',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: pine,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
