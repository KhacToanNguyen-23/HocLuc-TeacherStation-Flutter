import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/meet_events.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/core/platform/url_opener.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/google_meet_view.dart';
import 'package:teaching_companion/core/ui/google_brand_icon.dart';

class StudioMeetCockpitTab extends StatefulWidget {
  const StudioMeetCockpitTab({
    super.key,
    required this.meetService,
    required this.authService,
    this.sharingPanel = false,
  });

  final MeetAutomationService meetService;
  final GoogleMeetAuthService authService;
  final bool sharingPanel;

  @override
  State<StudioMeetCockpitTab> createState() => _StudioMeetCockpitTabState();
}

class _StudioMeetCockpitTabState extends State<StudioMeetCockpitTab> {
  bool _meetExpanded = false;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void dispose() {
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _muteAllParticipants() async {
    final muted = await widget.meetService.muteAllParticipants();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          muted
              ? 'Đã gửi yêu cầu tắt tiếng mic cả lớp đến Google Meet.'
              : 'Không tìm thấy nút tắt tiếng trong Google Meet. Hãy kiểm tra quyền chủ trì.',
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      final target = _chatScrollController.position.maxScrollExtent;
      final duration = AppMotion.duration(context, milliseconds: 250);
      if (duration == Duration.zero) {
        _chatScrollController.jumpTo(target);
        // The lazy list resolves its final extent after the jump lays out
        // the newest bubbles. Keep the latest message visible without motion.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _chatScrollController.hasClients) {
            _chatScrollController.jumpTo(
              _chatScrollController.position.maxScrollExtent,
            );
          }
        });
      } else {
        _chatScrollController.animateTo(
          target,
          duration: duration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    widget.meetService.sendChatMessage(text);
    _chatInputController.clear();
    _scrollToBottom();
  }

  Future<void> _expandMeet() async {
    setState(() => _meetExpanded = true);
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(child: Text('Google Meet')),
                  IconButton(
                    tooltip: 'Thu gọn Meet',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(child: GoogleMeetView(service: widget.meetService)),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _meetExpanded = false);
  }

  Widget _buildChatBubble(MeetChatMessage msg) {
    final isSelf = msg.isSelf;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isSelf
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.sender,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelf ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                msg.time,
                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: isSelf ? AppColors.primary : AppColors.surfaceMuted,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(10),
                topRight: const Radius.circular(10),
                bottomLeft: Radius.circular(isSelf ? 10 : 2),
                bottomRight: Radius.circular(isSelf ? 2 : 10),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 12,
                color: isSelf ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetService = widget.meetService;
    final meetUrl = meetService.meetingUrl;
    final hasRoom = meetService.hasRoom;
    final hands = meetService.raisedHands;
    final messages = meetService.messages;

    if (meetService.showEmbeddedMeet) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const GoogleBrandIcon(size: 16),
                    const SizedBox(width: 6),
                    Icon(
                      meetService.isHostJoined
                          ? Icons.check_circle_outline
                          : Icons.videocam_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meetService.isHostJoined
                            ? (widget.sharingPanel
                                  ? 'Meet khi chia sẻ'
                                  : 'Đã tham gia Meet')
                            : 'Chuẩn bị Meet',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sao chép link Meet',
                      onPressed: meetUrl == null
                          ? null
                          : () =>
                                Clipboard.setData(ClipboardData(text: meetUrl)),
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Phóng lớn Meet trong ứng dụng',
                      onPressed: _expandMeet,
                      icon: const Icon(Icons.open_in_full, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _meetExpanded
                ? const Center(child: Text('Meet đang mở trong cửa sổ lớn.'))
                : SizedBox.expand(child: GoogleMeetView(service: meetService)),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Status Card & Room Link
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasRoom ? AppColors.successSurface : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const GoogleBrandIcon(size: 16),
                    const SizedBox(width: 6),
                    Icon(
                      meetService.isHostJoined
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: hasRoom ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasRoom
                            ? meetService.isHostJoined
                                  ? 'Đã tham gia Google Meet'
                                  : 'Chuẩn bị Google Meet'
                            : 'Chưa khởi tạo phòng học',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hasRoom
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (meetService.isHostJoined)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
                if (meetUrl != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meetUrl,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Sao chép link gửi học sinh',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: meetUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép link Google Meet!'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      if (meetService.showEmbeddedMeet)
                        IconButton(
                          icon: const Icon(Icons.open_in_full, size: 15),
                          tooltip: 'Phóng lớn Meet trong ứng dụng',
                          onPressed: _expandMeet,
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Mở Google Meet ngoài',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => openExternalUrl(meetUrl),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Raised Hands Banner
        if (hands.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.front_hand_outlined,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang giơ tay: ${hands.join(", ")}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Quick Actions (Mute All)
        if (hasRoom)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                    ),
                    onPressed: meetService.isHostJoined
                        ? _muteAllParticipants
                        : null,
                    icon: const Icon(Icons.mic_off_outlined, size: 14),
                    label: const Text(
                      'Tắt tiếng cả lớp',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const Divider(height: 1, color: AppColors.line),

        if (meetService.showEmbeddedMeet)
          Expanded(
            flex: meetService.isHostJoined ? 1 : 2,
            child: _meetExpanded
                ? const Center(child: Text('Meet đang mở trong cửa sổ lớn.'))
                : SizedBox.expand(child: GoogleMeetView(service: meetService)),
          ),

        // Live Chat Area
        Expanded(
          flex: 1,
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 36,
                          color: AppColors.border,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Chưa có tin nhắn trong phòng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasRoom
                              ? 'Tin nhắn học sinh gửi từ Meet sẽ xuất hiện ngay tại đây.'
                              : 'Khởi tạo phòng Meet để bắt đầu nhận tin nhắn của học sinh.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildChatBubble(msg);
                  },
                ),
        ),

        const Divider(height: 1, color: AppColors.line),

        // Chat Input Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                  ),
                  child: TextField(
                    controller: _chatInputController,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Nhắn cho học sinh trên Meet…',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  onPressed: _handleSendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
