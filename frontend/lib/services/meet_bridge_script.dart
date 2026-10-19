/// Dart wrapper providing the Google Meet Bridge Script for WebView2 injection.
class MeetBridgeScript {
  static const String script = r'''
(function() {
  if (!document.body) return;
  if (window.__meetBridgeInstalled) {
    if (window.MeetBridge && window.MeetBridge.reportCallState) window.MeetBridge.reportCallState();
    return;
  }
  window.__meetBridgeInstalled = true;

  function sendToFlutter(type, payload) {
    try {
      var msg = JSON.stringify({ type: type, payload: payload, timestamp: Date.now() });
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(msg);
      }
    } catch (e) {
      console.error('[MeetBridge] PostMessage error:', e);
    }
  }

  function confirmedCallButton() {
    var text = (document.body.innerText || '').toLowerCase();
    if (text.includes('vui lòng đợi cho đến khi người tổ chức') || text.includes('wait until the host') || text.includes('asking to join')) return null;
    return document.querySelector('button[aria-label*="rời khỏi" i], button[aria-label*="rời cuộc gọi" i], button[aria-label*="kết thúc cuộc gọi" i], button[aria-label*="leave call" i], button[aria-label*="leave the call" i]');
  }
  function reportCallState() {
    if (confirmedCallButton()) sendToFlutter('MEET_JOINED', { status: 'joined', url: window.location.href });
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
  function scanChatMessages() {
    var messageNodes = document.querySelectorAll('[data-message-text], div[data-sender-name]');
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

      var id = sender + '_' + text;
      if (!seenMessageIds.has(id)) {
        seenMessageIds.add(id);
        sendToFlutter('CHAT_MESSAGE', {
          id: id,
          sender: sender,
          text: text,
          time: new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' })
        });
      }
    });
  }

  function ensurePeoplePanelOpen() {
    var inCall = document.querySelector('button[aria-label*="rời khỏi" i], button[aria-label*="leave call" i]');
    if (!inCall) return;

    var panel = document.querySelector('[aria-label*="mọi người" i][role="tabpanel"], div[jsname="AznF2e"], [data-tab-id="1"]');
    var isPanelVisible = panel && panel.offsetParent !== null;
    if (!isPanelVisible) {
      var peopleBtn = document.querySelector('button[aria-label*="mọi người" i], button[aria-label*="people" i], button[data-panel-id="1"]');
      if (peopleBtn && !peopleBtn.disabled) {
        peopleBtn.click();
      }
    }
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
    ensurePeoplePanelOpen();
    scanParticipants();
    scanHandsAndKnocks();
  }, 1000);

  window.MeetBridge = {
    attemptAutoJoin: attemptAutoJoin,
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

    muteAll: function() {
      var buttons = Array.from(document.querySelectorAll('button')).filter(function(b) {
        var t = (b.innerText || b.textContent || '').trim().toLowerCase();
        var a = (b.getAttribute('aria-label') || '').toLowerCase();
        return t.includes('tắt tiếng tất cả') || t.includes('mute all') ||
               a.includes('tắt tiếng tất cả') || a.includes('mute all');
      });
      buttons.forEach(function(btn) { btn.click(); });
      return buttons.length;
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

  sendToFlutter('MEET_BRIDGE_READY', { status: 'ready', url: window.location.href });
})();
''';
}
