import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';
import 'package:teaching_companion/features/studio_board/services/audience_output_service.dart';
import 'package:teaching_companion/features/studio_board/services/teacher_notes_privacy.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';

/// Collapsible presenter speaker notes bar attached below the canvas/slide.
/// Hidden during source selection or unverified capture; synchronized per-page.
class StudioSpeakerNotesBar extends StatefulWidget {
  const StudioSpeakerNotesBar({super.key, required this.studio});

  final StudioState studio;

  @override
  State<StudioSpeakerNotesBar> createState() => _StudioSpeakerNotesBarState();
}

class _StudioSpeakerNotesBarState extends State<StudioSpeakerNotesBar> {
  bool _isExpanded = false;
  bool _manuallyToggled = false;
  late final TextEditingController _controller;
  String _lastTarget = "";

  @override
  void initState() {
    super.initState();
    _isExpanded =
        widget.studio.teacherNoteText.isNotEmpty ||
        widget.studio.teacherActivityNote.isNotEmpty;
    _lastTarget = widget.studio.teacherTargetLabel;
    _controller = TextEditingController(text: widget.studio.teacherNoteText);
    widget.studio.addListener(_onStudioChanged);
  }

  @override
  void dispose() {
    widget.studio.removeListener(_onStudioChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStudioChanged() {
    if (_lastTarget != widget.studio.teacherTargetLabel ||
        _controller.text != widget.studio.teacherNoteText) {
      _lastTarget = widget.studio.teacherTargetLabel;
      final newNote = widget.studio.teacherNoteText;
      if (_controller.text != newNote) {
        _controller.text = newNote;
      }
    }
    if (!_manuallyToggled) {
      _isExpanded =
          widget.studio.teacherNoteText.isNotEmpty ||
          widget.studio.teacherActivityNote.isNotEmpty;
    }
    if (mounted) setState(() {});
  }

  void _onNoteChanged(String text) {
    widget.studio.setTeacherNote(text);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      MeetAutomationService(),
      AudienceOutputService.instance,
    ]),
    builder: (context, _) => _buildProtected(context),
  );

  Widget _buildProtected(BuildContext context) {
    final meet = MeetAutomationService();
    final audience = AudienceOutputService.instance;
    if (!canShowTeacherNotes(
      sharing: meet.isScreenSharing,
      selecting: meet.isSelectingShare,
      outputFresh: audience.fresh,
      audienceTitle: audience.windowTitle,
      sources: meet.screenShareSources,
    )) {
      return const Material(
        color: AppColors.surfaceMuted,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Ghi chú đã ẩn: nguồn chia sẻ chưa được xác minh là cửa sổ trình chiếu riêng.',
          ),
        ),
      );
    }
    final pageNum = widget.studio.page + 1;
    final targetLabel = widget.studio.teacherTargetLabel;
    final pageTitle = widget.studio.page < widget.studio.pageTitles.length
        ? widget.studio.pageTitles[widget.studio.page]
        : 'Trang $pageNum';
    final currentNote = widget.studio.teacherNoteText.isEmpty
        ? widget.studio.teacherActivityNote
        : widget.studio.teacherNoteText;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
            onTap: () => setState(() {
              _manuallyToggled = true;
              _isExpanded = !_isExpanded;
            }),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                  Flexible(
                    child: Text(
                      'Ghi chú · $targetLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
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
                  IconButton(
                    key: const Key('teacher_notes_pin'),
                    tooltip: widget.studio.teacherNotesPinned
                        ? 'Trở lại tự động theo trang'
                        : 'Ghim ghi chú hiện tại',
                    onPressed: widget.studio.teacherNotesPinned
                        ? widget.studio.followTeacherNotes
                        : widget.studio.pinTeacherNotes,
                    icon: Icon(
                      widget.studio.teacherNotesPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: AppColors.textMuted,
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
                  if (widget.studio.teacherActivities.isNotEmpty) ...[
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              widget.studio.stepPresentedActivity(-1),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Phần trước'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              widget.studio.stepPresentedActivity(1),
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Phần tiếp'),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      key: const Key('presenter_activity_selector'),
                      value: widget.studio.activeTeacherActivity?['id']
                          ?.toString(),
                      hint: const Text('Chọn hoạt động đang giảng'),
                      isExpanded: true,
                      items: widget.studio.teacherActivities
                          .map(
                            (activity) => DropdownMenuItem<String>(
                              value: activity['id']?.toString(),
                              child: Text(
                                '${activity['title'] ?? 'Hoạt động'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (!widget.studio.presentActivity(id)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Chưa mở được trang đã gắn. Kiểm tra tài liệu của hoạt động.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.studio.teacherActivityNote.isNotEmpty) ...[
                    const Text(
                      'Lời nhắc của hoạt động',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SelectableText(
                      widget.studio.teacherActivityNote,
                      maxLines: 3,
                      key: const Key('presenter_activity_notes'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    'Ghi chú của trang',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                          'Lời nhắc, câu hỏi gợi mở hoặc đáp án cho $targetLabel...',
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
                          'Ghi chú theo trang nằm trong bản lưu của giáo viên. Xuất kèm ghi chú chỉ khi bạn chủ động chọn.',
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
