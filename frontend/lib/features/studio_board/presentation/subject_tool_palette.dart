import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/core/widgets/liquid_glass_container.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import '../services/pdf_annotation_exporter.dart';

/// Dynamic In-Board Plugin Tool Palette Dock driven by `manifest.contributesTools`
/// (modeled after VS Code Extension Contribution Points).
class SubjectToolPalette extends StatefulWidget {
  const SubjectToolPalette({super.key, required this.studio});

  final StudioState studio;

  @override
  State<SubjectToolPalette> createState() => _SubjectToolPaletteState();
}

class _SubjectToolPaletteState extends State<SubjectToolPalette>
    with SingleTickerProviderStateMixin {
  StudioState get studio => widget.studio;

  static const double _buttonWidth = 148.0;
  static const double _columnGap = 8.0;
  static const double _toolbarWidth = (_buttonWidth * 2) + _columnGap; // 304.0

  AnimationController? _expandController;
  Animation<double>? _expandAnimation;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  bool _glassPresetFocused = false;
  bool _isToolsExpanded = true;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ensureAnimationsInitialized();
  }

  @override
  void reassemble() {
    super.reassemble();
    _ensureAnimationsInitialized();
  }

  void _ensureAnimationsInitialized() {
    if (_expandController != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      value: _isToolsExpanded ? 1.0 : 0.0,
    );
    _expandController = controller;
    _expandAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.12, 1.0, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _expandController?.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    _ensureAnimationsInitialized();
    setState(() {
      _isToolsExpanded = !_isToolsExpanded;
      if (_isToolsExpanded) {
        _expandController!.forward();
      } else {
        _expandController!.reverse();
      }
    });
  }

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
    _ensureAnimationsInitialized();
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
            onPanStart: (_) {
              if (!_isDragging) setState(() => _isDragging = true);
            },
            onPanUpdate: (details) {
              final mediaSize = MediaQuery.sizeOf(context);
              final maxDx = (mediaSize.width - _toolbarWidth - 8.0).clamp(0.0, 4000.0);
              final maxDy = (mediaSize.height - 80.0).clamp(0.0, 3000.0);
              final newPos = studio.subjectPaletteOffset + details.delta;
              studio.setSubjectPaletteOffset(
                Offset(
                  newPos.dx.clamp(0.0, maxDx),
                  newPos.dy.clamp(0.0, maxDy),
                ),
              );
            },
            onPanEnd: (_) {
              if (_isDragging) setState(() => _isDragging = false);
            },
            onPanCancel: () {
              if (_isDragging) setState(() => _isDragging = false);
            },
            child: Material(
              color: Colors.transparent,
              child: AnimatedScale(
                scale: _isDragging ? 1.025 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: SizedBox(
                  width: _toolbarWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Dock: Plugin Badge (with expand/collapse) + Utility Controls
                      LiquidGlassContainer(
                        key: const Key('subject_tool_palette_surface'),
                        preset: studio.glassPreset,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        borderColor: _isDragging
                            ? AppColors.overlayAccent
                            : (hasActiveTool
                                ? AppColors.overlayAccent
                                : AppColors.overlayMuted),
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildPluginBadgeButton(plugin),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildGlassPresetButton(),
                            const SizedBox(width: 3),
                            _buildEyeToggleButton(isEyeVisible),
                            const SizedBox(width: 3),
                            _buildCloseButton(),
                          ],
                        ),
                      ),

                      // Bottom Sub-Tray with smooth animated expand/collapse transition
                      AnimatedBuilder(
                        animation: _expandAnimation!,
                        builder: (context, child) {
                          if (_expandAnimation!.value == 0.0 && !_isToolsExpanded) {
                            return const SizedBox.shrink();
                          }
                          return ClipRect(
                            child: Align(
                              alignment: Alignment.topLeft,
                              heightFactor: _expandAnimation!.value,
                              child: FadeTransition(
                                opacity: _fadeAnimation!,
                                child: SlideTransition(
                                  position: _slideAnimation!,
                                  child: child,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: _toolbarWidth,
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              spacing: _columnGap,
                              runSpacing: 8.0,
                              children: [
                                for (int i = 0; i < tools.length; i++) ...[
                                  SizedBox(
                                    width: _buttonWidth,
                                    child: _buildContributedToolButton(
                                      context,
                                      tools[i],
                                    ),
                                  ),
                                  if (tools[i].action == 'snip_region' &&
                                      studio.pdfDgnlPassages.isNotEmpty) ...[
                                    SizedBox(
                                      width: _buttonWidth,
                                      child: _buildApplyPdfHighlightButton(
                                        context,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPluginBadgeButton(dynamic plugin) {
    return Tooltip(
      message: _isToolsExpanded
          ? 'Bấm để thu gọn công cụ môn học'
          : 'Bấm để mở rộng công cụ môn học',
      child: InkWell(
        key: const Key('subject_badge_button'),
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(9999),
        child: MouseRegion(
          cursor: _isDragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.all(Radius.circular(9999)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.drag_indicator,
                  size: 12,
                  color: AppColors.overlayAccent,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    plugin.manifest.name as String,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.overlayAccent,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                RotationTransition(
                  turns: Tween<double>(begin: 0.0, end: 0.5).animate(
                    CurvedAnimation(
                      parent: _expandController!,
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppColors.overlayAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEyeToggleButton(bool isEyeVisible) {
    return Tooltip(
      message: isEyeVisible
          ? 'Bấm để ẩn lớp chú thích trên bảng'
          : 'Bấm để hiện lớp chú thích trên bảng',
      child: InkWell(
        key: const Key('eye_toggle_button'),
        onTap: () => studio.toggleChalkAnnotationsVisibility(),
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isEyeVisible
                ? const Color(0x2E38BDF8)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isEyeVisible
                  ? AppColors.overlayAccent
                  : AppColors.overlayMuted.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: Icon(
            isEyeVisible ? Icons.visibility : Icons.visibility_off,
            size: 13,
            color: isEyeVisible
                ? AppColors.overlayAccent
                : AppColors.overlayMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Tooltip(
      message: 'Đóng khay công cụ môn học',
      child: InkWell(
        key: const Key('close_palette_button'),
        onTap: () => studio.closePlugin(),
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.overlayMuted.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: const Icon(
            Icons.close,
            size: 13,
            color: AppColors.overlayMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassPresetButton() {
    final preset = studio.glassPreset;
    final icon = switch (preset) {
      GlassPreset.clear => Icons.diamond_outlined,
      GlassPreset.frosted => Icons.ac_unit,
      GlassPreset.solid => Icons.shield_outlined,
    };

    return Semantics(
      key: const Key('glass_preset_button'),
      container: true,
      button: true,
      label: 'Glass appearance',
      value: preset.label,
      hint: 'Cycle clear, frosted, and solid glass',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onFocusChange: (focused) {
            if (_glassPresetFocused != focused) {
              setState(() => _glassPresetFocused = focused);
            }
          },
          onTap: () => studio.setGlassPreset(preset.next),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(
                  color: _glassPresetFocused
                      ? Colors.white
                      : AppColors.overlayMuted.withValues(alpha: 0.4),
                  width: _glassPresetFocused ? 2 : 1,
                ),
              ),
            ),
            child: SizedBox.square(
              dimension: 28,
              child: Icon(icon, size: 14, color: AppColors.overlayAccent),
            ),
          ),
        ),
      ),
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
        : tool.action == 'snip_region'
        ? studio.isSnippingActive
        : false;
    final buttonKey = Key(tool.widgetKey ?? '${tool.id}_tool_button');

    return Tooltip(
      message: tool.tooltip.isNotEmpty ? tool.tooltip : tool.label,
      child: LiquidGlassContainer(
        preset: studio.glassPreset,
        borderRadius: BorderRadius.circular(9999),
        borderColor: Colors.transparent,
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
          borderRadius: BorderRadius.circular(9999),
          child: AnimatedContainer(
            duration: AppMotion.duration(context, milliseconds: 150),
            curve: AppMotion.stateCurve,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0x3338BDF8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: isActive
                    ? AppColors.overlayAccent
                    : AppColors.overlayMuted,
                width: 1.0,
              ),
              boxShadow: isActive
                  ? const [
                      BoxShadow(
                        color: Color(0x3338BDF8),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _resolveIcon(tool.icon),
                  size: 14,
                  color: isActive
                      ? AppColors.overlayAccent
                      : Colors.white,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    tool.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isActive
                          ? AppColors.overlayAccent
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApplyPdfHighlightButton(BuildContext context) {
    return Tooltip(
      message:
          'Áp lớp Highlight chuẩn trực tiếp vào file PDF đang mở (không cần lưu tệp mới)',
      child: LiquidGlassContainer(
        preset: studio.glassPreset,
        borderRadius: BorderRadius.circular(9999),
        borderColor: Colors.transparent,
        child: InkWell(
          key: const Key('btn_palette_save_pdf_highlight'),
          onTap: () =>
              PdfAnnotationExporter.applyHighlightDirectlyToPdf(context, studio),
          borderRadius: BorderRadius.circular(9999),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.draw_rounded, size: 14, color: AppColors.border),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Highlight lên file',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.border,
                    ),
                  ),
                ),
              ],
            ),
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
            const Icon(
              Icons.edit_note,
              color: AppColors.overlayAccent,
              size: 20,
            ),
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
