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
import 'webview_environment_service.dart';

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
  bool _callJoined = false;
  String? _meetAccountEmail;
  bool _accountConfirmedByTeacher = false;
  String? get meetAccountEmail => _meetAccountEmail;
  bool get accountMismatch =>
      linkedTeacherEmail != null &&
      _meetAccountEmail != null &&
      _meetAccountEmail != linkedTeacherEmail!.trim().toLowerCase();
  bool get needsAccountConfirmation =>
      linkedTeacherEmail != null &&
      _meetAccountEmail == null &&
      !_accountConfirmedByTeacher;

  // This is a teacher acknowledgement, not a verified Google identity or host role.
  void confirmMeetAccount() {
    if (linkedTeacherEmail == null || accountMismatch) return;
    _accountConfirmedByTeacher = true;
    _updateJoinedState();
    notifyListeners();
  }

  void _updateJoinedState() {
    _hostJoined = _callJoined && !accountMismatch && !needsAccountConfirmation;
  }

  void _resetMeetAccount() {
    _participantsFresh = false;
    _participants.clear();
    _raisedHands.clear();
    _callJoined = false;
    _hostJoined = false;
    _meetAccountEmail = null;
    _accountConfirmedByTeacher = false;
  }

  bool showEmbeddedMeet = false;
  Future<void>? pendingSessionRegistration;
  String? _linkedTeacherEmail;
  bool _autoAdmitEnabled = false;
  bool? _admissionPreferenceBeforeLinkedClass;
  String? get linkedTeacherEmail => _linkedTeacherEmail;
  set linkedTeacherEmail(String? email) {
    if (_linkedTeacherEmail != email) _resetMeetAccount();
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
  bool _participantsFresh = false;
  bool get participantsFresh => _participantsFresh;
  int _pendingAdmitCount = 0;
  bool _isBridgeReady = false;
  bool _hasHocLucCam = false;
  bool _hasHocLucMic = false;

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
      _resetMeetAccount();
      _messages.clear();
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
          debugPrint(
            '[MeetAutomation] Backend returned response without meetingUrl: $response',
          );
        }
      } catch (e) {
        debugPrint(
          '[MeetAutomation] Backend service create classroom failed: $e',
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
    _resetMeetAccount();
    if (autoJoin) linkedTeacherEmail = null;
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
          _resetMeetAccount();
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
          debugPrint(
            '[MeetAutomation] Skipping previous room URL lingering in WebView: $realUrl',
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
        debugPrint('[MeetAutomation] Navigation URL: $url');
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
      debugPrint('[MeetAutomation] Loading target URL: $targetUrl');
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
      } else if (type == 'PARTICIPANTS_STATE' && payload is Map) {
        _participantsFresh = payload['available'] == true;
        notifyListeners();
      } else if (type == 'PARTICIPANTS_UPDATE' && payload is List) {
        _participantsFresh = true;
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
        _hasHocLucMic = payload['hasHocLucMic'] == true;
        notifyListeners();
      } else if (type == 'MEET_BRIDGE_READY') {
        _isBridgeReady = true;
        notifyListeners();
      } else if (type == 'MEET_ACCOUNT' || type == 'MEET_JOINED') {
        if (payload is! Map || payload['url'] is! String) return;
        final uri = Uri.tryParse(payload['url'] as String);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'meet.google.com' ||
            'https://meet.google.com${uri.path}' != _meetingUrl) {
          return;
        }
        if (type == 'MEET_ACCOUNT') {
          final email = payload['email'];
          final normalized = email is String && email.contains('@')
              ? email.trim().toLowerCase()
              : null;
          final inCall = payload.containsKey('inCall')
              ? payload['inCall'] == true
              : _callJoined;
          if (_meetAccountEmail == normalized && _callJoined == inCall) return;
          if (_meetAccountEmail != normalized) {
            _meetAccountEmail = normalized;
            _accountConfirmedByTeacher = false;
          }
          _callJoined = inCall;
        } else {
          if (_callJoined) return;
          _callJoined = true;
        }
        _updateJoinedState();
        _status = MeetStatus.ready;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MeetAutomation] Error parsing web message: $e');
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

  Future<bool> admitRequest(String requestId) {
    final existing = _admissionAttempts[requestId];
    if (existing != null) return existing.completer.future;
    if (!_admissionRequests.containsKey(requestId) ||
        _admissionDocumentId == null) {
      return Future.value(false);
    }
    final selected = _admissionRequests[requestId]!;
    if (selected.detail.isEmpty &&
        _admissionRequests.values
                .where(
                  (r) =>
                      r.name.trim().toLowerCase() ==
                      selected.name.trim().toLowerCase(),
                )
                .length >
            1) {
      _admissionErrors[requestId] =
          'Có nhiều người trùng tên và chưa đủ thông tin phân biệt. Hãy duyệt trong Meet.';
      notifyListeners();
      return Future.value(false);
    }
    final attempt = _AdmissionAttempt('attempt-${++_admissionAttemptCounter}');
    _admissionAttempts[requestId] = attempt;
    _admissionErrors.remove(requestId);
    attempt.timer = Timer(
      _admissionTimeout,
      () => _finishAdmission(requestId, 'UNCONFIRMED'),
    );
    notifyListeners();
    _sendAdmissionCommand(requestId, attempt);
    return attempt.completer.future;
  }

  Future<void> _sendAdmissionCommand(
    String requestId,
    _AdmissionAttempt attempt,
  ) async {
    try {
      final command = jsonEncode({
        'requestId': requestId,
        'attemptId': attempt.id,
        'documentId': _admissionDocumentId,
      });
      final raw = await _executeAdmissionScript(
        'window.MeetAdmissionBridge ? window.MeetAdmissionBridge.admit($command) : JSON.stringify({status:"NOT_READY"});',
      );
      var decoded = jsonDecode(raw);
      if (decoded is String) decoded = jsonDecode(decoded);
      if (_admissionAttempts[requestId] != attempt) return;
      final status = decoded is Map ? decoded['status']?.toString() : null;
      if (status != 'PENDING') {
        _finishAdmission(
          requestId,
          status == 'CONFIRMED' ? 'UNCONFIRMED' : status ?? 'UNCONFIRMED',
        );
      }
    } catch (_) {
      if (_admissionAttempts[requestId] == attempt) {
        _finishAdmission(requestId, 'NOT_READY');
      }
    }
  }

  void _finishAdmission(String id, String status) {
    final attempt = _admissionAttempts.remove(id);
    if (attempt == null) return;
    attempt.timer?.cancel();
    final confirmed = status == 'CONFIRMED';
    if (confirmed) {
      _admissionRequests.remove(id);
      _admissionErrors.remove(id);
    } else {
      _admissionErrors[id] = switch (status) {
        'NOT_FOUND' =>
          'Yêu cầu đã thay đổi hoặc không còn ở vị trí cũ. Hãy kiểm tra trong Meet.',
        'NOT_CLICKABLE' =>
          'Meet chưa cho phép duyệt yêu cầu này. Hãy kiểm tra quyền chủ phòng.',
        'STALE_DOCUMENT' => 'Phiên Meet đã thay đổi. Hãy kiểm tra lại yêu cầu.',
        'NOT_READY' =>
          'Chưa kết nối được nút duyệt trong Meet. Hãy mở panel Meet.',
        _ =>
          'Chưa xác nhận học sinh đã vào phòng. Hãy kiểm tra trong Meet trước khi thử lại.',
      };
    }
    _updateAdmissionCount();
    attempt.completer.complete(confirmed);
    notifyListeners();
  }

  void dismissAdmissionNotice(String id) {
    if (isAdmitting(id)) return;
    _admissionRequests.remove(id);
    _admissionErrors.remove(id);
    _updateAdmissionCount();
    notifyListeners();
  }

  void _updateAdmissionCount() =>
      _pendingAdmitCount = _admissionRequests.length + _unknownAdmissionCount;

  void _resetAdmissions() {
    _admissionGeneration++;
    _admissionBatch = null;
    for (final attempt in _admissionAttempts.values) {
      attempt.timer?.cancel();
      if (!attempt.completer.isCompleted) attempt.completer.complete(false);
    }
    _admissionAttempts.clear();
    _admissionRequests.clear();
    _admissionErrors.clear();
    _admissionDocumentId = null;
    _admissionSequence = -1;
    _unknownAdmissionCount = 0;
    _pendingAdmitCount = 0;
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
        await ctrl.executeScript(
          'window.MeetBridge && window.MeetBridge.setMicMute($micMuted);',
        );
      }
      if (camMuted != null) {
        await ctrl.executeScript(
          'window.MeetBridge && window.MeetBridge.setCamMute($camMuted);',
        );
      }
    } catch (e) {
      debugPrint('[MeetAutomation] syncMuteState error: $e');
    }
  }

  /// Request a send; only CHAT_MESSAGE from Meet adds a visible message.
  Future<bool> sendChatMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return false;
    if (_controller == null && _testExecuteScript == null) return false;
    try {
      final raw = await _executeAdmissionScript(
        'window.MeetBridge ? window.MeetBridge.sendChat(${jsonEncode(clean)}) : false;',
      );
      return jsonDecode(raw) == true;
    } catch (_) {
      return false;
    }
  }

  /// Duyệt tất cả học sinh đang chờ vào phòng
  Future<void> admitAllPending() {
    final running = _admissionBatch;
    if (running != null) return running;
    // Snapshot before notifying: newcomers always require a fresh teacher action.
    final ids = _admissionRequests.keys.toList();
    final generation = _admissionGeneration;
    final completion = Completer<void>();
    _admissionBatch = completion.future;
    notifyListeners();
    () async {
      try {
        for (final id in ids) {
          if (_admissionGeneration != generation) break;
          await admitRequest(id);
        }
      } finally {
        if (_admissionGeneration == generation) {
          _admissionBatch = null;
          notifyListeners();
        }
        completion.complete();
      }
    }();
    return completion.future;
  }

  /// Xóa sạch dữ liệu phiên học khi rời phòng
  void clearMeetingEvents() {
    _resetAdmissions();
    _resetMeetAccount();
    _messages.clear();
    _raisedHands.clear();
    _participants.clear();
    _participantsFresh = false;
    _pendingAdmitCount = 0;
    _isBridgeReady = false;
    notifyListeners();
  }

  /// Tạm dừng phiên giảng dạy (rời Studio tạm thời, giữ link Meet trên hệ thống)
  Future<void> pauseSession() async {
    _bridgeTimer?.cancel();
    await stopBroadcast();
    // Keep the Meet document and listener alive while teaching elsewhere in
    // the app. Only ending the classroom disconnects the admission queue.
    notifyListeners();
  }

  /// Đóng lớp học hoàn toàn
  Future<void> leaveClassroom() async {
    _bridgeTimer?.cancel();
    await stopBroadcast();
    linkedTeacherEmail = null;
    _manualJoin = false;
    showEmbeddedMeet = false;
    _controllerMeetingUrl = null;
    clearMeetingEvents();
    _status = MeetStatus.idle;
    _meetingUrl = null;
    _loadingSubscription?.cancel();
    _loadingSubscription = null;
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
      _controllerMeetingUrl = null;
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
    _bridgeTimer?.cancel();
    var injecting = false;
    _bridgeTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!identical(_controller, controller)) {
        timer.cancel();
        return;
      }
      if (injecting) return;
      injecting = true;
      try {
        await controller.executeScript(
          'window.__hoclucManualJoin = $_manualJoin;',
        );
        await controller.executeScript(MeetBridgeScript.script);
        await controller.executeScript(MeetAdmissionBridgeScript.script);
      } catch (err) {
        debugPrint('[MeetAutomation] Bridge inject error: $err');
      } finally {
        injecting = false;
      }
    });
  }

  /// Đảm bảo Host đã thực sự ở trong phòng cuộc gọi (IN_CALL)
  /// Thường được gọi khi chuyển từ Lobby sang Studio
  Future<void> ensureHostJoined() =>
      _hostJoining ??= _connectHost().whenComplete(() => _hostJoining = null);

  Future<void> _connectHost() async {
    if (_manualJoin) return;
    final url = _meetingUrl;
    if (!isOfficialMeetingUrl(url)) return;
    if (_controller == null || _controllerMeetingUrl != url) {
      await generateAndJoinRealMeetRoom(existingUrl: url);
    }
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      _scheduleAutoJoin(ctrl);
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
    _resetAdmissions();
    _loadingSubscription?.cancel();
    _bridgeTimer?.cancel();
    _urlSubscription?.cancel();
    _webMessageSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}

class _AdmissionAttempt {
  _AdmissionAttempt(this.id);
  final String id;
  final Completer<bool> completer = Completer<bool>();
  Timer? timer;
}
