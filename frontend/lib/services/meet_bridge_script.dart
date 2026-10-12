/// Dart wrapper providing the Google Meet Bridge Script for WebView2 injection.
class MeetBridgeScript {
  static const String script = '''
(function() {
  if (window.__meetBridgeInstalled) {
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

  function attemptAutoJoin() {
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

    if (joinBtn) {
      joinBtn.click();
      sendToFlutter('MEET_JOINED', { status: 'joined', url: window.location.href });
      return true;
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

    var admitButtons = Array.from(document.querySelectorAll('button')).filter(function(b) {
      var t = (b.innerText || b.textContent || '').trim().toLowerCase();
      var a = (b.getAttribute('aria-label') || '').toLowerCase();
      return t.includes('chấp nhận') || t.includes('admit') || a.includes('chấp nhận') || a.includes('admit');
    });

    if (admitButtons.length > 0) {
      sendToFlutter('ADMIT_REQUEST', { pendingCount: admitButtons.length });
    }
  }

  var observer = new MutationObserver(function() {
    scanChatMessages();
    scanHandsAndKnocks();
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

  window.MeetBridge = {
    admitAll: function() {
      var buttons = Array.from(document.querySelectorAll('button')).filter(function(b) {
        var t = (b.innerText || b.textContent || '').trim().toLowerCase();
        var a = (b.getAttribute('aria-label') || '').toLowerCase();
        return t.includes('chấp nhận tất cả') || t.includes('admit all') || 
               t.includes('chấp nhận') || t.includes('admit') ||
               a.includes('chấp nhận tất cả') || a.includes('admit all');
      });
      buttons.forEach(function(btn) { btn.click(); });
      return buttons.length;
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

    startPresenting: function() {
      var presentBtn = Array.from(document.querySelectorAll('button')).find(function(b) {
        var t = (b.innerText || b.textContent || '').trim().toLowerCase();
        var a = (b.getAttribute('aria-label') || '').toLowerCase();
        return t.includes('trình bày ngay') || t.includes('present now') ||
               a.includes('trình bày ngay') || a.includes('present now') ||
               a.includes('share screen') || a.includes('chia sẻ màn hình');
      });
      if (presentBtn) {
        presentBtn.click();
        return true;
      }
      return false;
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

  if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
    try {
      navigator.mediaDevices.enumerateDevices().then(function(devices) {
        var hocLucCam = devices.find(function(d) { return (d.label || '').includes('HocLuc'); });
        var hocLucMic = devices.find(function(d) { return (d.label || '').includes('HocLuc'); });
        sendToFlutter('MEET_MEDIA_DEVICE_SELECTED', {
          hasHocLucCam: !!hocLucCam,
          hasHocLucMic: !!hocLucMic,
          camLabel: hocLucCam ? hocLucCam.label : 'Default',
          micLabel: hocLucMic ? hocLucMic.label : 'Default'
        });
      });
    } catch (e) {}
  }

  sendToFlutter('MEET_BRIDGE_READY', { status: 'ready', url: window.location.href });
})();
''';
}
