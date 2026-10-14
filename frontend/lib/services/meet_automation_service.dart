import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'camera_broadcast_service.dart';
import '../models/meet_events.dart';
import 'google_meet_auth_service.dart';
import 'local_service.dart';
import 'meet_bridge_script.dart';
import 'webview_environment_service.dart';

enum MeetStatus {
  idle,
  creating,
  ready,
  error,
}

class MeetAutomationService extends ChangeNotifier {
  static final MeetAutomationService _instance = MeetAutomationService._internal();
  factory MeetAutomationService() => _instance;
  MeetAutomationService._internal() {
    CameraBroadcastService().addListener(() {
      final broadcasting = CameraBroadcastService().isBroadcasting;
      if (_isBroadcasting != broadcasting) {
        _isBroadcasting = broadcasting;
        notifyListeners();
      }
    });
  }

  win.WebviewController? _controller;
  MeetStatus _status = MeetStatus.idle;
  String? _meetingUrl;
  String? _errorMessage;
  bool _isBroadcasting = false;
  bool _autoAdmitEnabled = true;
  bool _needsGoogleLogin = false;
  StreamSubscription<String>? _urlSubscription;
  StreamSubscription<dynamic>? _webMessageSubscription;

  final List<MeetChatMessage> _messages = [];
  final List<String> _raisedHands = [];
  final List<MeetParticipant> _participants = [];
  int _pendingAdmitCount = 0;
  bool _isBridgeReady = false;
  bool _hasHocLucCam = false;
  bool _hasHocLucMic = false;

  MeetStatus get status => _status;
  String? get meetingUrl => _meetingUrl;
  String? get errorMessage => _errorMessage;
  bool get isBroadcasting => _isBroadcasting;
  bool get needsGoogleLogin => _needsGoogleLogin;
  bool get hasRoom => _meetingUrl != null && _status != MeetStatus.idle && _status != MeetStatus.error;
  win.WebviewController? get webviewController => _controller;

  List<MeetChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get raisedHands => List.unmodifiable(_raisedHands);
  List<MeetParticipant> get participants => List.unmodifiable(_participants);
  int get pendingAdmitCount => _pendingAdmitCount;
  bool get isBridgeReady => _isBridgeReady;
  bool get hasHocLucCam => _hasHocLucCam;
  bool get hasHocLucMic => _hasHocLucMic;
  bool get autoAdmitEnabled => _autoAdmitEnabled;

  set autoAdmitEnabled(bool val) {
    if (_autoAdmitEnabled != val) {
      _autoAdmitEnabled = val;
      notifyListeners();
      if (_autoAdmitEnabled && _pendingAdmitCount > 0) {
        unawaited(admitAllPending());
      }
    }
  }

  /// Gán link phòng Meet thật (từ người dùng dán hoặc từ Google API)
  void setMeetingUrl(String url) {
    var cleanUrl = url.trim();
    if (cleanUrl.isNotEmpty && !cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    _meetingUrl = cleanUrl.isEmpty ? null : cleanUrl;
    _status = _meetingUrl != null ? MeetStatus.ready : MeetStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Tạo lớp học (Khởi tạo phòng Meet chính thức từ API hoặc WebView2 native)
  Future<void> createClassroom({String? directUrl}) async {
    try {
      if (directUrl != null && directUrl.trim().isNotEmpty) {
        setMeetingUrl(directUrl);
        return;
      }

      _status = MeetStatus.creating;
      _errorMessage = null;
      notifyListeners();

      // 1. Gọi Backend Java để khởi tạo phòng Meet chính thức nếu có token
      try {
        final localService = LocalService();
        final reqData = <String, dynamic>{};
        if (directUrl != null) reqData['directUrl'] = directUrl;
        final token = GoogleMeetAuthService().accessToken;
        if (token != null) reqData['accessToken'] = token;

        final response = await localService.post('classroom/create', data: reqData);
        if (response['success'] == true && response['meetingUrl'] != null) {
          setMeetingUrl(response['meetingUrl'] as String);
          return;
        } else {
          debugPrint('[MeetAutomation] Backend returned response without meetingUrl: $response');
        }
      } catch (e) {
        debugPrint('[MeetAutomation] Backend service create classroom failed: $e');
      }

      // 2. Trên Web: Không gán link giả abc-defg-hij nữa
      if (kIsWeb) {
        _status = MeetStatus.ready;
        notifyListeners();
        return;
      }

      await generateAndJoinRealMeetRoom();
    } catch (e) {
      _status = MeetStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Tự động khởi tạo phòng Google Meet thật (meet.google.com/xxx-yyyy-zzz)
  /// và tự động tham gia vào phòng với tư cách Host.
  Future<String?> generateAndJoinRealMeetRoom({
    String? existingUrl,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (kIsWeb) {
      return null;
    }

    final previousUrl = _meetingUrl;
    _meetingUrl = null;
    _needsGoogleLogin = false;
    _status = MeetStatus.creating;
    _errorMessage = null;
    notifyListeners();

    try {
      await WebviewEnvironmentService.ensureInitialized();

      if (_controller != null) {
        try {
          _controller!.dispose();
        } catch (_) {}
        _controller = null;
      }

      final version = await win.WebviewController.getWebViewVersion();
      if (version == null) {
        throw StateError('Chưa cài đặt Microsoft Edge WebView2 Runtime trên máy tính.');
      }
      _controller = win.WebviewController();
      await _controller!.initialize();

      _webMessageSubscription?.cancel();
      _webMessageSubscription = _controller!.webMessage.listen((data) {
        _handleWebMessage(data);
      });

      final controller = _controller!;
      final completer = Completer<String?>();
      Timer? autoClickTimer;
      Timer? timeoutTimer;

      void onMeetingUrlDetected(String realUrl) {
        if (previousUrl != null && realUrl == previousUrl) {
          debugPrint('[MeetAutomation] Skipping previous room URL lingering in WebView: $realUrl');
          return;
        }
        _meetingUrl = realUrl;
        _status = MeetStatus.ready;
        notifyListeners();

        _scheduleAutoJoin(controller);

        if (!completer.isCompleted) {
          completer.complete(realUrl);
        }
      }

      _urlSubscription?.cancel();
      _urlSubscription = controller.url.listen((url) {
        debugPrint('[MeetAutomation] Navigation URL: $url');
        final match = RegExp(r'meet\.google\.com\/([a-z]{3}-[a-z]{4}-[a-z]{3})', caseSensitive: false).firstMatch(url);
        if (match != null) {
          final realUrl = 'https://meet.google.com/${match.group(1)!.toLowerCase()}';
          onMeetingUrlDetected(realUrl);
        }
      });

      final targetUrl = (existingUrl != null && existingUrl.trim().isNotEmpty)
          ? existingUrl.trim()
          : 'https://meet.google.com/new?hs=193';
      debugPrint('[MeetAutomation] Loading target URL: $targetUrl');
      await controller.loadUrl(targetUrl);

      // Liên tục tiêm script trích xuất URL và bypass modal cấp quyền media / tự click tham gia
      autoClickTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        if (_controller == null) {
          timer.cancel();
          return;
        }
        try {
          final res = await _controller!.executeScript(r'''
            (function() {
              var href = window.location.href || '';
              var m = href.match(/meet\.google\.com\/([a-z]{3}-[a-z]{4}-[a-z]{3})/i);
              var code = m ? m[1].toLowerCase() : '';

              // Kiểm tra xem đã vào phòng chưa (nút kết thúc cuộc gọi đỏ)
              var inCall = document.querySelector('button[aria-label*="rời khỏi" i], button[aria-label*="leave call" i]');
              if (inCall) {
                return 'IN_CALL:' + code;
              }

              var buttons = Array.from(document.querySelectorAll('button'));
              var permBtn = buttons.find(function(b) {
                var t = (b.innerText || b.textContent || '').trim().toLowerCase();
                return t.includes('sử dụng micrô') || 
                       t.includes('use microphone') || 
                       t.includes('cho phép') || 
                       t.includes('allow') || 
                       t.includes('tiếp tục mà không') ||
                       t.includes('continue without');
              }) || document.querySelector('button[data-id="EBS5Fd"]');
              if (permBtn && !permBtn.disabled) {
                permBtn.click();
              }

              var joinBtn = buttons.find(function(b) {
                var t = (b.innerText || b.textContent || '').trim().toLowerCase();
                var a = (b.getAttribute('aria-label') || '').toLowerCase();
                var js = b.getAttribute('jsname') || '';
                var isJoin = t.includes('tham gia ngay') || 
                             t.includes('join now') || 
                             t.includes('chuyển vào đây') || 
                             t.includes('switch here') ||
                             t.includes('yêu cầu tham gia') ||
                             t.includes('ask to join') ||
                             a.includes('tham gia ngay') ||
                             a.includes('join now') ||
                             js === 'Qx7uuf';
                return isJoin && !b.disabled && b.offsetParent !== null;
              });
              if (joinBtn) {
                joinBtn.click();
              }

              return code;
            })();
          ''');

          if (res != null && res.isNotEmpty && res != '""') {
            final cleaned = res.replaceAll('"', '').trim();
            if (cleaned.startsWith('IN_CALL:')) {
              final callCode = cleaned.replaceFirst('IN_CALL:', '').trim();
              if (callCode.isNotEmpty) {
                onMeetingUrlDetected('https://meet.google.com/$callCode');
              }
            } else if (RegExp(r'^[a-z]{3}-[a-z]{4}-[a-z]{3}$').hasMatch(cleaned)) {
              onMeetingUrlDetected('https://meet.google.com/$cleaned');
            }
          }
        } catch (_) {}
      });

      timeoutTimer = Timer(timeout, () {
        autoClickTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(_meetingUrl);
        }
      });

      final resultUrl = await completer.future;
      timeoutTimer.cancel();

      // Duy trì auto-click thêm 5 giây để Google hoàn tất animation vào phòng
      Future.delayed(const Duration(seconds: 5), () {
        autoClickTimer?.cancel();
      });

      return resultUrl;
    } catch (e) {
      _status = MeetStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Xử lý message nhận từ script tiêm trong WebView2 (hỗ trợ gọi trong test)
  @visibleForTesting
  void handleWebMessageForTesting(dynamic rawData) => _handleWebMessage(rawData);

  void _handleWebMessage(dynamic rawData) {
    try {
      final Map<String, dynamic> data = rawData is String
          ? jsonDecode(rawData) as Map<String, dynamic>
          : (rawData as Map).cast<String, dynamic>();

      final type = data['type'] as String?;
      final payload = data['payload'];

      if (type == 'CHAT_MESSAGE' && payload is Map) {
        final chat = MeetChatMessage.fromJson(payload.cast<String, dynamic>());
        if (!_messages.any((m) => m.id == chat.id)) {
          _messages.add(chat);
          notifyListeners();
        }
      } else if (type == 'PARTICIPANTS_UPDATE' && payload is List) {
        _participants.clear();
        for (final p in payload) {
          if (p is Map) {
            _participants.add(MeetParticipant.fromJson(p.cast<String, dynamic>()));
          }
        }
        notifyListeners();
      } else if (type == 'RAISE_HANDS_UPDATE' && payload is Map) {
        final event = MeetRaisedHandEvent.fromJson(payload.cast<String, dynamic>());
        _raisedHands
          ..clear()
          ..addAll(event.names);
        notifyListeners();
      } else if (type == 'ADMIT_REQUEST' && payload is Map) {
        final event = MeetAdmissionEvent.fromJson(payload.cast<String, dynamic>());
        _pendingAdmitCount = event.pendingCount;
        notifyListeners();
        if (_autoAdmitEnabled && _pendingAdmitCount > 0) {
          unawaited(admitAllPending());
        }
      } else if (type == 'MEET_MEDIA_DEVICE_SELECTED' && payload is Map) {
        _hasHocLucCam = payload['hasHocLucCam'] == true;
        _hasHocLucMic = payload['hasHocLucMic'] == true;
        notifyListeners();
      } else if (type == 'MEET_BRIDGE_READY') {
        _isBridgeReady = true;
        notifyListeners();
      } else if (type == 'MEET_JOINED') {
        _status = MeetStatus.ready;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MeetAutomation] Error parsing web message: $e');
    }
  }

  /// Bắt đầu phát sóng stream màn hình bảng vẽ lên Virtual Camera
  Future<void> startBroadcast() async {
    if (_isBroadcasting) return;
    await CameraBroadcastService().start();
  }

  /// Tạm dừng / Dừng phát sóng stream
  Future<void> stopBroadcast() async {
    await CameraBroadcastService().stop();
  }

  /// Chuyển đổi trạng thái phát sóng ON / OFF
  Future<void> toggleBroadcast() async {
    if (_isBroadcasting) {
      await stopBroadcast();
    } else {
      await startBroadcast();
    }
  }

  /// Đồng bộ trạng thái Tắt/Bật Mic & Camera từ App sang Google Meet
  Future<void> syncMuteState({bool? micMuted, bool? camMuted}) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      if (micMuted != null) {
        await ctrl.executeScript('window.MeetBridge && window.MeetBridge.setMicMute($micMuted);');
      }
      if (camMuted != null) {
        await ctrl.executeScript('window.MeetBridge && window.MeetBridge.setCamMute($camMuted);');
      }
    } catch (e) {
      debugPrint('[MeetAutomation] syncMuteState error: $e');
    }
  }

  /// Gửi tin nhắn chat từ Giáo viên vào phòng Meet
  Future<void> sendChatMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final nowStr = DateTime.now().toLocal().toString().substring(11, 16);
    final selfMessage = MeetChatMessage(
      id: 'self_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'Tôi (Giáo viên)',
      text: clean,
      time: nowStr,
      isSelf: true,
    );
    _messages.add(selfMessage);
    notifyListeners();

    if (_controller != null) {
      final escaped = clean.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n');
      try {
        await _controller!.executeScript('window.MeetBridge && window.MeetBridge.sendChat("$escaped");');
      } catch (e) {
        debugPrint('[MeetAutomation] Error executing sendChat script: $e');
      }
    }
  }

  /// Duyệt tất cả học sinh đang chờ vào phòng
  Future<void> admitAllPending() async {
    _pendingAdmitCount = 0;
    notifyListeners();
    if (_controller != null) {
      try {
        await _controller!.executeScript('window.MeetBridge && window.MeetBridge.admitAll();');
      } catch (e) {
        debugPrint('[MeetAutomation] Error executing admitAll script: $e');
      }
    }
  }

  /// Tắt tiếng micro của toàn bộ học sinh trong phòng
  Future<void> muteAllParticipants() async {
    for (int i = 0; i < _participants.length; i++) {
      _participants[i] = _participants[i].copyWith(isMuted: true, isSpeaking: false);
    }
    notifyListeners();
    if (_controller != null) {
      try {
        await _controller!.executeScript('window.MeetBridge && window.MeetBridge.muteAll();');
      } catch (e) {
        debugPrint('[MeetAutomation] Error executing muteAll script: $e');
      }
    }
  }

  /// Bật/Tắt tiếng micro riêng từng học sinh
  void toggleMuteParticipant(String id) {
    final idx = _participants.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final p = _participants[idx];
      final newMuted = !p.isMuted;
      _participants[idx] = p.copyWith(
        isMuted: newMuted,
        isSpeaking: newMuted ? false : p.isSpeaking,
      );
      notifyListeners();
    }
  }

  /// Hạ tay học sinh đang giơ tay
  void lowerHandParticipant(String id) {
    final idx = _participants.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final p = _participants[idx];
      _participants[idx] = p.copyWith(isHandRaised: false);
      _raisedHands.remove(p.name);
      notifyListeners();
    }
  }

  /// Mời học sinh ra khỏi phòng học (Kick out)
  Future<void> removeParticipant(String id, String name) async {
    _participants.removeWhere((p) => p.id == id);
    _raisedHands.remove(name);
    notifyListeners();
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      final safeName = name.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      await ctrl.executeScript('window.MeetBridge && window.MeetBridge.removeParticipant("$safeName");');
    } catch (e) {
      debugPrint('[MeetAutomation] Error executing removeParticipant: $e');
    }
  }

  /// Xóa sạch dữ liệu phiên học khi rời phòng
  void clearMeetingEvents() {
    _messages.clear();
    _raisedHands.clear();
    _participants.clear();
    _pendingAdmitCount = 0;
    _isBridgeReady = false;
    notifyListeners();
  }

  /// Tạm dừng phiên giảng dạy (rời Studio tạm thời, giữ link Meet trên hệ thống)
  Future<void> pauseSession() async {
    await stopBroadcast();
    _urlSubscription?.cancel();
    _urlSubscription = null;
    _webMessageSubscription?.cancel();
    _webMessageSubscription = null;
    if (_controller != null) {
      try {
        await _controller!.loadUrl('about:blank');
      } catch (e) {
        debugPrint('[MeetAutomation] Error pausing webview: $e');
      }
    }
    notifyListeners();
  }

  /// Đóng lớp học hoàn toàn
  Future<void> leaveClassroom() async {
    await stopBroadcast();
    clearMeetingEvents();
    _status = MeetStatus.idle;
    _meetingUrl = null;
    _urlSubscription?.cancel();
    _urlSubscription = null;
    _webMessageSubscription?.cancel();
    _webMessageSubscription = null;

    if (_controller != null) {
      try {
        await _controller!.loadUrl('about:blank');
      } catch (e) {
        debugPrint('[MeetAutomation] Error resetting webview: $e');
      }
      try {
        _controller!.dispose();
      } catch (e) {
        debugPrint('[MeetAutomation] Error disposing webview: $e');
      }
      _controller = null;
    }
    notifyListeners();
  }

  /// Tương thích ngược: Vừa tạo phòng vừa bắt đầu phát sóng
  Future<void> startAutoMeet() async {
    await createClassroom();
    await startBroadcast();
  }

  /// Tương thích ngược
  Future<void> stopAutoMeet() async {
    await leaveClassroom();
  }

  /// Tiêm script tự động bấm "Tham gia ngay" và Bridge Script giám sát DOM
  void _scheduleAutoJoin(win.WebviewController controller) {
    for (final delay in [1, 3, 5]) {
      Future.delayed(Duration(seconds: delay), () async {
        if (_controller == null) return;
        try {
          await controller.executeScript(MeetBridgeScript.script);
        } catch (err) {
          debugPrint('[MeetAutomation] Bridge inject error at ${delay}s: $err');
        }
      });
    }
  }

  /// Đảm bảo Host đã thực sự ở trong phòng cuộc gọi (IN_CALL)
  /// Thường được gọi khi chuyển từ Lobby sang Studio
  Future<void> ensureHostJoined() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      await ctrl.executeScript(r'''
        (function() {
          if (window.MeetBridge && typeof window.MeetBridge.attemptAutoJoin === 'function') {
            window.MeetBridge.attemptAutoJoin();
          }
        })();
      ''');
    } catch (e) {
      debugPrint('[MeetAutomation] ensureHostJoined error: $e');
    }
  }

  @override
  void dispose() {
    _urlSubscription?.cancel();
    _webMessageSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
