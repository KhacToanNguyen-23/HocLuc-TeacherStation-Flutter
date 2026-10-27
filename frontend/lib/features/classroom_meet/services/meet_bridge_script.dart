/// Dart wrapper providing the Google Meet Bridge Script for WebView2 injection.
class MeetBridgeScript {
  static const String script = r'''
(function() {
  if (!document.body) return;
  if (window.__meetBridgeInstalled) {
    if (window.MeetBridge && window.MeetBridge.resync) window.MeetBridge.resync();
    else if (window.MeetBridge && window.MeetBridge.reportCallState) window.MeetBridge.reportCallState();
    return;
  }
  window.__meetBridgeInstalled = true;

  var bridgeDocument = document;
  var documentId = 'meet-' + Date.now() + '-' + Math.random().toString(36).slice(2);
  function sendToFlutter(type, payload) {
    try {
      var msg = JSON.stringify({ type: type, payload: payload, documentId: documentId, url: window.location.href, timestamp: Date.now() });
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(msg);
      }
    } catch (e) {
      console.error('[MeetBridge] PostMessage error:', e);
    }
  }

  function confirmedCallButton() {
    // Chat/admission text can contain waiting-room phrases during a live call.
    // Only an actual visible connected hangup control proves the joined state.
    return Array.from(document.querySelectorAll('button[aria-label*="rời khỏi" i], button[aria-label*="rời cuộc gọi" i], button[aria-label*="kết thúc cuộc gọi" i], button[aria-label*="leave call" i], button[aria-label*="leave the call" i]')).find(function(button) {
      if (!button.isConnected || button.hidden || button.getAttribute('aria-hidden') === 'true' || !button.getClientRects().length) return false;
      var style = window.getComputedStyle ? window.getComputedStyle(button) : null;
      return !style || (style.visibility !== 'hidden' && style.visibility !== 'collapse' && style.display !== 'none');
    }) || null;
  }
  function reportCallState() {
    if (confirmedCallButton()) sendToFlutter('MEET_JOINED', { status: 'joined', url: window.location.href });
  }
  function resync() {
    // Re-establish document identity before call state when the host reattaches.
    // The retained closure/lease stays intact and this handshake never clicks UI.
    sendToFlutter('MEET_BRIDGE_READY', { status: 'ready', url: window.location.href });
    reportCallState();
  }
  function attemptAutoJoin() {
    if (window.__hoclucManualJoin) {
      var joined = confirmedCallButton();
      if (joined) sendToFlutter('MEET_JOINED', { status: 'joined', url: window.location.href });
      return !!joined;
    }
    var activeCall = confirmedCallButton();
    if (activeCall) {
      sendToFlutter('MEET_JOINED', { status: 'joined', url: window.location.href });
      return true;
    }
    var buttons = Array.from(document.querySelectorAll('button'));

    // 1. Tự động bypass popup cấp quyền media / micro / camera của Google Meet
    var permBtn = buttons.find(function(b) {
      var t = (b.innerText || b.textContent || '').trim().toLowerCase();
      return t.includes('sử dụng micrô') || 
             t.includes('use microphone') || 
             t.includes('cho phép') || 
             t.includes('allow') || 
             t.includes('tiếp tục mà không') ||
             t.includes('continue without');
    }) || document.querySelector('button[data-id="EBS5Fd"]');
    if (permBtn) {
      permBtn.click();
    }

    // 2. Tự động click Tham gia ngay / Join now / Chuyển vào đây
    var joinBtn = buttons.find(function(b) {
      var text = (b.innerText || b.textContent || '').trim().toLowerCase();
      var aria = (b.getAttribute('aria-label') || '').toLowerCase();
      return text.includes('tham gia ngay') || 
             text.includes('join now') || 
             text.includes('chuyển vào đây') ||
             text.includes('switch here') ||
             text.includes('yêu cầu tham gia') ||
             text.includes('ask to join') ||
             aria.includes('tham gia ngay') ||
             aria.includes('join now');
    }) || document.querySelector('button[jsname="Qx7uuf"]');

    // Kiểm tra xem đã vào phòng chưa (nút kết thúc cuộc gọi đỏ)
    var inCall = confirmedCallButton();
    if (inCall) {
      sendToFlutter('MEET_JOINED', { status: 'joined', url: window.location.href });
      return true;
    }

    if (joinBtn && !joinBtn.disabled) {
      try {
        joinBtn.click();
      } catch(e) {}
      // Không dừng interval ngay, để lần tick sau kiểm tra xem inCall đã xuất hiện chưa
    }
    return false;
  }

  var seenMessageIds = new Set();
  var tutorObservationReady = false;
  var tutorObservedInput = null;
  function messageId(node) {
    var row = node.closest('[data-message-id]') || node;
    var nativeId = row.getAttribute('data-message-id');
    if (nativeId) return documentId + ':' + nativeId;
    var sender = node.getAttribute('data-sender-name') || (node.closest('[data-sender-name]') || node).getAttribute('data-sender-name') || '';
    var text = (node.getAttribute('data-message-text') || node.innerText || '').trim();
    // Conservative fallback survives DOM remounts; identical repeats may be dropped.
    return documentId + ':fallback:' + JSON.stringify([sender, text]);
  }
  function isSelfMessage(node) {
    // Names (including "You") are user-controlled and are never identity proof.
    var row = node.closest('[data-is-self], [data-self], [data-sender-id]');
    if (!row) return false;
    if (row.getAttribute('data-is-self') === 'true' || row.getAttribute('data-self') === 'true') return true;
    var self = document.querySelector('[data-participant-id][data-is-self="true"], [data-participant-id][data-self="true"]');
    return !!self && !!row.getAttribute('data-sender-id') && row.getAttribute('data-sender-id') === self.getAttribute('data-participant-id');
  }
  function chatNodes() {
    return Array.from(document.querySelectorAll('[data-message-text], div[data-sender-name]')).filter(function(node) {
      return !node.querySelector('[data-message-text]');
    });
  }
  var tutorAttempt = null;
  var uncertainTutorTexts = new Set();
  function chatInput() {
    var input = document.querySelector('textarea[name="chatTextInput"], textarea[aria-label*="tin nhắn" i], textarea[aria-label*="message" i], [contenteditable="true"][aria-label*="tin nhắn" i], [contenteditable="true"][aria-label*="message" i]');
    return input && input.isConnected && input.getClientRects().length ? input : null;
  }
  var tutorObservationWanted = false;
  var tutorObservationId = null;
  var tutorObservationCommand = null;
  var tutorInitialBaseline = false;
  var tutorStableInput = null;
  var tutorStableSignature = null;
  var tutorStableSince = 0;
  var tutorOpening = null;
  var tutorDeferredRows = new Map();
  // Recent cancelled leases block commands that arrive out of order. Expiry
  // rejects old transport commands even after their tombstone is evicted.
  var tutorEndedObservations = new Set();
  function observationState(ready) {
    tutorObservationReady = ready;
    sendToFlutter('TUTOR_OBSERVATION_STATE', {observationId: tutorObservationId, ready: ready});
  }
  function visibleTutorAction(node) {
    return node && node.isConnected && node.getClientRects().length &&
      !node.disabled && node.getAttribute('aria-disabled') !== 'true';
  }
  function namedTutorAction(pattern) {
    return Array.from(document.querySelectorAll('button, [role="button"], [role="menuitem"]')).find(function(node) {
      var label = (node.getAttribute('aria-label') || node.innerText || node.textContent || '').trim();
      return visibleTutorAction(node) && pattern.test(label);
    });
  }
  function expandedTutorAction(node) {
    return node.getAttribute('aria-expanded') === 'true' || node.getAttribute('aria-pressed') === 'true';
  }
  function openTutorChat() {
    if (!tutorOpening) tutorOpening = {menuClicked: false, chatClicked: false};
    if (tutorOpening.chatClicked) return;
    var direct = document.querySelector('button[aria-label*="trò chuyện" i], button[aria-label*="chat" i]');
    var chatName = /^(?:chat|trò chuyện|in-call messages|chat with everyone|send a message to everyone|tin nhắn trong cuộc gọi|trò chuyện với mọi người|gửi tin nhắn cho mọi người)(?:\s*\([^)]*\))?$/i;
    var action = visibleTutorAction(direct) && chatName.test((direct.getAttribute('aria-label') || '').trim()) ? direct : namedTutorAction(chatName);
    if (action) {
      tutorOpening.chatClicked = true;
      if (!expandedTutorAction(action)) action.click();
      return;
    }
    if (!tutorOpening.menuClicked) {
      var menu = namedTutorAction(/^(?:more options|tùy chọn khác|tuỳ chọn khác|các tùy chọn khác|thêm tùy chọn)(?:\s*\([^)]*\))?$/i);
      if (menu) {
        // Record the transition before clicking: its DOM mutations can reenter
        // observation. Never toggle the menu again while its contents load.
        tutorOpening.menuClicked = true;
        if (!expandedTutorAction(menu)) menu.click();
      }
    }
  }
  function maintainTutorObservation() {
    if (!tutorObservationWanted) return;
    var input = tutorContext(tutorObservationCommand) ? chatInput() : null;
    if (tutorObservationReady && input !== tutorObservedInput) observationState(false);
    if (!input) {
      tutorStableInput = null;
      tutorStableSignature = null;
      if (tutorContext(tutorObservationCommand)) openTutorChat();
      return;
    }
    // A later close/remount starts a new recovery episode. Within each episode
    // an opening click is issued once, even if Meet renders the input slowly.
    tutorOpening = null;
    if (tutorObservationReady) return;
    var signature = JSON.stringify(chatNodes().map(function(node) {
      return [messageId(node), node.getAttribute('data-message-text') || node.innerText || ''];
    }));
    if (input !== tutorStableInput || signature !== tutorStableSignature) {
      tutorStableInput = input;
      tutorStableSignature = signature;
      tutorStableSince = Date.now();
      return;
    }
    if (Date.now() - tutorStableSince < 250) return;
    tutorObservedInput = input;
    if (!tutorInitialBaseline) {
      // All rows loaded during the first stable history snapshot are historical.
      scanChatMessages(true);
      tutorInitialBaseline = true;
    }
    observationState(true);
  }
  function beginTutorObservation(command) {
    if (!tutorContext(command)) return JSON.stringify({status: 'NOT_READY'});
    var id = command.observationId || 'legacy';
    if ((command.expiresAt !== undefined &&
        (!Number.isFinite(command.expiresAt) || Date.now() >= command.expiresAt)) ||
        tutorEndedObservations.has(id)) return JSON.stringify({status: 'NOT_READY'});
    if (!tutorObservationWanted || id !== tutorObservationId) {
      tutorObservationWanted = true;
      tutorObservationId = id;
      tutorObservationCommand = {documentId: command.documentId, url: command.url};
      tutorInitialBaseline = false;
      tutorStableInput = null;
      tutorStableSignature = null;
      tutorOpening = null;
      tutorDeferredRows.clear();
      observationState(false);
    }
    scanChatMessages();
    return JSON.stringify({status: tutorObservationReady ? 'READY' : 'PENDING', documentId: documentId, url: window.location.href, observationId: id});
  }
  function endTutorObservation(command) {
    if (!command || command.documentId !== documentId || command.url !== window.location.href ||
        document !== bridgeDocument) return false;
    var id = command.observationId || 'legacy';
    tutorEndedObservations.add(id);
    if (tutorEndedObservations.size > 256) {
      tutorEndedObservations.delete(tutorEndedObservations.values().next().value);
    }
    // An old stop still tombstones its own lease, but cannot stop a newer one.
    if (!tutorObservationCommand || command.url !== tutorObservationCommand.url ||
        id !== tutorObservationId) return false;
    tutorObservationWanted = false;
    tutorDeferredRows.clear();
    tutorStableInput = null;
    tutorObservedInput = null;
    tutorOpening = null;
    observationState(false);
    return true;
  }
  function cancelTutor(command) {
    if (command && command.documentId === documentId && tutorAttempt && command.requestId === tutorAttempt.requestId) {
      if (!tutorAttempt.confirmed) uncertainTutorTexts.add(tutorAttempt.text);
      tutorAttempt.cancelled = true;
    }
    return false;
  }
  function tutorContext(command) {
    return command && command.documentId === documentId && document === bridgeDocument &&
      command.url === window.location.href && !!confirmedCallButton();
  }
  function tutorStatus(command) {
    if (!tutorContext(command) || !tutorAttempt || tutorAttempt.requestId !== command.requestId) return JSON.stringify({status: 'STALE'});
    if (tutorAttempt.cancelled) return JSON.stringify({status: 'CANCELLED'});
    if (tutorAttempt.confirmed) return JSON.stringify({status: 'CONFIRMED', requestId: command.requestId, documentId: documentId, url: window.location.href});
    if (Date.now() >= tutorAttempt.deadline) {
      uncertainTutorTexts.add(tutorAttempt.text);
      clearTutorDraft(chatInput(), tutorAttempt.text);
      return JSON.stringify({status: 'TIMEOUT'});
    }
    var confirmed = chatNodes().some(function(node) {
      return !tutorAttempt.baseline.has(messageId(node)) && isSelfMessage(node) &&
        (node.getAttribute('data-message-text') || node.innerText || '').trim() === tutorAttempt.text;
    });
    if (confirmed) tutorAttempt.confirmed = true;
    return JSON.stringify({status: confirmed ? 'CONFIRMED' : 'PENDING', requestId: command.requestId, documentId: documentId, url: window.location.href});
  }
  function clearTutorDraft(input, text) {
    if (!input || (input.isContentEditable ? input.textContent : input.value) !== text) return;
    if (input.isContentEditable) input.textContent = '';
    else {
      var setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(input), 'value');
      if (setter && setter.set) setter.set.call(input, ''); else input.value = '';
    }
    input.dispatchEvent(new Event('input', {bubbles: true}));
  }
  function sendTutor(command) {
    if (!command || !tutorObservationWanted || !command.observationId || command.observationId !== tutorObservationId || tutorEndedObservations.has(command.observationId)) return JSON.stringify({status: 'NOT_READY'});
    if (!tutorObservationReady || chatInput() !== tutorObservedInput || !tutorContext(command) || !command.requestId || !Number.isFinite(command.expiresAt) || Date.now() >= command.expiresAt || typeof command.text !== 'string' || !command.text.trim()) return JSON.stringify({status: 'NOT_READY'});
    if (tutorAttempt && !tutorAttempt.cancelled && JSON.parse(tutorStatus(tutorAttempt)).status === 'PENDING') return JSON.stringify({status: 'BUSY'});
    if (uncertainTutorTexts.has(command.text.trim())) return JSON.stringify({status: 'UNCONFIRMED'});
    var input = chatInput();
    // No delayed click/retry: a closed panel or a teacher draft fails safely.
    if (!input || input.disabled || input.readOnly || (input.value || input.textContent || '')) return JSON.stringify({status: 'INPUT_BUSY'});
    var send = document.querySelector('button[aria-label*="gửi" i], button[aria-label*="send" i], [data-tooltip*="gửi" i]');
    if (!send) return JSON.stringify({status: 'NOT_READY'});
    tutorAttempt = Object.assign({}, command, {text: command.text.trim(), deadline: Math.min(command.expiresAt, Date.now() + Math.min(command.timeoutMs || 10000, 10000)), baseline: new Set(Array.from(seenMessageIds).concat(chatNodes().map(messageId)))});
    if (input.isContentEditable) input.textContent = tutorAttempt.text;
    else {
      var setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(input), 'value');
      if (setter && setter.set) setter.set.call(input, tutorAttempt.text);
      else input.value = tutorAttempt.text;
    }
    input.dispatchEvent(new Event('input', {bubbles: true}));
    if (!tutorContext(command) || Date.now() >= tutorAttempt.deadline || send.disabled || !input.isConnected || !send.isConnected) {
      clearTutorDraft(input, tutorAttempt.text);
      tutorAttempt = null;
      return JSON.stringify({status: 'NOT_READY'});
    }
    send.click();
    return tutorStatus(command);
  }
  function scanChatMessages(baselineOnly) {
    if (!baselineOnly) maintainTutorObservation();
    var messageNodes = chatNodes();
    if (!baselineOnly && tutorObservationWanted && tutorInitialBaseline && !tutorObservationReady) {
      messageNodes.forEach(function(node) {
        if (!seenMessageIds.has(messageId(node))) tutorDeferredRows.set(messageId(node), node);
      });
      return;
    }
    if (tutorObservationReady && tutorDeferredRows.size) {
      messageNodes = Array.from(tutorDeferredRows.values()).concat(messageNodes);
      tutorDeferredRows.clear();
    }
    messageNodes.forEach(function(node) {
      var text = (node.getAttribute('data-message-text') || node.innerText || '').trim();
      var sender = node.getAttribute('data-sender-name') || '';
      
      if (!sender) {
        var parent = node.closest('[data-sender-name]');
        if (parent) sender = parent.getAttribute('data-sender-name') || '';
      }
      if (!sender) {
        var header = node.parentElement ? node.parentElement.querySelector('[data-self-name], .name, strong, b') : null;
        if (header) sender = (header.innerText || '').trim();
      }
      if (!sender) sender = 'Học sinh';

      if (!text) return;

      var id = messageId(node);
      if (!seenMessageIds.has(id)) {
        seenMessageIds.add(id);
        sendToFlutter('CHAT_MESSAGE', {
          observationId: tutorObservationId,
          id: id,
          sender: sender,
          isSelf: isSelfMessage(node),
          isTutorEligible: tutorObservationReady && !!chatInput(),
          sourceDocumentId: documentId,
          text: text,
          time: new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' })
        });
      }
    });
  }

  var lastParticipantsKey = '';
  function scanParticipants() {
    var nodes = Array.from(document.querySelectorAll('[data-participant-id]'));
    if (nodes.length === 0) return;

    var participants = [];
    nodes.forEach(function(node) {
      var id = node.getAttribute('data-participant-id') || '';
      var text = (node.innerText || '').trim();
      var lines = text.split('\n').map(function(s) { return s.trim(); }).filter(Boolean);
      var name = lines[0] || '';
      if (!name) return;
      if (name.toLowerCase() === 'bạn' || text.toLowerCase().includes('(chủ phòng)')) return;

      var isMuted = !!node.querySelector('[data-is-muted="true"], [aria-label*="đã tắt tiếng" i], [aria-label*="mic is off" i]');
      var isHandRaised = !!node.querySelector('[data-is-hand-raised="true"], [aria-label*="giơ tay" i], [aria-label*="raised hand" i]');
      participants.push({
        id: id || ('p_' + name),
        name: name,
        isMuted: isMuted,
        isHandRaised: isHandRaised,
        isSpeaking: false
      });
    });

    var key = participants.map(function(p) { return p.name + ':' + p.isMuted + ':' + p.isHandRaised; }).join(',');
    if (key !== lastParticipantsKey) {
      lastParticipantsKey = key;
      sendToFlutter('PARTICIPANTS_UPDATE', participants);
    }
  }

  var lastHandsCount = -1;
  function scanHandsAndKnocks() {
    var handElements = Array.from(document.querySelectorAll('[aria-label*="giơ tay" i], [aria-label*="raised hand" i], [data-is-hand-raised="true"]'));
    var handCount = handElements.length;
    if (handCount !== lastHandsCount) {
      lastHandsCount = handCount;
      var raisedNames = handElements.map(function(el) {
        var container = el.closest('[data-participant-id]') || el.parentElement;
        return (container ? container.innerText : '').trim() || 'Học sinh';
      });
      sendToFlutter('RAISE_HANDS_UPDATE', { count: handCount, names: raisedNames });
    }

  }

  var observer = new MutationObserver(function() {
    scanChatMessages();
    scanHandsAndKnocks();
    scanParticipants();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true
  });

  var joinInterval = setInterval(function() {
    if (attemptAutoJoin()) {
      clearInterval(joinInterval);
    }
  }, 1000);

  setInterval(function() {
    // Participant polling is read-only and must not close chat or teacher menus.
    scanParticipants();
    scanHandsAndKnocks();
  }, 1000);

  setInterval(function() { scanChatMessages(); }, 100);

  window.MeetBridge = {
    endTutorObservation: endTutorObservation,
    beginTutorObservation: beginTutorObservation,
    cancelTutor: cancelTutor,
    sendTutor: sendTutor,
    tutorStatus: tutorStatus,
    attemptAutoJoin: attemptAutoJoin,
    resync: resync,
    reportCallState: reportCallState,
    // Admission is exclusively driven by the teacher's named request snapshot.
    admitAll: function() { return false; },
    removeParticipant: function(targetName) {
      if (!targetName) return false;
      var clean = targetName.trim().toLowerCase();
      var nodes = Array.from(document.querySelectorAll('[data-participant-id], div[role="listitem"]'));
      var targetNode = nodes.find(function(n) {
        return (n.innerText || '').toLowerCase().includes(clean);
      });
      if (targetNode) {
        var menuBtn = targetNode.querySelector('button[aria-label*="thao tác khác" i], button[aria-label*="more actions" i], button[aria-label*="thêm" i]');
        if (menuBtn) {
          menuBtn.click();
          setTimeout(function() {
            var removeBtn = Array.from(document.querySelectorAll('[role="menuitem"], button')).find(function(m) {
              var t = (m.innerText || m.textContent || '').toLowerCase();
              return t.includes('xóa khỏi cuộc gọi') || t.includes('remove from the call') || t.includes('xóa');
            });
            if (removeBtn) {
              removeBtn.click();
              setTimeout(function() {
                var confirmBtn = Array.from(document.querySelectorAll('button')).find(function(c) {
                  var t = (c.innerText || c.textContent || '').toLowerCase();
                  return t.includes('xóa') || t.includes('remove');
                });
                if (confirmBtn) confirmBtn.click();
              }, 400);
            }
          }, 300);
          return true;
        }
      }
      return false;
    },

    muteAll: function(openPeoplePanel) {
      var normalize = function(value) {
        return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
      };
      var buttons = Array.from(document.querySelectorAll('button, [role="button"]'));
      var labelOf = function(b) {
        return normalize([b.innerText, b.textContent, b.getAttribute('aria-label'), b.getAttribute('data-tooltip'), b.title].join(' ')).replace(/\s+/g, ' ').trim();
      };
      var inCall = buttons.some(function(b) {
        return /leave call|leave the call|roi khoi|roi cuoc goi|ket thuc cuoc goi/.test(labelOf(b));
      });
      if (!inCall) return false;

      var peopleButton = buttons.find(function(b) {
        return /people|participants|nguoi tham gia|moi nguoi/.test(labelOf(b));
      }) || document.querySelector('button[data-panel-id="1"]');
      var panel = Array.from(document.querySelectorAll('[role="tabpanel"], [data-tab-id="1"], div[jsname="AznF2e"]')).find(function(el) {
        return /people|participants|moi nguoi|nguoi tham gia/.test(labelOf(el)) || el.matches('[data-tab-id="1"], div[jsname="AznF2e"]');
      });
      if (openPeoplePanel && (!panel || panel.offsetParent === null) && peopleButton && !peopleButton.disabled) {
        peopleButton.click();
      }

      var findAndMute = function() {
        var muteButton = Array.from(document.querySelectorAll('button, [role="button"]')).find(function(b) {
          var label = labelOf(b);
          return /^(mute everyone|mute all|tat tieng moi nguoi|tat tieng tat ca)(\b|$)/.test(label);
        });
        if (muteButton && !muteButton.disabled) {
          muteButton.click();
          return true;
        }
        return false;
      };
      return findAndMute();
    },

    sendChat: function(message) {
      if (!message || !message.trim()) return false;

      var input = document.querySelector('textarea[name="chatTextInput"], textarea[aria-label*="tin nhắn" i], textarea[aria-label*="message" i], [contenteditable="true"][aria-label*="tin nhắn" i]');
      if (!input) {
        var chatPanelBtn = document.querySelector('button[aria-label*="trò chuyện" i], button[aria-label*="chat" i]');
        if (chatPanelBtn) {
          chatPanelBtn.click();
          setTimeout(function() { window.MeetBridge.sendChat(message); }, 500);
          return true;
        }
        return false;
      }

      input.value = message;
      input.dispatchEvent(new Event('input', { bubbles: true }));

      var sendBtn = document.querySelector('button[aria-label*="gửi" i], button[aria-label*="send" i], [data-tooltip*="gửi" i]');
      if (sendBtn) {
        sendBtn.click();
        return true;
      }
      return false;
    },

    setMicMute: function(muted) {
      var micBtn = Array.from(document.querySelectorAll('button')).find(function(b) {
        var a = (b.getAttribute('aria-label') || '').toLowerCase();
        return a.includes('micro') || a.includes('microphone') || a.includes('tắt mic') || a.includes('bật mic');
      });
      if (micBtn) {
        var isCurrentlyMuted = (micBtn.getAttribute('aria-label') || '').toLowerCase().includes('bật') ||
                               (micBtn.getAttribute('data-is-muted') === 'true');
        if (isCurrentlyMuted !== muted) {
          micBtn.click();
          return true;
        }
      }
      return false;
    },

    setCamMute: function(muted) {
      var camBtn = Array.from(document.querySelectorAll('button')).find(function(b) {
        var a = (b.getAttribute('aria-label') || '').toLowerCase();
        return a.includes('máy ảnh') || a.includes('camera') || a.includes('tắt máy ảnh') || a.includes('bật máy ảnh');
      });
      if (camBtn) {
        var isCurrentlyMuted = (camBtn.getAttribute('aria-label') || '').toLowerCase().includes('bật') ||
                               (camBtn.getAttribute('data-is-muted') === 'true');
        if (isCurrentlyMuted !== muted) {
          camBtn.click();
          return true;
        }
      }
      return false;
    }
  };

  resync();
})();
''';
}

