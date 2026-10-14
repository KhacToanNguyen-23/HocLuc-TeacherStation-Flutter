import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../services/google_meet_auth_service.dart';
import '../services/local_service.dart';
import '../services/meet_automation_service.dart';
import '../services/teacher_media_service.dart';
import '../widgets/lobby/lobby_header.dart';
import '../widgets/lobby/lobby_media_preview.dart';
import '../widgets/lobby/lobby_meet_room_card.dart';
import '../widgets/auth/google_webview_login_dialog.dart';
import 'studio_screen.dart';

/// Classroom Lobby screen coordinating hardware pre-flight checks,
/// Google Meet room connectivity, and transition to teaching Studio.
class ClassroomLobbyScreen extends StatefulWidget {
  const ClassroomLobbyScreen({
    super.key,
    this.initialMeetingUrl,
    this.initialLessonTitle = 'Bài giảng Chuyên đề mới',
    this.mediaService,
    this.authService,
    this.meetService,
  });

  final String? initialMeetingUrl;
  final String initialLessonTitle;
  final TeacherMediaService? mediaService;
  final GoogleMeetAuthService? authService;
  final MeetAutomationService? meetService;

  @override
  State<ClassroomLobbyScreen> createState() => _ClassroomLobbyScreenState();
}

class _ClassroomLobbyScreenState extends State<ClassroomLobbyScreen> {
  late final TeacherMediaService _mediaService;
  late final GoogleMeetAuthService _authService;
  late final MeetAutomationService _meetService;
  late final TextEditingController _titleController;

  static final RegExp _meetCodeRegex = RegExp(
    r'(?:https?:\/\/)?(?:meet\.google\.com\/)?([a-z]{3}-[a-z]{4}-[a-z]{3})',
    caseSensitive: false,
  );

  static bool isRealGoogleMeetUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return _meetCodeRegex.hasMatch(url.trim());
  }

  static String? extractRealGoogleMeetUrl(String? text) {
    if (text == null) return null;
    final match = _meetCodeRegex.firstMatch(text.trim());
    if (match != null) {
      return 'https://meet.google.com/${match.group(1)!.toLowerCase()}';
    }
    return null;
  }

  String? _currentMeetingUrl;
  String _selectedBackground = 'none';
  String _selectedCamera = 'Webcam HD (Tích hợp trên máy)';
  String _selectedMic = 'Microphone (Realtek High Definition Audio)';
  bool _isCreatingMeet = false;
  Timer? _micMeterTimer;
  double _simulatedDb = -18.0;

  @override
  void initState() {
    super.initState();
    _mediaService = widget.mediaService ?? TeacherMediaService();
    _authService = widget.authService ?? GoogleMeetAuthService();
    _meetService = widget.meetService ?? MeetAutomationService();
    _titleController = TextEditingController(text: widget.initialLessonTitle);

    final incoming = widget.initialMeetingUrl ?? _meetService.meetingUrl;
    if (incoming != null && isRealGoogleMeetUrl(incoming)) {
      _currentMeetingUrl = extractRealGoogleMeetUrl(incoming);
    } else {
      _currentMeetingUrl = null;
    }

    _mediaService.initMedia();
    _startSimulatedMicMeter();

    if (_currentMeetingUrl != null) {
      _syncClassroomToBackend(_currentMeetingUrl!);
    }
  }

  @override
  void dispose() {
    _micMeterTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _startSimulatedMicMeter() {
    _micMeterTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) return;
      if (_mediaService.isMicActive) {
        final variance = (DateTime.now().millisecond % 16) - 8;
        setState(() {
          _simulatedDb = (-18.0 + variance).clamp(-40.0, -2.0);
        });
      } else {
        setState(() {
          _simulatedDb = -40.0;
        });
      }
    });
  }

  Future<void> _syncClassroomToBackend(String meetingUrl) async {
    try {
      final local = LocalService();
      await local.post('classroom/create', data: {
        'directUrl': meetingUrl,
        'title': _titleController.text.trim(),
        'teacherName': _authService.teacherName ?? 'Giáo viên',
        'teacherEmail': _authService.teacherEmail,
      });
    } catch (e) {
      debugPrint('[ClassroomLobby] Sync classroom to backend error: $e');
    }
  }

  void _copyMeetingLink() {
    if (_currentMeetingUrl == null) return;
    Clipboard.setData(ClipboardData(text: _currentMeetingUrl!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã sao chép link lớp học: $_currentMeetingUrl',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleCancelLobby() async {
    try {
      final local = LocalService();
      await local.endClassroom();
    } catch (e) {
      debugPrint('[ClassroomLobby] Error ending classroom on cancel: $e');
    }
    await _meetService.leaveClassroom();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleGenerateNewMeetRoom() async {
    setState(() => _isCreatingMeet = true);
    try {
      var realUrl = await _meetService.generateAndJoinRealMeetRoom();

      if (realUrl == null && _meetService.needsGoogleLogin && mounted) {
        final loginResult = await GoogleWebviewLoginDialog.show(context);
        if (loginResult != null && mounted) {
          realUrl = await _meetService.generateAndJoinRealMeetRoom();
        }
      }

      if (realUrl != null && isRealGoogleMeetUrl(realUrl)) {
        final formatted = extractRealGoogleMeetUrl(realUrl)!;
        setState(() => _currentMeetingUrl = formatted);
        _meetService.setMeetingUrl(formatted);
        await _syncClassroomToBackend(formatted);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã kết nối phòng Google Meet thật: $formatted'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ClassroomLobby] Error creating real meet: $e');
    } finally {
      if (mounted) setState(() => _isCreatingMeet = false);
    }
  }

  Future<void> _pasteMeetingLinkFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bộ nhớ tạm trống! Vui lòng sao chép link Google Meet trước.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final extracted = extractRealGoogleMeetUrl(text);
    if (extracted != null) {
      setState(() => _currentMeetingUrl = extracted);
      _meetService.setMeetingUrl(extracted);
      await _syncClassroomToBackend(extracted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã nhận diện link Google Meet thật: $extracted'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      _showCustomLinkDialog(initialText: text);
    }
  }

  void _showCustomLinkDialog({String? initialText}) {
    final customUrlController = TextEditingController(text: initialText ?? _currentMeetingUrl ?? '');
    String? validationError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.link_rounded, color: AppColors.sky600),
                SizedBox(width: 8),
                Text(
                  'Dán link Google Meet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: customUrlController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'https://meet.google.com/xxx-yyyy-zzz',
                      prefixIcon: const Icon(Icons.videocam_outlined, size: 18),
                      errorText: validationError,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded, size: 18),
                        tooltip: 'Dán từ bộ nhớ tạm',
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null && data!.text!.trim().isNotEmpty) {
                            customUrlController.text = data.text!.trim();
                            setDialogState(() => validationError = null);
                          }
                        },
                      ),
                    ),
                    onChanged: (_) {
                      if (validationError != null) {
                        setDialogState(() => validationError = null);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  final input = customUrlController.text.trim();
                  final extracted = extractRealGoogleMeetUrl(input);
                  if (extracted != null) {
                    setState(() => _currentMeetingUrl = extracted);
                    _meetService.setMeetingUrl(extracted);
                    _syncClassroomToBackend(extracted);
                    Navigator.of(ctx).pop();
                  } else {
                    setDialogState(() {
                      validationError = 'Đường dẫn không hợp lệ. Vui lòng nhập link dạng meet.google.com/xxx-yyyy-zzz';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.sky600, foregroundColor: Colors.white),
                child: const Text('Xác nhận link'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _enterTeachingStudio() {
    if (_currentMeetingUrl == null || !isRealGoogleMeetUrl(_currentMeetingUrl)) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Chưa có link Google Meet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Bạn có thể vào dạy ngoại tuyến hoặc để ứng dụng tự động tạo một phòng Google Meet mới.',
            style: TextStyle(fontSize: 13, color: AppColors.slate700),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _proceedToStudio(meetingUrl: null);
              },
              child: const Text('Vào dạy ngoại tuyến', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleGenerateNewMeetRoom();
              },
              icon: const Icon(Icons.video_call_rounded, size: 16),
              label: const Text('Tự động tạo phòng Meet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      return;
    }

    _proceedToStudio(meetingUrl: _currentMeetingUrl);
  }

  void _proceedToStudio({String? meetingUrl}) {
    if (meetingUrl != null) {
      _meetService.setMeetingUrl(meetingUrl);
      _syncClassroomToBackend(meetingUrl);
    }
    _meetService.ensureHostJoined();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StudioScreen(
          initialState: null,
          lessonTitle: _titleController.text.trim(),
          meetingUrl: meetingUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 960;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleCancelLobby();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: LobbyHeader(
          authService: _authService,
          onBack: _handleCancelLobby,
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LobbyMediaPreview(
                          mediaService: _mediaService,
                          selectedBackground: _selectedBackground,
                          selectedCamera: _selectedCamera,
                          selectedMic: _selectedMic,
                          simulatedDb: _simulatedDb,
                          onBackgroundSelected: (bg) => setState(() => _selectedBackground = bg),
                          onCameraChanged: (cam) => setState(() => _selectedCamera = cam),
                          onMicChanged: (mic) => setState(() => _selectedMic = mic),
                        ),
                        const SizedBox(height: 24),
                        LobbyMeetRoomCard(
                          titleController: _titleController,
                          currentMeetingUrl: _currentMeetingUrl,
                          isCreatingMeet: _isCreatingMeet,
                          mediaService: _mediaService,
                          onCopyLink: _copyMeetingLink,
                          onGenerateNewMeet: _handleGenerateNewMeetRoom,
                          onPasteFromClipboard: _pasteMeetingLinkFromClipboard,
                          onShowCustomLinkDialog: _showCustomLinkDialog,
                          onEnterStudio: _enterTeachingStudio,
                          onCancel: _handleCancelLobby,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: LobbyMediaPreview(
                            mediaService: _mediaService,
                            selectedBackground: _selectedBackground,
                            selectedCamera: _selectedCamera,
                            selectedMic: _selectedMic,
                            simulatedDb: _simulatedDb,
                            onBackgroundSelected: (bg) => setState(() => _selectedBackground = bg),
                            onCameraChanged: (cam) => setState(() => _selectedCamera = cam),
                            onMicChanged: (mic) => setState(() => _selectedMic = mic),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 1,
                          child: LobbyMeetRoomCard(
                            titleController: _titleController,
                            currentMeetingUrl: _currentMeetingUrl,
                            isCreatingMeet: _isCreatingMeet,
                            mediaService: _mediaService,
                            onCopyLink: _copyMeetingLink,
                            onGenerateNewMeet: _handleGenerateNewMeetRoom,
                            onPasteFromClipboard: _pasteMeetingLinkFromClipboard,
                            onShowCustomLinkDialog: _showCustomLinkDialog,
                            onEnterStudio: _enterTeachingStudio,
                            onCancel: _handleCancelLobby,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
