import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';

/// Collapsible presenter speaker notes bar attached below the canvas/slide.
/// Only visible to the teacher; automatically synchronized per-page.
class StudioSpeakerNotesBar extends StatefulWidget {
  const StudioSpeakerNotesBar({super.key, required this.studio});

  final StudioState studio;

  @override
  State<StudioSpeakerNotesBar> createState() => _StudioSpeakerNotesBarState();
}

class _StudioSpeakerNotesBarState extends State<StudioSpeakerNotesBar> {
  bool _isExpanded = false;
  late final TextEditingController _controller;
  int _lastPageIndex = 0;
  int _lastTotalPages = 0;
  String _lastTitle = '';
  String _lastNote = '';

  @override
  void initState() {
    super.initState();
    _lastPageIndex = widget.studio.page;
    _lastTotalPages = widget.studio.pages.length;
    _lastTitle = _currentTitle();
    _lastNote = widget.studio.currentPageNote;
    _controller = TextEditingController(text: widget.studio.currentPageNote);
    widget.studio.addListener(_onStudioChanged);
  }

  @override
  void dispose() {
    widget.studio.removeListener(_onStudioChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStudioChanged() {
    final pageChanged = _lastPageIndex != widget.studio.page;
    final title = _currentTitle();
    final total = widget.studio.pages.length;
    final note = widget.studio.currentPageNote;
    final changed =
        pageChanged ||
        title != _lastTitle ||
        total != _lastTotalPages ||
        note != _lastNote;
    if (pageChanged) {
      _lastPageIndex = widget.studio.page;
      if (_controller.text != note) {
        _controller.text = note;
      }
    }
    _lastTitle = title;
    _lastTotalPages = total;
    _lastNote = note;
    // The screen shell no longer rebuilds on every studio change, so refresh
    // whenever any value this bar displays changes.
    if (changed && mounted) setState(() {});
  }

  String _currentTitle() {
    final studio = widget.studio;
    return studio.page < studio.pageTitles.length
        ? studio.pageTitles[studio.page]
        : 'Trang ${studio.page + 1}';
  }

  void _onNoteChanged(String text) {
    widget.studio.setPageNote(widget.studio.page, text);
  }

  @override
  Widget build(BuildContext context) {
    final pageNum = widget.studio.page + 1;
    final totalPages = widget.studio.pages.length;
    final pageTitle = widget.studio.page < widget.studio.pageTitles.length
        ? widget.studio.pageTitles[widget.studio.page]
        : 'Trang $pageNum';
    final currentNote = widget.studio.currentPageNote;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Collapsed Bar
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.sky50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.sticky_note_2_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ghi chú Trang $pageNum/$totalPages',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (pageTitle.isNotEmpty &&
                      pageTitle != 'Trang $pageNum') ...[
                    Flexible(
                      child: Text(
                        ' · $pageTitle',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (!_isExpanded) ...[
                    Expanded(
                      child: Text(
                        currentNote.isEmpty
                            ? '(Chưa có ghi chú nhắc bài - bấm để mở)'
                            : currentNote.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: currentNote.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: currentNote.isEmpty
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 11,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Chỉ giáo viên thấy',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Đóng thanh ghi chú',
                    child: InkWell(
                      key: const Key('btn_close_speaker_notes'),
                      onTap: () => widget.studio.setSpeakerNotesOpen(false),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content Area
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: _onNoteChanged,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Ghi chú điểm cần nhấn mạnh, câu hỏi gợi mở hoặc đáp án cho Trang $pageNum...',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ghi chú được lưu tự động theo từng trang và sẵn sàng xuất tài liệu học tập.',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('btn_export_handout_notes'),
                        onPressed: () {
                          PdfAnnotationExporter.exportHandoutWithNotesToPdf(
                            context,
                            widget.studio,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'Xuất Handout (Slide + Ghi chú)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


