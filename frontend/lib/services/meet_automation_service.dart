import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'package:wgc_broadcaster/wgc_broadcaster.dart';
import 'google_meet_auth_service.dart';
import 'local_service.dart';

enum MeetStatus {
  idle,
  creating,
  ready,
  error,
}

class MeetAutomationService extends ChangeNotifier {
  static final MeetAutomationService _instance = MeetAutomationService._internal();
  factory MeetAutomationService() => _instance;
  MeetAutomationService._internal();

  win.WebviewController? _controller;
  MeetStatus _status = MeetStatus.idle;
  String? _meetingUrl;
  String? _errorMessage;
  bool _isBroadcasting = false;
  StreamSubscription<String>? _urlSubscription;

  MeetStatus get status => _status;
  String? get meetingUrl => _meetingUrl;
  String? get errorMessage => _errorMessage;
  bool get isBroadcasting => _isBroadcasting;
  bool get hasRoom => _meetingUrl != null && _status != MeetStatus.idle && _status != MeetStatus.error;
  win.WebviewController? get webviewController => _controller;

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

      // 1. Gọi Backend Java để khởi tạo phòng Meet chính thức
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

      // Khởi tạo WebView Windows nếu chưa có (Native Windows Desktop)
      if (_controller == null) {
        final version = await win.WebviewController.getWebViewVersion();
        if (version == null) {
          throw StateError('Chưa cài đặt Microsoft Edge WebView2 Runtime trên máy tính.');
        }
        _controller = win.WebviewController();
        await _controller!.initialize();
      }

      final controller = _controller!;

      // Lắng nghe URL chuyển hướng từ meet.google.com/new
      _urlSubscription?.cancel();
      _urlSubscription = controller.url.listen((url) {
        debugPrint('[MeetAutomation] URL changed: $url');
        final match = RegExp(r'meet\.google\.com\/([a-z]{3}-[a-z]{4}-[a-z]{3})').firstMatch(url);
        if (match != null) {
          _meetingUrl = 'https://meet.google.com/${match.group(1)}';
          _status = MeetStatus.ready;
          notifyListeners();
          _scheduleAutoJoin(controller);
        }
      });

      // Mở trang tạo phòng họp mới của Google Meet
      await controller.loadUrl('https://meet.google.com/new');
    } catch (e) {
      _status = MeetStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Bắt đầu phát sóng stream màn hình bảng vẽ lên Virtual Camera
  Future<void> startBroadcast() async {
    if (_isBroadcasting) return;
    if (!kIsWeb) {
      await WgcBroadcaster.startBroadcast();
    }
    _isBroadcasting = true;
    notifyListeners();
  }

  /// Tạm dừng / Dừng phát sóng stream
  Future<void> stopBroadcast() async {
    if (!_isBroadcasting) return;
    if (!kIsWeb) {
      await WgcBroadcaster.stopBroadcast();
    }
    _isBroadcasting = false;
    notifyListeners();
  }

  /// Chuyển đổi trạng thái phát sóng ON / OFF
  Future<void> toggleBroadcast() async {
    if (_isBroadcasting) {
      await stopBroadcast();
    } else {
      await startBroadcast();
    }
  }

  /// Đóng lớp học hoàn toàn
  Future<void> leaveClassroom() async {
    await stopBroadcast();
    _status = MeetStatus.idle;
    _meetingUrl = null;
    _urlSubscription?.cancel();
    _urlSubscription = null;

    if (_controller != null) {
      try {
        await _controller!.loadUrl('about:blank');
      } catch (e) {
        debugPrint('[MeetAutomation] Error resetting webview: $e');
      }
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

  /// Inject script tự động bấm "Tham gia ngay" (Join now) và tắt pop-up
  void _scheduleAutoJoin(win.WebviewController controller) {
    const jsScript = '''
      (function() {
        console.log('[MeetBot] Auto-join script activated');
        var attempts = 0;
        var interval = setInterval(function() {
          attempts++;
          if (attempts > 30) {
            clearInterval(interval);
            return;
          }

          var buttons = Array.from(document.querySelectorAll('button'));
          var joinBtn = buttons.find(function(b) {
            var text = (b.innerText || b.textContent || '').trim().toLowerCase();
            return text.includes('tham gia ngay') || 
                   text.includes('join now') || 
                   text.includes('chuyển vào đây') ||
                   text.includes('switch here');
          });

          if (joinBtn) {
            console.log('[MeetBot] Clicking join button...');
            joinBtn.click();
            clearInterval(interval);
          }
        }, 1000);
      })();
    ''';

    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await controller.executeScript(jsScript);
      } catch (err) {
        debugPrint('[MeetAutomation] Script execute error: $err');
      }
    });
  }

  @override
  void dispose() {
    _urlSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
