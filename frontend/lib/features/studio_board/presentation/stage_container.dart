import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'grid_painter.dart';
import 'pdf_stage.dart';
import 'interactive_chalkboard.dart';
import 'floating_pdf_window.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/floating_pip.dart';
import 'studio/studio_document_drawer.dart';
import 'subject_tool_palette.dart';
import 'presentation_surface.dart';
import 'region_snipping_overlay.dart';
import 'package:teaching_companion/features/plugin_engine/presentation/floating_plugin_window.dart';
import 'package:teaching_companion/features/plugin_engine/presentation/plugin_host_drawer.dart';
import '../services/pdf_annotation_exporter.dart';

class StageContainer extends StatelessWidget {
  const StageContainer({
    super.key,
    required this.studio,
    this.interactive = true,
  });

  final StudioState studio;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    studio.onApplyHighlightToPdfRequested = () =>
        PdfAnnotationExporter.applyHighlightDirectlyToPdf(context, studio);
    studio.onSaveHighlightedPdfRequested = () =>
        PdfAnnotationExporter.saveHighlightedPdf(context, studio);

    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f1): () =>
                studio.setViewportMode(StudioViewportMode.fullBoard),
            const SingleActivator(LogicalKeyboardKey.f2): () =>
                studio.setViewportMode(StudioViewportMode.fullPdf),
            const SingleActivator(LogicalKeyboardKey.f3): () =>
                studio.setViewportMode(StudioViewportMode.split),
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
              if (studio.canUndo) studio.undo();
            },
            const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
              if (studio.canRedo) studio.redo();
            },
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              control: true,
              shift: true,
            ): () {
              if (studio.canRedo) studio.redo();
            },
          },
          child: Focus(
            autofocus: true,
            child: DropTarget(
              onDragDone: (detail) async {
                for (final file in detail.files) {
                  if (file.name.toLowerCase().endsWith('.pdf')) {
                    final bytes = await file.readAsBytes();
                    studio.addImportedDoc(file.name, file.path, bytes);
                  }
                }
              },
              child: DragTarget<ImportedDocument>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) {
                  final RenderBox? renderBox =
                      context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final local = renderBox.globalToLocal(details.offset);
                    studio.setPdfWindowPosition(local);
                  }
                  studio.selectDoc(
                    details.data.id,
                    targetMode: StudioViewportMode.split,
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: chalkboardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: isHovering
                                  ? Border.all(
                                      color: AppColors.onPrimary,
                                      width: 2.5,
                                    )
                                  : null,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                // Viewport Mode Content
                                Positioned.fill(
                                  child: PresentationSurface(
                                    studio: studio,
                                    manageCamera: interactive,
                                    child: AnimatedSwitcher(
                                      duration: AppMotion.duration(
                                        context,
                                        milliseconds: 200,
                                      ),
                                      switchInCurve: AppMotion.enterCurve,
                                      switchOutCurve: AppMotion.exitCurve,
                                      child: KeyedSubtree(
                                        key: ValueKey(
                                          '${studio.viewportMode}_${studio.pdfOnRight}',
                                        ),
                                        child: _buildStageContent(constraints),
                                      ),
                                    ),
                                  ),
                                ),

                                // Collapsible Left Drawer
                                if (interactive)
                                  Positioned.fill(
                                    child: StudioDocumentDrawer(studio: studio),
                                  ),

                                // Floating Draggable Camera PIP Card
                                if (interactive)
                                  Positioned.fill(
                                    child: FloatingPip(studio: studio),
                                  ),

                                // Floating In-Board Subject Tool Palette Dock
                                if (interactive && studio.activePlugin != null)
                                  SubjectToolPalette(studio: studio),

                                // Floating Plugin Window (e.g. Casio Calculator, floating tools)
                                if (interactive)
                                  FloatingPluginWindow(studio: studio),

                                // Docked Plugin Host Drawer (e.g. side drawer plugins)
                                if (interactive)
                                  PluginHostDrawer(studio: studio),

                                // PrtSc Drag Snipping Overlay
                                if (interactive && studio.isSnippingActive)
                                  Positioned.fill(
                                    child: RegionSnippingOverlay(
                                      studio: studio,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStageContent(BoxConstraints constraints) {
    switch (studio.viewportMode) {
      case StudioViewportMode.fullBoard:
        return _buildChalkboard();
      case StudioViewportMode.fullPdf:
        return PdfStage(studio: studio, interactive: interactive);
      case StudioViewportMode.split:
        return Stack(
          children: [
            Positioned.fill(child: RepaintBoundary(child: _buildChalkboard())),
            FloatingPdfWindow(
              studio: studio,
              boardConstraints: constraints,
              interactive: interactive,
            ),
          ],
        );
    }
  }

  Widget _buildChalkboard() {
    return InteractiveChalkboard(studio: studio, interactive: interactive);
  }
}

class ViewportModeSwitcher extends StatelessWidget {
  const ViewportModeSwitcher({
    super.key,
    required this.studio,
    this.compact = false,
  });

  final StudioState studio;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            context: context,
            mode: StudioViewportMode.fullBoard,
            icon: Icons.border_clear,
            label: 'Bảng (F1)',
            tooltip: 'Toàn màn hình Bảng viết (F1)',
          ),
          const SizedBox(width: 2),
          _buildButton(
            context: context,
            mode: StudioViewportMode.split,
            icon: Icons.vertical_split_outlined,
            label: 'Chia đôi (F3)',
            tooltip: 'Chia đôi màn hình 50/50 (PDF & Bảng) (F3)',
          ),
          const SizedBox(width: 2),
          _buildButton(
            context: context,
            mode: StudioViewportMode.fullPdf,
            icon: Icons.picture_as_pdf_outlined,
            label: 'PDF (F2)',
            tooltip: 'Toàn màn hình Tài liệu PDF (F2)',
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 16, color: AppColors.border),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Nhập tệp PDF từ máy tính',
            child: InkWell(
              onTap: studio.importPdfDialog,
              borderRadius: BorderRadius.circular(7),
              child: AnimatedContainer(
                duration: AppMotion.duration(context, milliseconds: 150),
                curve: AppMotion.stateCurve,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.selected,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add,
                      size: 14,
                      color: AppColors.onSelected,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'Nhập PDF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSelected,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (studio.pdfFilePath != null || studio.pdfBytes != null) ...[
            const SizedBox(width: 2),
            Tooltip(
              message: 'Đóng tài liệu PDF',
              child: InkWell(
                onTap: () {
                  studio.setPdfFile(null, null);
                  studio.setViewportMode(StudioViewportMode.fullBoard);
                },
                borderRadius: BorderRadius.circular(7),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(Icons.close, size: 14, color: Color(0xffd32f2f)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required StudioViewportMode mode,
    required IconData icon,
    required String label,
    required String tooltip,
  }) {
    final active = studio.viewportMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => studio.setViewportMode(mode),
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, milliseconds: 150),
          curve: AppMotion.stateCurve,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? AppColors.onPrimary : AppColors.textSecondary,
              ),
              if (!compact) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

