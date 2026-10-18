import 'package:teaching_companion/utils/frontend_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'camera_broadcast_service.dart';
import '../models/meet_events.dart';
import 'google_meet_auth_service.dart';
import 'local_service.dart';
import 'meet_bridge_script.dart';
import 'meet_admission_bridge_script.dart';
import 'meet_focus_style_script.dart';
import 'webview_environment_service.dart';

part 'meet_automation_admission.dart';

enum MeetStatus { idle, creating, ready, error }

class MeetAutomationService extends ChangeNotifier {
  static final MeetAutomationService _instance =
      MeetAutomationService._internal();
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
  String? _controllerMeetingUrl;
  Future<void>? _hostJoining;
  MeetStatus _status = MeetStatus.idle;
  String? _meetingUrl;
  String? _errorMessage;
  bool _isBroadcasting = false;
  bool _needsGoogleLogin = false;
  bool _manualJoin = false;
  bool _hostJoined = false;
  bool get isHostJoined => _hostJoined;
  bool showEmbeddedMeet = false;
  Future<void>? pendingSessionRegistration;
  String? _linkedTeacherEmail;
  bool _autoAdmitEnabled = false;
  bool? _admissionPreferenceBeforeLinkedClass;
  String? get linkedTeacherEmail => _linkedTeacherEmail;
  set linkedTeacherEmail(String? email) {
    if (email != null && _linkedTeacherEmail == null) {
      _admissionPreferenceBeforeLinkedClass = _autoAdmitEnabled;
      _autoAdmitEnabled = false;
    } else if (email == null && _linkedTeacherEmail != null) {
      _autoAdmitEnabled = _admissionPreferenceBeforeLinkedClass ?? false;
      _admissionPreferenceBeforeLinkedClass = null;
    }
    _linkedTeacherEmail = email;
    notifyListeners();
  }

  StreamSubscription<String>? _urlSubscription;
  Timer? _bridgeTimer;
  StreamSubscription<dynamic>? _webMessageSubscription;

  final List<MeetChatMessage> _messages = [];
  final List<String> _raisedHands = [];
  final List<MeetParticipant> _participants = [];
  int _pendingAdmitCount = 0;
  bool _isBridgeReady = false;
  bool _hasHocLucCam = false;

  final Map<String, MeetAdmissionRequest> _admissionRequests = {};
  final Map<String, _AdmissionAttempt> _admissionAttempts = {};
  final Map<String, String> _admissionErrors = {};
  String? _admissionDocumentId;
  int _admissionSequence = -1;
  int _admissionAttemptCounter = 0;
  int _unknownAdmissionCount = 0;
  Duration _admissionTimeout = const Duration(seconds: 10);
  Future<String> Function(String)? _testExecuteScript;

  Future<void>? _admissionBatch;
  int _admissionGeneration = 0;
  StreamSubscription<win.LoadingState>? _loadingSubscription;

  @visibleForTesting
  MeetAutomationService.forTesting({
    Future<String> Function(String)? executeScript,
    Duration admissionTimeout = const Duration(seconds: 10),
  }) {
    _testExecuteScript = executeScript;
    _admissionTimeout = admissionTimeout;
  }

  bool get isAdmittingAll => _admissionBatch != null;

  MeetStatus get status => _status;
  String? get meetingUrl => _meetingUrl;
  String? get errorMessage => _errorMessage;
  bool get isBroadcasting => _isBroadcasting;
  bool get needsGoogleLogin => _needsGoogleLogin;
  bool get hasRoom =>
      _meetingUrl != null &&
      _status != MeetStatus.idle &&
      _status != MeetStatus.error;
  win.WebviewController? get webviewController => _controller;

  List<MeetChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get raisedHands => List.unmodifiable(_raisedHands);
  List<MeetParticipant> get participants => List.unmodifiable(_participants);
  int get pendingAdmitCount => _pendingAdmitCount;
  List<MeetAdmissionRequest> get admissionRequests =>
      List.unmodifiable(_admissionRequests.values);
  int get unknownAdmissionCount => _unknownAdmissionCount;
  bool isAdmitting(String id) => _admissionAttempts.containsKey(id);
  String? admissionError(String id) => _admissionErrors[id];
  bool get isBridgeReady => _isBridgeReady;
  bool get hasHocLucCam => _hasHocLucCam;
  bool get autoAdmitEnabled => _autoAdmitEnabled;

  set autoAdmitEnabled(bool val) {
    if (linkedTeacherEmail != null && val) return;
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
    if (cleanUrl.isNotEmpty &&
        !cleanUrl.startsWith('http://') &&
        !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final nextUrl = cleanUrl.isEmpty ? null : cleanUrl;
    if (_meetingUrl != nextUrl) {
      _resetAdmissions();
      _hostJoined = false;
    }
    _meetingUrl = nextUrl;
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

        final response = await localService.post(
          'classroom/create',
          data: reqData,
        );
        if (response['success'] == true && response['meetingUrl'] != null) {
          setMeetingUrl(response['meetingUrl'] as String);
          return;
        } else {
          FrontendLogger.write(
            '[MeetAutomation] Backend response missing meeting URL',
          );
        }
      } catch (e) {
        FrontendLogger.write(
          '[MeetAutomation] Backend classroom request failed | cause=${e.runtimeType}',
        );
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
    bool autoJoin = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (kIsWeb) {
      return null;
    }

    final previousUrl = _meetingUrl;
    if (existingUrl != null &&
        _controllerMeetingUrl == existingUrl &&
        _controller != null &&
        _status != MeetStatus.error) {
      return existingUrl;
    }
    _resetAdmissions();
    _hostJoined = false;
    _manualJoin = !autoJoin;
    _meetingUrl = existingUrl;
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
      _controllerMeetingUrl = null;

      final version = await win.WebviewController.getWebViewVersion();
      if (version == null) {
        throw StateError(
          'Chưa cài đặt Microsoft Edge WebView2 Runtime trên máy tính.',
        );
      }
      _controller = win.WebviewController();
      await _controller!.initialize();

      _webMessageSubscription?.cancel();
      _webMessageSubscription = _controller!.webMessage.listen((data) {
        _handleWebMessage(data);
      });

      final controller = _controller!;
      notifyListeners();
      await _loadingSubscription?.cancel();
      _loadingSubscription = controller.loadingState.listen((state) {
        if (_controller != controller) return;
        if (state == win.LoadingState.loading) {
          _resetAdmissions();
          notifyListeners();
        } else if (state == win.LoadingState.navigationCompleted) {
          _scheduleAutoJoin(controller);
        }
      });
      final completer = Completer<String?>();
      Timer? autoClickTimer;
      Timer? timeoutTimer;

      void onMeetingUrlDetected(String realUrl) {
        if (linkedTeacherEmail != null &&
            existingUrl != null &&
            realUrl != existingUrl) {
          _errorMessage =
              'Meet đã chuyển sang phòng khác. Quay lại đúng phòng đã liên kết với lớp.';
          _hostJoined = false;
          _status = MeetStatus.error;
          notifyListeners();
          return;
        }
        if (existingUrl == null &&
            previousUrl != null &&
            realUrl == previousUrl) {
          FrontendLogger.write(
            '[MeetAutomation] Ignored previous meeting URL detected in WebView',
          );
          return;
        }
        if (_meetingUrl != realUrl) _resetAdmissions();
        _controllerMeetingUrl = realUrl;
        _meetingUrl = realUrl;
        _controllerMeetingUrl = realUrl;
        _status = MeetStatus.ready;
        notifyListeners();

        _scheduleAutoJoin(controller);

        if (!completer.isCompleted) {
          completer.complete(realUrl);
        }
      }

      _urlSubscription?.cancel();
      _urlSubscription = controller.url.listen((url) {
        FrontendLogger.write('[MeetAutomation] Navigation state changed');
        if (url.contains('accounts.google.com')) {
          _needsGoogleLogin = true;
          notifyListeners();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          return;
        }
        final match = RegExp(
          r'meet\.google\.com\/([a-z]{3}-[a-z]{4}-[a-z]{3})',
          caseSensitive: false,
        ).firstMatch(url);
        if (match != null) {
          final realUrl =
              'https://meet.google.com/${match.group(1)!.toLowerCase()}';
          onMeetingUrlDetected(realUrl);
        }
      });

      final targetUrl = (existingUrl != null && existingUrl.trim().isNotEmpty)
          ? existingUrl.trim()
          : 'https://meet.google.com/new?hs=193';
      FrontendLogger.write('[MeetAutomation] Loading meeting page');
      await controller.loadUrl(targetUrl);
      _controllerMeetingUrl ??= existingUrl;
      if (!autoJoin) {
        _meetingUrl = existingUrl;
        _status = MeetStatus.ready;
        notifyListeners();
        return existingUrl;
      }

      // Liên tục tiêm script trích xuất URL và bypass modal cấp quyền media / tự click tham gia
      autoClickTimer = Timer.periodic(const Duration(milliseconds: 500), (
        timer,
      ) async {
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
                return isJoin && !b.disabled;
              });
              if (joinBtn) {
                try { joinBtn.scrollIntoView({block: 'center'}); } catch(e){}
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
                if (!_hostJoined) {
                  _hostJoined = true;
                  _status = MeetStatus.ready;
                  notifyListeners();
                }
                onMeetingUrlDetected('https://meet.google.com/$callCode');
              }
            } else if (RegExp(
              r'^[a-z]{3}-[a-z]{4}-[a-z]{3}$',
            ).hasMatch(cleaned)) {
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
  void handleWebMessageForTesting(dynamic rawData) =>
      _handleWebMessage(rawData);

  void _handleWebMessage(dynamic rawData) {
    try {
      final Map<String, dynamic> data = rawData is String
          ? jsonDecode(rawData) as Map<String, dynamic>
          : (rawData as Map).cast<String, dynamic>();

      final type = data['type'] as String?;
      final payload = data['payload'];

      if (type == 'ADMISSION_BRIDGE_READY') {
        if (!_isCurrentMeetMessage(data)) return;
        final documentId = data['documentId'] as String?;
        if (documentId == null || documentId.isEmpty) return;
        if (_admissionDocumentId != documentId) _resetAdmissions();
        _admissionDocumentId = documentId;
        notifyListeners();
        return;
      }
      if (type == 'ADMISSION_QUEUE' && payload is Map) {
        if (!_isCurrentMeetMessage(data) ||
            data['documentId'] != _admissionDocumentId) {
          return;
        }
        final sequence = (data['sequence'] as num?)?.toInt() ?? -1;
        if (sequence <= _admissionSequence) return;
        _admissionSequence = sequence;
        final incoming = <String, MeetAdmissionRequest>{};
        final rawRequests = payload['requests'];
        if (rawRequests is List) {
          for (final raw in rawRequests) {
            if (raw is! Map) continue;
            final request = MeetAdmissionRequest.fromJson(
              raw.cast<String, dynamic>(),
            );
            if (request.id.isNotEmpty && request.name.isNotEmpty) {
              incoming[request.id] = request;
            }
          }
        }
        // A disappearing knock is not proof that our click admitted somebody.
        for (final entry in _admissionRequests.entries) {
          if (_admissionAttempts.containsKey(entry.key) ||
              _admissionErrors.containsKey(entry.key)) {
            incoming.putIfAbsent(entry.key, () => entry.value);
          }
        }
        _admissionRequests
          ..clear()
          ..addAll(incoming);
        _unknownAdmissionCount =
            ((payload['unknownCount'] as num?)?.toInt() ?? 0)
                .clamp(0, 1000)
                .toInt();
        _updateAdmissionCount();
        notifyListeners();
        return;
      }
      if (type == 'ADMISSION_RESULT' && payload is Map) {
        if (!_isCurrentMeetMessage(data) ||
            data['documentId'] != _admissionDocumentId) {
          return;
        }
        final requestId = payload['requestId'] as String?;
        final attempt = _admissionAttempts[requestId];
        if (attempt == null || attempt.id != payload['attemptId']) return;
        _finishAdmission(
          requestId!,
          payload['status']?.toString() ?? 'UNCONFIRMED',
        );
        return;
      }

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
            _participants.add(
              MeetParticipant.fromJson(p.cast<String, dynamic>()),
            );
          }
        }
        notifyListeners();
      } else if (type == 'RAISE_HANDS_UPDATE' && payload is Map) {
        final event = MeetRaisedHandEvent.fromJson(
          payload.cast<String, dynamic>(),
        );
        _raisedHands
          ..clear()
          ..addAll(event.names);
        notifyListeners();
      } else if (type == 'ADMIT_REQUEST' && payload is Map) {
        // The named bridge is the only authority for admission notifications.
        // Legacy counts can include unrelated permission buttons.
        return;
      } else if (type == 'MEET_MEDIA_DEVICE_SELECTED' && payload is Map) {
        _hasHocLucCam = payload['hasHocLucCam'] == true;
        notifyListeners();
      } else if (type == 'MEET_BRIDGE_READY') {
        _isBridgeReady = true;
        notifyListeners();
      } else if (type == 'MEET_JOINED') {
        if (payload is! Map || payload['url'] is! String) return;
        final uri = Uri.tryParse(payload['url'] as String);
        if (uri == null ||
            uri.host != 'meet.google.com' ||
            'https://meet.google.com${uri.path}' != _meetingUrl) {
          return;
        }
        if (_hostJoined) return;
        _hostJoined = true;
        _status = MeetStatus.ready;
        notifyListeners();
      }
    } catch (e) {
      FrontendLogger.write('[MeetAutomation] Error parsing web message: $e');
    }
  }

  @visibleForTesting
  void receiveBridgeMessage(Map<String, dynamic> data) =>
      _handleWebMessage(data);

  static bool isOfficialMeetingUrl(String? url) {
    final uri = Uri.tryParse(url ?? '');
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'meet.google.com' &&
        RegExp(r'^/[a-z]{3}-[a-z]{4}-[a-z]{3}$').hasMatch(uri.path);
  }

  bool _isCurrentMeetMessage(Map<String, dynamic> data) {
    final uri = Uri.tryParse(data['url']?.toString() ?? '');
    final room = Uri.tryParse(_meetingUrl ?? '');
    return uri != null &&
        room != null &&
        isOfficialMeetingUrl(_meetingUrl) &&
        isOfficialMeetingUrl(uri.toString()) &&
        uri.path == room.path;
  }

  Future<String> _executeAdmissionScript(String script) async {
    if (_testExecuteScript != null) return _testExecuteScript!(script);
    final controller = _controller;
    if (controller == null) throw StateError('Chưa mở Google Meet trong app.');
    final result = await controller.executeScript(script);
    return result is String ? result : jsonEncode(result);
  }

  @override
  void dispose() {
    _resetAdmissions();
    _loadingSubscription?.cancel();
    _bridgeTimer?.cancel();
    _urlSubscription?.cancel();
    _webMessageSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}

