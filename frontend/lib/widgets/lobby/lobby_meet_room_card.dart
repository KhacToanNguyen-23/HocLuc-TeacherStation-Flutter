import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/teacher_media_service.dart';

/// Right panel in Classroom Lobby for Lesson info, Google Meet connection, and entering/canceling the classroom.
class LobbyMeetRoomCard extends StatelessWidget {
  const LobbyMeetRoomCard({
    super.key,
    required this.titleController,
    required this.currentMeetingUrl,
    required this.isCreatingMeet,
    required this.mediaService,
    required this.onCopyLink,
    required this.onGenerateNewMeet,
    required this.onOpenChrome,
    required this.onPasteFromClipboard,
    required this.onShowCustomLinkDialog,
    required this.onEnterStudio,
    this.onCancel,
  });

  final TextEditingController titleController;
  final String? currentMeetingUrl;
  final bool isCreatingMeet;
  final TeacherMediaService mediaService;
  final VoidCallback onCopyLink;
  final VoidCallback onGenerateNewMeet;
  final VoidCallback onOpenChrome;
  final VoidCallback onPasteFromClipboard;
  final VoidCallback onShowCustomLinkDialog;
  final VoidCallback onEnterStudio;
  final VoidCallback? onCancel;

  static final RegExp _meetCodeRegex = RegExp(
    r'(?:https?:\/\/)?(?:meet\.google\.com\/)?([a-z]{3}-[a-z]{4}-[a-z]{3})',
    caseSensitive: false,
  );

  static bool isRealGoogleMeetUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return _meetCodeRegex.hasMatch(url.trim());
  }

  @override
  Widget build(BuildContext context) {
    final hasRealLink = currentMeetingUrl != null && isRealGoogleMeetUrl(currentMeetingUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Classroom Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Topic & Status
              Row(
                children: [
                  const Icon(Icons.school_rounded, size: 20, color: AppColors.sky600),
                  const SizedBox(width: 8),
                  const Text(
                    'Thông tin Buổi học',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasRealLink ? AppColors.emerald50 : AppColors.amber50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasRealLink ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: hasRealLink ? AppColors.emerald600 : AppColors.amber600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hasRealLink ? 'Sẵn sàng' : 'Chưa có link',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: hasRealLink ? AppColors.emerald600 : AppColors.amber600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title input
              TextField(
                controller: titleController,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate900),
                decoration: InputDecoration(
                  hintText: 'Nhập tên bài học...',
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.slate500),
                  filled: true,
                  fillColor: AppColors.slate50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.slate200),
              const SizedBox(height: 16),

              // Google Meet Channel Header
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Kênh Phát sóng Google Meet',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate800),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (hasRealLink) ...[
                // Meeting URL Container with Copy Action
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 18, color: AppColors.blue600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          currentMeetingUrl!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: onCopyLink,
                        icon: const Icon(Icons.copy_rounded, size: 13),
                        label: const Text('Sao chép', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          elevation: 0,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Supplementary Actions
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: isCreatingMeet ? null : onGenerateNewMeet,
                      icon: isCreatingMeet
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.autorenew_rounded, size: 14),
                      label: const Text('Tạo link mới', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    TextButton.icon(
                      onPressed: onOpenChrome,
                      icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                      label: const Text('Mở trên Chrome', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    TextButton.icon(
                      onPressed: onShowCustomLinkDialog,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Dán link có sẵn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ] else ...[
                // Banner warning
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.amber50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.amber600),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chưa có phòng Meet thật. Bấm tạo link mới để học sinh có thể tham gia.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isCreatingMeet ? null : onGenerateNewMeet,
                        icon: isCreatingMeet
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.video_call_rounded, size: 15),
                        label: const Text('Tạo link mới', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenChrome,
                        icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                        label: const Text('Mở Chrome', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.slate700,
                          side: const BorderSide(color: AppColors.slate300),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onPasteFromClipboard,
                      icon: const Icon(Icons.paste_rounded, size: 14),
                      label: const Text('Dán từ Clipboard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onShowCustomLinkDialog,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Dán link có sẵn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Big Primary CTA Button: Vào phòng giảng dạy
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: onEnterStudio,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'BẮT ĐẦU VÀO PHÒNG GIẢNG DẠY',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Button: HỦY / QUAY LẠI DASHBOARD
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text(
              'HỦY / QUAY LẠI DASHBOARD',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.slate600,
              side: const BorderSide(color: AppColors.slate300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
