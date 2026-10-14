import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import '../services/pdf_annotation_exporter.dart';

class SubjectToolPalette extends StatelessWidget {
  const SubjectToolPalette({super.key, required this.studio});

  final StudioState studio;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final plugin = studio.activePlugin;
        if (plugin == null) return const SizedBox.shrink();

        final isSvoActive = studio.activeSubjectTool == 'svo';
        final isEyeVisible = studio.chalkAnnotationsVisible;

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
                  color: const Color(
                    0xf2101c17,
                  ), // Deep slate green chalkboard tone
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSvoActive
                        ? const Color(0xff89b4fa)
                        : const Color(0x55d4e8a6),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle & Subject Badge (Click to toggle Assistant Panel)
                    Tooltip(
                      message: studio.showPluginDrawer
                          ? 'Thu gọn bảng trợ giảng'
                          : 'Mở bảng điều khiển Trợ giảng Tiếng Anh',
                      child: InkWell(
                        key: const Key('subject_badge_button'),
                        onTap: () {
                          studio.openPlugin(
                            plugin,
                            openModal: !studio.showPluginDrawer,
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: studio.showPluginDrawer
                                ? const Color(0x55d4e8a6)
                                : const Color(0x28d4e8a6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x44d4e8a6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.drag_indicator,
                                size: 13,
                                color: Color(0xffa5b5a8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                plugin.manifest.name,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xffd4e8a6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick Scan Paragraph on PDF/Chalkboard (Kéo chụp & Highlight trực tiếp)
                    Tooltip(
                      message:
                          'Kéo chụp đoạn văn trên đề để highlight Ngữ pháp & Từ vựng trực tiếp trên file (PrtSc)',
                      child: InkWell(
                        key: const Key('quick_snip_dgnl_button'),
                        onTap: () => studio.startSnipping(target: 'dgnl'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0x4489b4fa), Color(0x44f5c2e7)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xff89b4fa),
                              width: 1.3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x3389b4fa),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.crop_free,
                                size: 14,
                                color: Color(0xff89b4fa),
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Quét đoạn văn',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xffcdd6f4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (studio.pdfDgnlPassages.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message:
                            'Áp lớp Highlight chuẩn trực tiếp vào file PDF đang mở (không cần lưu tệp mới)',
                        child: InkWell(
                          key: const Key('btn_palette_save_pdf_highlight'),
                          onTap: () =>
                              PdfAnnotationExporter.applyHighlightDirectlyToPdf(context, studio),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x3386efac),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xff86efac),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x2286efac),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.draw_rounded,
                                  size: 14,
                                  color: Color(0xff86efac),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Highlight lên file',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff86efac),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),

                    // S-V-O Tool Toggle Button
                    Tooltip(
                      message: isSvoActive
                          ? 'Đang bật S-V-O (Chạm vào câu để gạch chân)'
                          : 'Bật công cụ bóc tách S-V-O',
                      child: InkWell(
                        key: const Key('svo_tool_button'),
                        onTap: () {
                          studio.setActiveSubjectTool(
                            isSvoActive ? null : 'svo',
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSvoActive
                                ? const Color(0x3d89b4fa)
                                : const Color(0x1fffffff),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSvoActive
                                  ? const Color(0xff89b4fa)
                                  : const Color(0x33ffffff),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: isSvoActive
                                    ? const Color(0xff89b4fa)
                                    : const Color(0xffd4e8a6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Công cụ S-V-O',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSvoActive
                                      ? const Color(0xff89b4fa)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Quick Type / Select Sentence Button (Cách 2: Gõ/chọn câu trên Dock)
                    Tooltip(
                      message:
                          'Nhập hoặc chọn câu tiếng Anh để gạch chân S-V-O-A',
                      child: InkWell(
                        key: const Key('quick_sentence_button'),
                        onTap: () => _showQuickSentenceDialog(context, studio),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1fffffff),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0x33ffffff),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.edit_note,
                                size: 15,
                                color: Color(0xffd4e8a6),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Nhập câu',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Eye Toggle Button (Ẩn / Hiện đáp án)
                    Tooltip(
                      message: isEyeVisible
                          ? 'Bấm để ẩn đáp án S-V-O cho học sinh đoán'
                          : 'Bấm để hiện đáp án S-V-O',
                      child: InkWell(
                        key: const Key('eye_toggle_button'),
                        onTap: () => studio.toggleChalkAnnotationsVisibility(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isEyeVisible
                                ? const Color(0x2886efac)
                                : const Color(0x28f38ba8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isEyeVisible
                                  ? const Color(0x6686efac)
                                  : const Color(0x66f38ba8),
                            ),
                          ),
                          child: Icon(
                            isEyeVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 14,
                            color: isEyeVisible
                                ? const Color(0xff86efac)
                                : const Color(0xfff38ba8),
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
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0x1fffffff),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Color(0xffa5b5a8),
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

  void _showQuickSentenceDialog(BuildContext context, StudioState studio) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xf5101c17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x55d4e8a6), width: 1.2),
        ),
        title: Row(
          children: const [
            Icon(Icons.edit_note, color: Color(0xff89b4fa), size: 20),
            SizedBox(width: 8),
            Text(
              'Nhập / Chọn câu bóc tách S-V-O-A',
              style: TextStyle(
                color: Color(0xffd4e8a6),
                fontSize: 14,
                fontWeight: FontWeight.w700,
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
                'Nhập câu tiếng Anh bất kỳ (thì đơn, thì hoàn thành, bị động, câu ghép...) để spaCy phân tích cú pháp chuẩn xác:',
                style: TextStyle(color: Color(0x99ffffff), fontSize: 11),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: I has been learning Math.',
                  hintStyle: const TextStyle(
                    color: Color(0x66ffffff),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0x22ffffff),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0x33ffffff)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xff89b4fa),
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
              style: TextStyle(color: Color(0x88ffffff)),
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
              backgroundColor: const Color(0xff89b4fa),
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
