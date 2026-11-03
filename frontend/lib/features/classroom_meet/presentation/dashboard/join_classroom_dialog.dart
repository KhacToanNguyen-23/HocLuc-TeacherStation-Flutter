import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/core/platform/url_opener.dart';
import 'package:teaching_companion/features/classroom_meet/services/teaching_launcher.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';

/// Dialog to join a classroom via Google Meet link or room code.
class JoinClassroomDialog extends StatefulWidget {
  const JoinClassroomDialog({super.key, this.onJoin});
  final Future<void> Function(String)? onJoin;

  static Future<void> show(BuildContext context) {
    return showAppModalDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => JoinClassroomDialog(
        onJoin: (url) => TeachingLauncher.open(
          context,
          TeachingTarget(title: 'Buổi học từ link Meet', meetingUrl: url),
        ),
      ),
    );
  }

  @override
  State<JoinClassroomDialog> createState() => _JoinClassroomDialogState();
}

class _JoinClassroomDialogState extends State<JoinClassroomDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  static final _meetRegex = RegExp(
    r'(?:https?:\/\/)?(?:meet\.google\.com\/)?([a-z]{3}-[a-z]{4}-[a-z]{3})',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(
        () => _errorMessage = 'Vui lòng nhập link hoặc mã phòng Google Meet',
      );
      return;
    }

    final match = _meetRegex.firstMatch(input);
    if (match == null) {
      setState(
        () => _errorMessage =
            'Mã phòng không hợp lệ! Vui lòng nhập link dạng meet.google.com/xxx-yyyy-zzz hoặc mã xxx-yyyy-zzz do Google cấp.',
      );
      return;
    }

    final validUrl = 'https://meet.google.com/${match.group(1)!.toLowerCase()}';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final open = widget.onJoin;
      if (open == null) throw StateError('Không tìm thấy màn hình mở lớp.');
      Navigator.of(context).pop();
      await open(validUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể kết nối phòng học: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slate = AppColors.textPrimary;
    final sky = AppColors.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.selected,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Center(
                    child: Icon(Icons.add_link_rounded, color: sky, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tham gia phòng học',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: slate,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'https://meet.google.com/xxx-yyyy-zzz',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: Icon(Icons.link_rounded, size: 18, color: sky),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  tooltip: 'Dán từ bộ nhớ tạm',
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      setState(() {
                        _controller.text = data.text!.trim();
                        _errorMessage = null;
                      });
                    }
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: sky, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _handleJoin(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openExternalUrl('https://meet.google.com/new'),
                icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                label: const Text(
                  'Mở Chrome tạo phòng mới',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: sky,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sky,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Vào phòng học',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


