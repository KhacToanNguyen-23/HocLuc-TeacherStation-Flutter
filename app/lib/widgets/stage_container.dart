import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/studio_state.dart';
import 'grid_painter.dart';
import 'pdf_stage.dart';
import 'interactive_chalkboard.dart';
import 'floating_pdf_window.dart';
import 'floating_pip.dart';
import 'drawer_questions.dart';

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
                                      color: const Color(0xffd4e8a6),
                                      width: 2.5,
                                    )
                                  : null,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 16,
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
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: KeyedSubtree(
                                      key: ValueKey(
                                        '${studio.viewportMode}_${studio.pdfOnRight}',
                                      ),
                                      child: _buildStageContent(constraints),
                                    ),
                                  ),
                                ),

                                // Collapsible Left Drawer
                                if (interactive)
                                  Positioned.fill(
                                    child: DrawerQuestions(studio: studio),
                                  ),

                                // Floating Draggable Camera PIP Card
                                if (interactive) FloatingPip(studio: studio),
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
            Positioned.fill(child: _buildChalkboard()),
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
        color: const Color(0xffedf1e8),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xffdbe2d5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            mode: StudioViewportMode.fullBoard,
            icon: Icons.border_clear,
            label: 'Bảng (F1)',
            tooltip: 'Toàn màn hình Bảng viết (F1)',
          ),
          const SizedBox(width: 2),
          _buildButton(
            mode: StudioViewportMode.split,
            icon: Icons.vertical_split_outlined,
            label: 'Chia đôi (F3)',
            tooltip: 'Chia đôi màn hình 50/50 (PDF & Bảng) (F3)',
          ),
          const SizedBox(width: 2),
          _buildButton(
            mode: StudioViewportMode.fullPdf,
            icon: Icons.picture_as_pdf_outlined,
            label: 'PDF (F2)',
            tooltip: 'Toàn màn hình Tài liệu PDF (F2)',
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 16, color: const Color(0xffd0d7ca)),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Nhập tệp PDF từ máy tính',
            child: InkWell(
              onTap: studio.importPdfDialog,
              borderRadius: BorderRadius.circular(7),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffdcebd0),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xffb8d8a2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 14, color: Color(0xff1b473b)),
                    if (!compact) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'Nhập PDF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff1b473b),
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
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: active ? const Color(0xff173e35) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: active
                    ? const Color(0xffd4e8a6)
                    : const Color(0xff4a5f54),
              ),
              if (!compact) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : const Color(0xff4a5f54),
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
