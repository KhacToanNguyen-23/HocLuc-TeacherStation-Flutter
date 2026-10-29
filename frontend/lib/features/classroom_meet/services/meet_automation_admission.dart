// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'meet_automation_service.dart';

extension MeetAutomationAdmissionAndControlsExt on MeetAutomationService {
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
    stopTutorObservation();
    _invalidateTutor();
    _tutorObservationReady = false;
    _tutorDocumentId = null;
    _tutorDocumentUrl = null;
    _hostJoined = false;
    _resetAdmissionQueue();
  }

  // The admission adapter has its own document identity. Reinstalling that
  // adapter must not discard the retained Meet/tutor handshake or active lease.
  void _resetAdmissionQueue() {
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

  Future<void> showSharingPanel(bool visible) async {
    _sharingPanelVisible = visible;
    if (_controller == null && _testExecuteScript == null) return;
    try {
      await _executeAdmissionScript(
        'window.HocLucScreenShare && window.HocLucScreenShare.showPanel($visible);',
      );
    } catch (error) {
      FrontendLogger.write(
        '[MeetAutomation] Could not switch sharing panel: $error',
      );
    }
  }

  /// Stop only streams returned by Meet's real screen/window picker.
  Future<void> stopScreenSharing() async {
    if (_controller == null && _testExecuteScript == null) return;
    try {
      await _executeAdmissionScript(
        'window.HocLucScreenShare && window.HocLucScreenShare.stop();',
      );
    } catch (error) {
      // A closed/navigating renderer must not prevent the room from closing.
      FrontendLogger.write(
        '[MeetAutomation] Could not stop display tracks: $error',
      );
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
      FrontendLogger.write('[MeetAutomation] syncMuteState error: $e');
    }
  }

  void _invalidateTutor() {
    _tutorGeneration++;
    if (!_tutorCancelled.isCompleted) _tutorCancelled.complete();
    _tutorCancelled = Completer<void>();
  }

  /// Opens and prepares chat in the retained native Meet page; no Flutter panel
  /// is required. Polling is bounded and tied to one cancellable observation lease.
  Future<bool> beginTutorObservation() async {
    _tutorObservationError = null;
    final room = _meetingUrl;
    if (_disposed ||
        !MeetAutomationService.isOfficialMeetingUrl(room) ||
        (_controller == null && _testExecuteScript == null)) {
      _tutorObservationError =
          'Vào phòng Meet trong ứng dụng trước khi bật AI.';
      return false;
    }
    if (_tutorObservationId != null) stopTutorObservation();
    if (!_tutorPreparationCancelled.isCompleted) {
      _tutorPreparationCancelled.complete();
    }
    _tutorPreparationCancelled = Completer<void>();
    final id = 'observe-${++_tutorObservationSerial}';
    final epoch = ++_tutorPreparationEpoch;
    _tutorObservationId = id;
    _tutorObservationRequested = true;
    _tutorObservationReady = false;
    final ready = await _waitTutorObservation(id, epoch, room!);
    if (!ready && epoch == _tutorPreparationEpoch) {
      _tutorObservationError = _hostJoined
          ? 'AI chưa kết nối được với cuộc trò chuyện Meet. Vui lòng thử lại.'
          : 'Chưa đồng bộ được trạng thái cuộc gọi Meet. Vui lòng thử bật AI lại.';
      FrontendLogger.write(
        '[MeetAutomation] Tutor preparation timeout: joined=$_hostJoined, bridge=$_isBridgeReady, document=${_tutorDocumentId != null}',
      );
      stopTutorObservation();
    }
    return ready;
  }

  Future<bool> _waitTutorObservation(String id, int epoch, String room) async {
    final watch = Stopwatch()..start();
    final cancelled = _tutorPreparationCancelled.future;
    bool current() =>
        !_disposed &&
        _tutorObservationRequested &&
        epoch == _tutorPreparationEpoch &&
        id == _tutorObservationId &&
        room == _meetingUrl;
    while (current() && watch.elapsed < _tutorTimeout) {
      final doc = _tutorDocumentId;
      final url = _tutorDocumentUrl;
      if (_hostJoined &&
          doc != null &&
          MeetAutomationService.canonicalMeetingUrl(url) ==
              MeetAutomationService.canonicalMeetingUrl(room)) {
        try {
          final command = jsonEncode({
            'documentId': doc,
            'url': url,
            'observationId': id,
            'expiresAt': DateTime.now()
                .add(_tutorTimeout - watch.elapsed)
                .millisecondsSinceEpoch,
          });
          final raw = await Future.any([
            _executeAdmissionScript(
              'window.MeetBridge ? window.MeetBridge.beginTutorObservation($command) : "null";',
            ),
            cancelled.then<String>(
              (_) => throw StateError('Tutor observation cancelled'),
            ),
          ]).timeout(_tutorTimeout - watch.elapsed);
          var response = jsonDecode(raw);
          if (response is String) response = jsonDecode(response);
          if (!current() ||
              doc != _tutorDocumentId ||
              url != _tutorDocumentUrl) {
            return false;
          }
          if (response is Map &&
              response['status'] == 'READY' &&
              response['documentId'] == doc &&
              response['url'] == url &&
              response['observationId'] == id) {
            if (!_tutorObservationReady) {
              _tutorObservationReady = true;
              notifyListeners();
            }
            return current() && _tutorObservationReady;
          }
          if (response is Map && response['status'] == 'READY') return false;
        } catch (_) {
          /* A bridge being injected may become ready next poll. */
        }
      }
      final remaining = _tutorTimeout - watch.elapsed;
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        remaining < const Duration(milliseconds: 150)
            ? remaining
            : const Duration(milliseconds: 150),
      );
    }
    return false;
  }

  void stopTutorObservation() {
    final hadObservation = _tutorObservationId != null;
    _invalidateTutor();
    final command = jsonEncode({
      'documentId': _tutorDocumentId,
      'url': _tutorDocumentUrl,
      'observationId': _tutorObservationId,
    });
    _tutorPreparationEpoch++;
    if (!_tutorPreparationCancelled.isCompleted) {
      _tutorPreparationCancelled.complete();
    }
    _tutorObservationRequested = false;
    _tutorObservationReady = false;
    _tutorObservationId = null;
    if (hadObservation &&
        !_disposed &&
        (_controller != null || _testExecuteScript != null)) {
      unawaited(
        _executeAdmissionScript(
          'window.MeetBridge && window.MeetBridge.endTutorObservation($command);',
        ).catchError((Object _) => 'false'),
      );
    }
  }

  /// Controller context/state changes invalidate pending and queued requests.
  void cancelTutorSend() {
    final command = jsonEncode({
      'documentId': _tutorDocumentId,
      'requestId': _activeTutorRequestId,
    });
    _invalidateTutor();
    if (!_disposed && (_controller != null || _testExecuteScript != null)) {
      unawaited(
        _executeAdmissionScript(
          'window.MeetBridge && window.MeetBridge.cancelTutor($command);',
        ).catchError((Object _) => 'false'),
      );
    }
  }

  /// Returns true only after a new self-authored DOM echo in this document.
  Future<bool> sendTutorMessage(
    String text, {
    bool Function()? stillCurrent,
  }) async =>
      await sendTutorMessageDetailed(text, stillCurrent: stillCurrent) ==
      MeetTutorDelivery.confirmed;

  Future<MeetTutorDelivery> sendTutorMessageDetailed(
    String text, {
    bool Function()? stillCurrent,
  }) async {
    final generation = _tutorGeneration;
    final cancelled = _tutorCancelled.future;
    bool callerCurrent() {
      try {
        return stillCurrent?.call() ?? true;
      } catch (_) {
        return false;
      }
    }

    if (!callerCurrent() || text.trim().isEmpty) {
      return MeetTutorDelivery.notDispatched;
    }
    if (!_tutorObservationReady &&
        _tutorObservationRequested &&
        _tutorObservationId != null &&
        _meetingUrl != null) {
      await Future.any([
        _waitTutorObservation(
          _tutorObservationId!,
          _tutorPreparationEpoch,
          _meetingUrl!,
        ),
        cancelled.then((_) => false),
      ]);
    }
    final documentId = _tutorDocumentId;
    final url = _tutorDocumentUrl;
    final observationId = _tutorObservationId;
    bool current() =>
        callerCurrent() &&
        !_disposed &&
        _hostJoined &&
        _tutorObservationRequested &&
        _tutorObservationReady &&
        observationId != null &&
        observationId == _tutorObservationId &&
        generation == _tutorGeneration &&
        documentId != null &&
        documentId == _tutorDocumentId &&
        url == _tutorDocumentUrl &&
        MeetAutomationService.isOfficialMeetingUrl(_meetingUrl);
    if (text.trim().isEmpty || !current()) {
      return Future.value(MeetTutorDelivery.notDispatched);
    }
    final result = Completer<MeetTutorDelivery>();
    var dispatched = false;
    _tutorQueue = _tutorQueue.then((_) async {
      if (!current()) {
        result.complete(MeetTutorDelivery.notDispatched);
        return;
      }
      final requestId = 'tutor-${++_tutorCounter}';
      _activeTutorRequestId = requestId;
      final command = jsonEncode({
        'requestId': requestId,
        'observationId': observationId,
        'documentId': documentId,
        'url': url,
        'text': text.trim(),
        'timeoutMs': _tutorTimeout.inMilliseconds,
        'expiresAt': DateTime.now().add(_tutorTimeout).millisecondsSinceEpoch,
      });
      final watch = Stopwatch()..start();
      try {
        var method = 'sendTutor';
        while (current() && watch.elapsed < _tutorTimeout) {
          if (method == 'sendTutor') dispatched = true;
          final raw = await _executeAdmissionScript(
            'window.MeetBridge ? window.MeetBridge.$method($command) : "null";',
          ).timeout(_tutorTimeout - watch.elapsed);
          var response = jsonDecode(raw);
          if (response is String) response = jsonDecode(response);
          if (method == 'sendTutor' &&
              response is Map &&
              const [
                'NOT_READY',
                'INPUT_BUSY',
                'BUSY',
              ].contains(response['status'])) {
            result.complete(MeetTutorDelivery.notDispatched);
            return;
          }
          if (!current() ||
              response is! Map ||
              response['requestId'] != requestId ||
              response['documentId'] != documentId ||
              response['url'] != url) {
            break;
          }
          if (watch.elapsed >= _tutorTimeout) break;
          if (response['status'] == 'CONFIRMED') {
            result.complete(MeetTutorDelivery.confirmed);
            return;
          }
          if (response['status'] != 'PENDING') break;
          method = 'tutorStatus';
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (!current()) break;
        }
      } catch (_) {
        // Transport failure, navigation and timeout never imply delivery.
      }
      result.complete(
        dispatched
            ? MeetTutorDelivery.unconfirmed
            : MeetTutorDelivery.notDispatched,
      );
    });
    return Future.any([
      result.future,
      cancelled.then(
        (_) => dispatched
            ? MeetTutorDelivery.unconfirmed
            : MeetTutorDelivery.notDispatched,
      ),
    ]);
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
      final escaped = clean
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll('\n', r'\n');
      try {
        await _controller!.executeScript(
          'window.MeetBridge && window.MeetBridge.sendChat("$escaped");',
        );
      } catch (e) {
        FrontendLogger.write(
          '[MeetAutomation] Error executing sendChat script: $e',
        );
      }
    }
  }

  /// Duyệt tất cả học sinh đang chờ vào phòng
  Future<void> admitAllPending() {
    if (linkedTeacherEmail != null) return Future.value();
    final running = _admissionBatch;
    if (running != null) return running;
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

  /// Tắt tiếng micro của toàn bộ học sinh trong phòng
  Future<bool> muteAllParticipants() async {
    final controller = _controller;
    if (!_hostJoined || controller == null) return false;

    final stopwatch = Stopwatch()..start();
    var openPeoplePanel = true;
    while (stopwatch.elapsed < const Duration(seconds: 3)) {
      try {
        final raw = await controller.executeScript(
          'window.MeetBridge ? window.MeetBridge.muteAll($openPeoplePanel) : false;',
        );
        openPeoplePanel = false;
        dynamic result = jsonDecode(raw);
        if (result is String) result = jsonDecode(result);
        if (result == true) return true;
      } catch (e) {
        FrontendLogger.write(
          '[MeetAutomation] Error executing muteAll script: $e',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
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
      await ctrl.executeScript(
        'window.MeetBridge && window.MeetBridge.removeParticipant("$safeName");',
      );
    } catch (e) {
      FrontendLogger.write(
        '[MeetAutomation] Error executing removeParticipant: $e',
      );
    }
  }

  /// Xóa sạch dữ liệu phiên học khi rời phòng
  void clearMeetingEvents() {
    _resetAdmissions();
    _hostJoined = false;
    _isScreenSharing = false;
    _messages.clear();
    _raisedHands.clear();
    _participants.clear();
    _pendingAdmitCount = 0;
    _isBridgeReady = false;
    notifyListeners();
  }

  /// Tạm dừng phiên giảng dạy (rời Studio tạm thời, giữ link Meet trên hệ thống)
  Future<void> pauseSession() async {
    _bridgeTimer?.cancel();
    await stopScreenSharing();
    notifyListeners();
  }

  /// Đóng lớp học hoàn toàn (mặc định kết thúc cuộc gọi cho tất cả mọi người trên Google Meet)
  Future<void> leaveClassroom({bool endForEveryone = true}) async {
    _bridgeTimer?.cancel();
    await stopScreenSharing();
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

    if (endForEveryone && _controller != null) {
      try {
        await _controller!.executeScript(r'''
          (async function() {
            try {
              function findEl(sel, kws) {
                var els = Array.from(document.querySelectorAll(sel));
                return els.find(function(el) {
                  var t = (el.innerText || el.textContent || el.getAttribute('aria-label') || '').toLowerCase();
                  return kws.some(function(kw) { return t.includes(kw); });
                }) || null;
              }

              var hangup = document.querySelector('button[aria-label*="rời khỏi" i], button[aria-label*="leave call" i], button[aria-label*="leave" i], button[data-call-action="end"]')
                || findEl('button', ['rời khỏi cuộc gọi', 'leave call', 'leave the call', 'kết thúc cuộc gọi']);

              if (hangup) {
                hangup.click();
                await new Promise(function(r) { setTimeout(r, 400); });
                var endAll = findEl('button, [role="menuitem"], [role="button"], li, div[role="menuitem"]', [
                  'kết thúc cuộc gọi cho mọi người',
                  'kết thúc cuộc gọi cho tất cả',
                  'kết thúc cho mọi người',
                  'end the call for everyone',
                  'end call for everyone',
                  'end for everyone'
                ]);
                if (endAll) {
                  endAll.click();
                  await new Promise(function(r) { setTimeout(r, 600); });
                }
              }
            } catch (e) {}
          })();
        ''');
        await Future.delayed(const Duration(milliseconds: 700));
      } catch (e) {
        FrontendLogger.write(
          '[MeetAutomation] Error ending call for everyone: $e',
        );
      }
    }

    if (_controller != null) {
      try {
        await _controller!.loadUrl('about:blank');
      } catch (e) {
        FrontendLogger.write('[MeetAutomation] Error resetting webview: $e');
      }
      try {
        _controller!.dispose();
      } catch (e) {
        FrontendLogger.write('[MeetAutomation] Error disposing webview: $e');
      }
      _controller = null;
      _controllerMeetingUrl = null;
    }
    notifyListeners();
  }

  /// Compatibility entry point. Presenting requires a user click inside Meet.
  Future<void> startAutoMeet() async {
    await createClassroom();
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
        await controller.executeScript(MeetFocusStyleScript.script);
        await controller.executeScript(MeetBridgeScript.script);
        await controller.executeScript(MeetAdmissionBridgeScript.script);
      } catch (err) {
        FrontendLogger.write('[MeetAutomation] Bridge inject error: $err');
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
    if (!MeetAutomationService.isOfficialMeetingUrl(url)) return;
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
      FrontendLogger.write('[MeetAutomation] ensureHostJoined error: $e');
    }
  }
}

class _AdmissionAttempt {
  _AdmissionAttempt(this.id);
  final String id;
  final Completer<bool> completer = Completer<bool>();
  Timer? timer;
}
