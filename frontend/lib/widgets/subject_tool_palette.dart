import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/plugin_manifest.dart';
import '../models/studio_state.dart';
import '../services/pdf_annotation_exporter.dart';

/// Dynamic In-Board Plugin Tool Palette Dock driven by `manifest.contributesTools`
/// (modeled after VS Code Extension Contribution Points).
class SubjectToolPalette extends StatelessWidget {
  const SubjectToolPalette({super.key, required this.studio});

  final StudioState studio;

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'crop_free':
        return Icons.crop_free;
      case 'edit_note':
        return Icons.edit_note;
      case 'calculate':
        return Icons.calculate_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'bookmark':
        return Icons.bookmark_outline;
      case 'auto_awesome':
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final plugin = studio.activePlugin;
        if (plugin == null ||
            plugin.manifest.uiPlacement == 'floating_window' ||
            plugin.manifest.contributesTools.isEmpty) {
          return const SizedBox.shrink();
        }

        final tools = plugin.manifest.contributesTools;
        final isEyeVisible = studio.chalkAnnotationsVisible;
        final hasActiveTool = studio.activeSubjectTool != null;

        return Positioned(
          left: studio.subjectPaletteOffset.dx,
          top: studio.subjectPaletteOffset.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              final newPos = studio.subjectPaletteOffset + details.delta;
              studio.setSubjectPaletteOffset(
                Offset(
                  newPos.dx.clamp(0.0, 1000.0),
                  newPos.dy.clamp(0.0, 700.0),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.overlaySurface,
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  border: Border.all(
                    color: hasActiveTool
                        ? AppColors.overlayAccent
                        : AppColors.overlaySelected,
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle & Plugin Badge
                    Container(
                      key: const Key('subject_badge_button'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.overlaySelected,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.overlaySelected),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.drag_indicator,
                            size: 13,
                            color: AppColors.overlayMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            plugin.manifest.name,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.overlayAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Dynamically render tools contributed by manifest.json
                    for (int i = 0; i < tools.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _buildContributedToolButton(context, tools[i]),
                      if (tools[i].action == 'snip_region' &&
                          studio.pdfDgnlPassages.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildApplyPdfHighlightButton(context),
                      ],
                    ],

                    const SizedBox(width: 6),

                    // Eye Toggle Button (Ẩn / Hiện lớp chú thích của tiện ích)
                    Tooltip(
                      message: isEyeVisible
                          ? 'Bấm để ẩn lớp chú thích trên bảng'
                          : 'Bấm để hiện lớp chú thích trên bảng',
                      child: InkWell(
                        key: const Key('eye_toggle_button'),
                        onTap: () => studio.toggleChalkAnnotationsVisibility(),
                        borderRadius: BorderRadius.circular(AppRadii.panel),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isEyeVisible
                                ? AppColors.overlaySelected
                                : AppColors.overlayRaised,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isEyeVisible
                                  ? AppColors.overlaySelected
                                  : AppColors.overlayRaised,
                            ),
                          ),
                          child: Icon(
                            isEyeVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 14,
                            color: isEyeVisible
                                ? AppColors.border
                                : AppColors.errorSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Close Button
                    Tooltip(
                      message: 'Đóng khay công cụ môn học',
                      child: InkWell(
                        key: const Key('close_palette_button'),
                        onTap: () => studio.closePlugin(),
                        borderRadius: BorderRadius.circular(AppRadii.panel),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.overlayRaised,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.overlayMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContributedToolButton(
    BuildContext context,
    PluginToolContribution tool,
  ) {
    final targetId = tool.target ?? tool.id;
    final isToggle = tool.action == 'toggle_tool';
    final isSettingToggle = tool.action == 'toggle_setting';
    final isActive = isToggle
        ? studio.activeSubjectTool == targetId
        : isSettingToggle && tool.settingKey != null
        ? studio.contributedToolSetting(
            tool.settingKey!,
            defaultValue: tool.defaultValue,
          )
        : false;
    final isPrimarySnip = tool.action == 'snip_region';
    final buttonKey = Key(tool.widgetKey ?? '${tool.id}_tool_button');

    return Tooltip(
      message: tool.tooltip.isNotEmpty ? tool.tooltip : tool.label,
      child: InkWell(
        key: buttonKey,
        onTap: () {
          switch (tool.action) {
            case 'snip_region':
              studio.startSnipping(target: targetId);
              break;
            case 'toggle_tool':
              studio.setActiveSubjectTool(isActive ? null : targetId);
              break;
            case 'toggle_setting':
              final settingKey = tool.settingKey;
              if (settingKey != null) {
                studio.toggleContributedToolSetting(
                  settingKey,
                  defaultValue: tool.defaultValue,
                );
              }
              break;
            case 'quick_input':
              _showQuickInputDialog(context, studio, tool);
              break;
            default:
              studio.setActiveSubjectTool(isActive ? null : targetId);
          }
        },
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, milliseconds: 150),
          curve: AppMotion.stateCurve,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (isActive || isPrimarySnip)
                ? AppColors.overlaySelected
                : AppColors.overlayRaised,
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(
              color: (isActive || isPrimarySnip)
                  ? AppColors.overlayAccent
                  : AppColors.overlayBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _resolveIcon(tool.icon),
                size: 14,
                color: AppColors.overlayAccent,
              ),
              const SizedBox(width: 5),
              Text(
                tool.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? AppColors.overlayAccent
                      : (isPrimarySnip ? AppColors.overlayText : Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyPdfHighlightButton(BuildContext context) {
    return Tooltip(
      message:
          'Áp lớp Highlight chuẩn trực tiếp vào file PDF đang mở (không cần lưu tệp mới)',
      child: InkWell(
        key: const Key('btn_palette_save_pdf_highlight'),
        onTap: () => PdfAnnotationExporter.applyHighlightDirectlyToPdf(
          context,
          studio,
        ),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.overlaySelected,
            borderRadius: BorderRadius.circular(AppRadii.panel),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.draw_rounded, size: 14, color: AppColors.border),
              SizedBox(width: 5),
              Text(
                'Highlight lên file',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickInputDialog(
    BuildContext context,
    StudioState studio,
    PluginToolContribution tool,
  ) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.overlaySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.overlaySelected, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: AppColors.overlayAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tool.tooltip.isNotEmpty ? tool.tooltip : tool.label,
                style: const TextStyle(
                  color: AppColors.overlayAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập nội dung để ghim và phân tích trực tiếp lên bảng phấn:',
                style: TextStyle(color: AppColors.overlayMuted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nhập văn bản hoặc biểu thức...',
                  hintStyle: const TextStyle(
                    color: AppColors.overlayMuted,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.overlayBorder,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    borderSide: const BorderSide(
                      color: AppColors.overlayBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    borderSide: const BorderSide(
                      color: AppColors.overlayAccent,
                      width: 1.4,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.overlayMuted),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              final t = textController.text.trim();
              if (t.isNotEmpty) {
                studio.addTypedChalkAnnotation(t);
              }
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Gạch chân lên bảng'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.overlayAccent,
              foregroundColor: const Color(0xff14221d),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
