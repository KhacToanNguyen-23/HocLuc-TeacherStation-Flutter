import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'camera_broadcast_service.dart';
import '../models/meet_events.dart';
import 'google_meet_auth_service.dart';
import 'local_service.dart';
import 'meet_bridge_script.dart';

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
  @visibleForTesting
  MeetAutomationService.forTesting({LocalService Function()? localServiceFactory,
    Future<String> Function(String)? executeScript,
    Duration admissionTimeout = const Duration(seconds: 10)}) {
    if (localServiceFactory != null) _localServiceFactory = localServiceFactory;
    _testExecuteScript = executeScript;
    _admissionTimeout = admissionTimeout;
  }

  LocalService Function() _localServiceFactory = () => LocalService();
  MeetStatus _status = MeetStatus.idle;
  String? _meetingUrl;
  String? _errorMessage;
  String? _accessType;
  String? _classroomId;
  Future<void>? _panelOpening;
  String? _panelRoomUrl;
  bool _creatingCookieRoom = false;
  String? _previousCookieRoom;
  int _cookieCreationGeneration = 0;
  bool _isBroadcasting = false;
  StreamSubscription<String>? _urlSubscription;
  StreamSubscription<dynamic>? _webMessageSubscription;
  StreamSubscription<win.LoadingState>? _loadingSubscription;

  final List<MeetChatMessage> _messages = [];
  final List<String> _raisedHands = [];
  final List<MeetParticipant> _participants = [];
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

  MeetStatus get status => _status;
  String? get meetingUrl => _meetingUrl;
  String? get errorMessage => _errorMessage;
  String? get accessType => _accessType;
  String? get classroomId => _classroomId;
  bool get isCreatingCookieRoom => _creatingCookieRoom;
  bool get isBroadcasting => _isBroadcasting;
  bool get hasRoom =>
      _meetingUrl != null &&
      _status != MeetStatus.idle &&
      _status != MeetStatus.error;
  win.WebviewController? get webviewController => _controller;

  List<MeetChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get raisedHands => List.unmodifiable(_raisedHands);
  List<MeetParticipant> get participants => List.unmodifiable(_participants);
  int get pendingAdmitCount => _pendingAdmitCount;
  List<MeetAdmissionRequest> get admissionRequests => List.unmodifiable(_admissionRequests.values);
  int get unknownAdmissionCount => _unknownAdmissionCount;
  bool isAdmitting(String id) => _admissionAttempts.containsKey(id);
  String? admissionError(String id) => _admissionErrors[id];
  bool get isBridgeReady => _isBridgeReady;
  bool get hasHocLucCam => _hasHocLucCam;
  bool get hasHocLucMic => _hasHocLucMic;

  /// Gán link phòng Meet thật (từ người dùng dán hoặc từ Google API)
  void setMeetingUrl(String url) {
    var cleanUrl = url.trim();
    if (cleanUrl.isNotEmpty &&
        !cleanUrl.startsWith('http://') &&
        !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    if (_meetingUrl != cleanUrl) {
      _accessType = null;
      _classroomId = null;
      clearMeetingEvents();
    }
    _meetingUrl = cleanUrl.isEmpty ? null : cleanUrl;
    _status = _meetingUrl != null ? MeetStatus.ready : MeetStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Create an OPEN space through OAuth + Meet REST; pasted links retain their
  /// existing Google access settings and are never labelled OPEN here.
  Future<void> createClassroom({String? directUrl, String? title}) async {
    if (directUrl != null && directUrl.trim().isNotEmpty) {
      setMeetingUrl(directUrl);
      return;
    }
    final auth = GoogleMeetAuthService();
    _status = MeetStatus.creating;
    _meetingUrl = null;
    _accessType = null;
    _classroomId = null;
    _errorMessage = null;
    notifyListeners();
    final local = _localServiceFactory();
    try {
      if (!auth.isGoogleAuthenticated) {
        throw StateError(
          'Hãy kết nối Google và cấp quyền tạo phòng Meet trước.',
        );
      }
      final response = await local.post(
        'classroom/create',
        data: {
          'googleSessionId': auth.googleSessionId,
          'title': title ?? 'Phòng học trực tuyến',
          'teacherId': auth.teacherEmail,
        },
        timeout: const Duration(seconds: 50),
      );
      if (response['success'] != true) {
        if (response['requiresGoogleReconnect'] == true) {
          auth.disconnectGoogle();
        }
        throw StateError(
          response['error']?.toString() ?? 'Không tạo được phòng Google Meet.',
        );
      }
      final url = response['meetingUrl'] as String?;
      if (response['accessType'] != 'OPEN' || !isOfficialMeetingUrl(url)) {
        throw StateError(
          'Google chưa xác nhận phòng OPEN với đường dẫn hợp lệ.',
        );
      }
      setMeetingUrl(url!);
      _accessType = response['accessType'] as String;
      _classroomId = response['id'] as String?;
      notifyListeners();
    } catch (e) {
      _status = MeetStatus.error;
      _errorMessage = e.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
    } finally {
      local.client.close();
    }
  }

  /// Compatibility entry point: room creation no longer navigates to /new.
  Future<String?> generateAndJoinRealMeetRoom({
    Duration timeout = const Duration(seconds: 50),
  }) async {
    await createClassroom();
    return _status == MeetStatus.ready ? _meetingUrl : null;
  }

  static bool isOfficialMeetingUrl(String? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'meet.google.com' &&
        RegExp(r'^/[a-z]{3}-[a-z]{4}-[a-z]{3}$').hasMatch(uri.path);
  }

  Future<void> openMeetingPanel() {
    if (_panelOpening != null) return _panelOpening!;
    return _panelOpening = _loadMeetingPanel().whenComplete(
      () => _panelOpening = null,
    );
  }

  /// Uses the API's exact meetingUri. Browser cookies are separate from OAuth:
  /// the teacher may need to sign in to this Meet panel as the room owner.
  Future<void> _loadMeetingPanel() async {
    final url = _meetingUrl;
    if (!isOfficialMeetingUrl(url)) {
      throw StateError('Chưa có link Google Meet hợp lệ.');
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      throw StateError(
        'Panel Google Meet trong app hiện hỗ trợ Windows. Bạn có thể mở cùng link trong trình duyệt.',
      );
    }
    if (_controller != null && _panelRoomUrl == url) return;
    await _ensureMeetController();
    if (_meetingUrl != url) {
      throw StateError('Phòng Meet đã thay đổi. Hãy mở lại panel.');
    }
    final teacherEmail = _accessType == 'OPEN' ? GoogleMeetAuthService().googleEmail : null;
    final uri = Uri.parse(url!);
    final target = teacherEmail == null ? uri : uri.replace(queryParameters: {'authuser': teacherEmail});
    await _controller!.loadUrl(target.toString());
    _panelRoomUrl = url;
  }

  /// Cookie-based creation is independent of the optional OAuth OPEN API flow.
  /// The panel remains visible for Google sign-in and the teacher's Join action.
  Future<void> beginCookieRoomCreation() async {
    if (_creatingCookieRoom) return;
    final generation = ++_cookieCreationGeneration;
    _previousCookieRoom = _meetingUrl;
    _creatingCookieRoom = true;
    _panelRoomUrl = null;
    _meetingUrl = null;
    _classroomId = null;
    _accessType = null;
    _status = MeetStatus.creating;
    _errorMessage = null;
    clearMeetingEvents();
    notifyListeners();
    try {
      await _ensureMeetController();
      if (!_creatingCookieRoom || _cookieCreationGeneration != generation) return;
      await _controller!.loadUrl('https://meet.google.com/new');
    }
    catch (_) { cancelCookieRoomCreation(); rethrow; }
  }

  void cancelCookieRoomCreation() {
    if (!_creatingCookieRoom) return;
    _creatingCookieRoom = false;
    _cookieCreationGeneration++;
    setMeetingUrl(_previousCookieRoom ?? '');
    _previousCookieRoom = null;
    _panelRoomUrl = null;
  }

  Future<void> _ensureMeetController() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      throw StateError('Tạo phòng trong panel hiện hỗ trợ Windows. Hãy mở Meet trong trình duyệt và dán link vào app.');
    }
    if (_controller == null) {
      if (await win.WebviewController.getWebViewVersion() == null) {
        throw StateError(
          'Cần Microsoft Edge WebView2 Runtime để mở panel Google Meet.',
        );
      }
      final controller = win.WebviewController();
      try {
        await controller.initialize();
      } catch (_) {
        controller.dispose();
        rethrow;
      }
      _controller = controller;
      _urlSubscription = controller.url.listen((url) {
        if (!_creatingCookieRoom || !isOfficialMeetingUrl(url)) return;
        final uri = Uri.parse(url);
        final meetingUrl = 'https://meet.google.com${uri.path}';
        if (meetingUrl == _previousCookieRoom) return;
        _creatingCookieRoom = false;
        _previousCookieRoom = null;
        setMeetingUrl(meetingUrl);
        _panelRoomUrl = meetingUrl;
      });
      _webMessageSubscription = controller.webMessage.listen(_handleWebMessage);
      _loadingSubscription = controller.loadingState.listen((state) {
        if (state == win.LoadingState.loading) {
          _resetAdmissions();
          _isBridgeReady = false;
          notifyListeners();
        }
        if (state == win.LoadingState.navigationCompleted &&
            _controller == controller) {
          _scheduleAutoJoin(controller);
        }
      });
      notifyListeners();
    }
  }

  /// Xử lý message nhận từ script tiêm trong WebView2
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
        if (!_isCurrentMeetMessage(data) || data['documentId'] != _admissionDocumentId) return;
        final sequence = (data['sequence'] as num?)?.toInt() ?? -1;
        if (sequence <= _admissionSequence) return;
        _admissionSequence = sequence;
        final incoming = <String, MeetAdmissionRequest>{};
        final rawRequests = payload['requests'];
        if (rawRequests is List) {
          for (final raw in rawRequests) {
            if (raw is! Map) continue;
            final request = MeetAdmissionRequest.fromJson(raw.cast<String, dynamic>());
            if (request.id.isNotEmpty && request.name.isNotEmpty) incoming[request.id] = request;
          }
        }
        // A disappearing knock is not proof that our click admitted somebody.
        for (final entry in _admissionRequests.entries) {
          if (_admissionAttempts.containsKey(entry.key) || _admissionErrors.containsKey(entry.key)) {
            incoming.putIfAbsent(entry.key, () => entry.value);
          }
        }
        _admissionRequests..clear()..addAll(incoming);
        _unknownAdmissionCount = ((payload['unknownCount'] as num?)?.toInt() ?? 0).clamp(0, 1000).toInt();
        _updateAdmissionCount();
        notifyListeners();
        return;
      }
      if (type == 'ADMISSION_RESULT' && payload is Map) {
        if (!_isCurrentMeetMessage(data) || data['documentId'] != _admissionDocumentId) return;
        final requestId = payload['requestId'] as String?;
        final attempt = _admissionAttempts[requestId];
        if (attempt == null || attempt.id != payload['attemptId']) return;
        _finishAdmission(requestId!, payload['status']?.toString() ?? 'UNCONFIRMED');
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
        if (_admissionDocumentId != null) return;
        final event = MeetAdmissionEvent.fromJson(payload.cast<String, dynamic>());
        _pendingAdmitCount = event.pendingCount;
        _unknownAdmissionCount = event.pendingCount;
        notifyListeners();
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

  @visibleForTesting
  void receiveBridgeMessage(Map<String, dynamic> data) => _handleWebMessage(data);

  bool _isCurrentMeetMessage(Map<String, dynamic> data) {
    final uri = Uri.tryParse(data['url']?.toString() ?? '');
    final room = Uri.tryParse(_meetingUrl ?? '');
    return uri != null && room != null && isOfficialMeetingUrl(_meetingUrl) && isOfficialMeetingUrl(uri.toString()) && uri.path == room.path;
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
    if (!_admissionRequests.containsKey(requestId) || _admissionDocumentId == null) {
      return Future.value(false);
    }
    final selected = _admissionRequests[requestId]!;
    if (selected.detail.isEmpty && _admissionRequests.values.where((r) => r.name.trim().toLowerCase() == selected.name.trim().toLowerCase()).length > 1) {
      _admissionErrors[requestId] = 'Có nhiều người trùng tên và chưa đủ thông tin phân biệt. Hãy duyệt trong Meet.';
      notifyListeners();
      return Future.value(false);
    }
    final attempt = _AdmissionAttempt('attempt-${++_admissionAttemptCounter}');
    _admissionAttempts[requestId] = attempt;
    _admissionErrors.remove(requestId);
    attempt.timer = Timer(_admissionTimeout, () => _finishAdmission(requestId, 'UNCONFIRMED'));
    notifyListeners();
    _sendAdmissionCommand(requestId, attempt);
    return attempt.completer.future;
  }

  Future<void> _sendAdmissionCommand(String requestId, _AdmissionAttempt attempt) async {
    try {
      final command = jsonEncode({'requestId': requestId, 'attemptId': attempt.id, 'documentId': _admissionDocumentId});
      final raw = await _executeAdmissionScript('window.MeetAdmissionBridge ? window.MeetAdmissionBridge.admit($command) : JSON.stringify({status:"NOT_READY"});');
      var decoded = jsonDecode(raw);
      if (decoded is String) decoded = jsonDecode(decoded);
      if (_admissionAttempts[requestId] != attempt) return;
      final status = decoded is Map ? decoded['status']?.toString() : null;
      if (status != 'PENDING') _finishAdmission(requestId, status == 'CONFIRMED' ? 'UNCONFIRMED' : status ?? 'UNCONFIRMED');
    } catch (_) {
      if (_admissionAttempts[requestId] == attempt) _finishAdmission(requestId, 'NOT_READY');
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
        'NOT_FOUND' => 'Yêu cầu đã thay đổi hoặc không còn ở vị trí cũ. Hãy kiểm tra trong Meet.',
        'NOT_CLICKABLE' => 'Meet chưa cho phép duyệt yêu cầu này. Hãy kiểm tra quyền chủ phòng.',
        'STALE_DOCUMENT' => 'Phiên Meet đã thay đổi. Hãy kiểm tra lại yêu cầu.',
        'NOT_READY' => 'Chưa kết nối được nút duyệt trong Meet. Hãy mở panel Meet.',
        _ => 'Chưa xác nhận học sinh đã vào phòng. Hãy kiểm tra trong Meet trước khi thử lại.',
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

  void _updateAdmissionCount() => _pendingAdmitCount = _admissionRequests.length + _unknownAdmissionCount;

  void _resetAdmissions() {
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
    // Explicit snapshot: never include new arrivals or unresolved identities.
    final ids = _admissionRequests.keys.toList();
    for (final id in ids) {
      await admitRequest(id);
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

  /// Xóa sạch dữ liệu phiên học khi rời phòng
  void clearMeetingEvents() {
    _resetAdmissions();
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
    clearMeetingEvents();
    _panelRoomUrl = null;
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
    _cookieCreationGeneration++;
    _creatingCookieRoom = false;
    _previousCookieRoom = null;
    await stopBroadcast();
    clearMeetingEvents();
    _status = MeetStatus.idle;
    _meetingUrl = null;
    _accessType = null;
    _classroomId = null;
    _panelRoomUrl = null;
    _urlSubscription?.cancel();
    _urlSubscription = null;
    _webMessageSubscription?.cancel();
    _webMessageSubscription = null;
    _loadingSubscription?.cancel();
    _loadingSubscription = null;

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
        if (_controller != controller) return;
        try {
          await controller.executeScript(
            'if (location.hostname === "meet.google.com") { window.__meetManualJoin = true; ${MeetBridgeScript.script} }',
          );
        } catch (err) {
          debugPrint('[MeetAutomation] Bridge inject error at ${delay}s: $err');
        }
      });
    }
  }

  @override
  void dispose() {
    _resetAdmissions();
    _urlSubscription?.cancel();
    _webMessageSubscription?.cancel();
    _loadingSubscription?.cancel();
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
