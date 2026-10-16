import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'package:flutter/services.dart';
import '../services/meet_automation_service.dart';
import '../services/url_opener.dart';

class CreateClassroomDialog extends StatefulWidget {
  const CreateClassroomDialog({super.key});

  @override
  State<CreateClassroomDialog> createState() => _CreateClassroomDialogState();
}

class _CreateClassroomDialogState extends State<CreateClassroomDialog> {
  final _service = MeetAutomationService();
  final _urlInputController = TextEditingController();
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    if (_service.meetingUrl != null) {
      _urlInputController.text = _service.meetingUrl!;
    } else if (!_service.hasRoom && _service.status != MeetStatus.creating) {
      _service.createClassroom();
    }
  }

  @override
  void dispose() {
    _urlInputController.dispose();
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      if (_service.meetingUrl != null && _urlInputController.text.isEmpty) {
        _urlInputController.text = _service.meetingUrl!;
      }
      setState(() {});
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _service.status;
    final url = _service.meetingUrl;
    final isCreating = status == MeetStatus.creating;
    final hasUrl = url != null && url.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 490,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFF1E222D),
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(color: Colors.white12, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.video_call_rounded,
                    color: Color(0xFF60A5FA),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phòng Google Meet lớp học',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kết nối phòng học trực tuyến cho học sinh',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 22),

            if (isCreating) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: const Column(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Đang kết nối Google Meet...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (hasUrl) ...[
                // Banner thông báo sẵn sàng
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Phòng học đã sẵn sàng để gửi học sinh!',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Ô Link & Nút Copy + Mở Meet
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          url,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Mở Google Meet trên tab mới',
                        child: IconButton(
                          icon: const Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                          onPressed: () => openExternalUrl(url),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _copyLink(url),
                        icon: Icon(
                          _copied ? Icons.check : Icons.copy_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        label: Text(_copied ? 'Đã chép' : 'Sao chép'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _copied
                              ? AppColors.success
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Cho phép nhập hoặc dán link Meet thật
                TextField(
                  controller: _urlInputController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Dán Link Google Meet của bạn',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'https://meet.google.com/xxx-yyyy-zzz',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.link_rounded,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          openExternalUrl('https://meet.google.com/new'),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Mở tạo phòng Meet mới'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF60A5FA),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Nút hành động chính
              FilledButton.icon(
                onPressed: () {
                  if (_urlInputController.text.trim().isNotEmpty) {
                    _service.setMeetingUrl(_urlInputController.text.trim());
                  }
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Xác nhận & Giảng dạy'),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
