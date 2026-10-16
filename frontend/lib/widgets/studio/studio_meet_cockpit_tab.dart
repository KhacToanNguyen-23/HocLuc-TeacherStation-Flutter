import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import '../../models/meet_events.dart';
import '../../services/google_meet_auth_service.dart';
import '../../services/meet_automation_service.dart';
import '../../services/url_opener.dart';
import '../google_meet_view.dart';

class StudioMeetCockpitTab extends StatefulWidget {
  const StudioMeetCockpitTab({
    super.key,
    required this.meetService,
    required this.authService,
  });

  final MeetAutomationService meetService;
  final GoogleMeetAuthService authService;

  @override
  State<StudioMeetCockpitTab> createState() => _StudioMeetCockpitTabState();
}

class _StudioMeetCockpitTabState extends State<StudioMeetCockpitTab> {
  bool _meetExpanded = false;
  bool _sendingChat = false;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void dispose() {
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    if (_sendingChat) return;
    final draft = _chatInputController.text;
    final text = draft.trim();
    if (text.isEmpty) return;
    setState(() => _sendingChat = true);
    bool requested;
    try {
      requested = await widget.meetService.sendChatMessage(text);
    } finally {
      if (mounted) setState(() => _sendingChat = false);
    }
    if (!mounted) return;
    if (!requested) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa gửi được. Mở Chat trong Google Meet để gửi tin nhắn.',
          ),
        ),
      );
      return;
    }
    if (_chatInputController.text == draft) _chatInputController.clear();
    _scrollToBottom();
  }

  Future<void> _expandMeet() async {
    setState(() => _meetExpanded = true);
    await showDialog<void>(context: context, builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: Text('Google Meet · ${widget.meetService.linkedTeacherEmail}')),
          IconButton(tooltip: 'Thu gọn Meet', onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
        ])),
        Expanded(child: GoogleMeetView(service: widget.meetService)),
      ]),
    ));
    if (mounted) setState(() => _meetExpanded = false);
  }

  Widget _buildChatBubble(MeetChatMessage msg) {
    final isSelf = msg.isSelf;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.sender,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelf ? AppColors.sky600 : AppColors.slate600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                msg.time,
                style: const TextStyle(fontSize: 9, color: AppColors.slate400),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: isSelf ? AppColors.sky600 : AppColors.slate100,
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
                color: isSelf ? Colors.white : AppColors.slate800,
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
      return Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(meetService.isHostJoined ? Icons.check_circle_outline : Icons.videocam_outlined, size: 18, color: AppColors.sky600),
            const SizedBox(width: 8),
            Expanded(child: Text(meetService.isHostJoined ? 'Đã tham gia Meet' : 'Chuẩn bị Meet', style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Sao chép link Meet', onPressed: meetUrl == null ? null : () => Clipboard.setData(ClipboardData(text: meetUrl)), icon: const Icon(Icons.copy, size: 18)),
            IconButton(tooltip: 'Phóng lớn Meet trong ứng dụng', onPressed: _expandMeet, icon: const Icon(Icons.open_in_full, size: 18)),
          ]),
          if (meetService.linkedTeacherEmail != null) Text('Dùng tài khoản ${meetService.linkedTeacherEmail}', style: const TextStyle(fontSize: 11, color: AppColors.slate600)),
          if (meetService.linkedTeacherEmail != null && !meetService.isHostJoined)
            const Text('Lần đầu: nếu Meet yêu cầu đăng nhập, chọn tài khoản đã kết nối ở trên. Các lần sau dùng lại phiên đã lưu.', style: TextStyle(fontSize: 11, color: AppColors.slate600)),
        ])),
        Expanded(child: _meetExpanded ? const Center(child: Text('Meet đang mở trong cửa sổ lớn.')) : GoogleMeetView(service: meetService)),
      ]);
    }

    return Column(
      children: [
        // Status Card & Room Link
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasRoom ? AppColors.emerald50 : AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasRoom ? const Color(0xffbbf7d0) : AppColors.slate200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      meetService.isHostJoined ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: hasRoom ? AppColors.emerald600 : AppColors.slate400,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasRoom
                            ? meetService.isHostJoined ? 'Đã tham gia Google Meet' : 'Chuẩn bị Google Meet'
                            : 'Chưa khởi tạo phòng học',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hasRoom ? const Color(0xff15803d) : AppColors.slate700,
                        ),
                      ),
                    ),
                    if (meetService.isHostJoined)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xffdcfce7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff166534),
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
                            color: AppColors.blue600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 15, color: AppColors.blue600),
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
                        icon: const Icon(Icons.open_in_new_rounded, size: 15, color: AppColors.slate600),
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
                color: AppColors.amber50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xfffed7aa)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.front_hand_outlined, size: 16, color: Color(0xff9a3412)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang giơ tay: ${hands.join(", ")}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xff9a3412)),
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
                      foregroundColor: AppColors.rose600,
                      side: const BorderSide(color: Color(0xfffecaca)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.mic_off_outlined, size: 14),
                    label: const Text('Tắt tiếng trong Google Meet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

        const Divider(height: 1, color: AppColors.line),

        if (meetService.showEmbeddedMeet)
          Expanded(child: _meetExpanded
            ? const Center(child: Text('Meet đang mở trong cửa sổ lớn.'))
            : GoogleMeetView(service: meetService)),

        // Live Chat Area
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text(
                          'Chưa có tin nhắn trong phòng',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasRoom
                              ? 'Tin nhắn học sinh gửi từ Meet sẽ xuất hiện ngay tại đây.'
                              : 'Khởi tạo phòng Meet để bắt đầu nhận tin nhắn của học sinh.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: TextField(
                    controller: _chatInputController,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Nhắn cho học sinh trên Meet…',
                      hintStyle: TextStyle(fontSize: 11, color: AppColors.slate400),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  color: AppColors.sky600,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  onPressed: _sendingChat ? null : _handleSendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
