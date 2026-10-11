/**
 * Google Meet Headless Bridge Script
 * Injected into WebView2 session running Google Meet.
 * Uses MutationObserver to capture Chat, Hands, Participant changes, and Admission requests.
 * Exposes window.MeetBridge for remote commands from Teacher Station.
 */
(function() {
  if (window.__meetBridgeInstalled) {
    console.log('[MeetBridge] Already installed.');
    return;
  }
  window.__meetBridgeInstalled = true;

  console.log('[MeetBridge] Installing Headless Google Meet Bridge...');

  // Safe PostMessage to Host (Flutter WebView2)
  function sendToFlutter(type, payload) {
    try {
      var msg = JSON.stringify({ type: type, payload: payload, timestamp: Date.now() });
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(msg);
      } else {
        console.log('[MeetBridge PostMessage]', type, payload);
      }
    } catch (e) {
      console.error('[MeetBridge] Error sending to host:', e);
    }
  }

  // 1. AUTO-JOIN & PERMISSION POPUP HANDLER
  function attemptAutoJoin() {
    var buttons = Array.from(document.querySelectorAll('button'));
    var joinBtn = buttons.find(function(b) {
      var text = (b.innerText || b.textContent || '').trim().toLowerCase();
      var aria = (b.getAttribute('aria-label') || '').toLowerCase();
      return text.includes('tham gia ngay') || 
             text.includes('join now') || 
             text.includes('chuyển vào đây') ||
             text.includes('switch here') ||
             aria.includes('tham gia ngay') ||
             aria.includes('join now');
    });

    if (joinBtn) {
      console.log('[MeetBridge] Clicking Join Button...');
      joinBtn.click();
      sendToFlutter('MEET_JOINED', { status: 'joined', url: window.location.href });
      return true;
    }
    return false;
  }

  // 2. CHAT MUTATION OBSERVER
  var seenMessageIds = new Set();
  function scanChatMessages() {
    // Select elements containing chat message lines
    var messageNodes = document.querySelectorAll('[data-message-text], div[data-sender-name]');
    messageNodes.forEach(function(node) {
      var text = (node.getAttribute('data-message-text') || node.innerText || '').trim();
      var sender = node.getAttribute('data-sender-name') || '';
      
      // Fallback for different Google Meet layouts
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

      var id = sender + '_' + text + '_' + node.getAttribute('data-formatted-timestamp');
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

  // 3. RAISED HANDS & ADMISSION SCANNER
  var lastHandsCount = -1;
  function scanHandsAndKnocks() {
    // Raised hands icons/badges
    var handElements = Array.from(document.querySelectorAll('[aria-label*="giơ tay" i], [aria-label*="raised hand" i], [data-is-hand-raised="true"]'));
    var handCount = handElements.length;
    if (handCount !== lastHandsCount) {
      lastHandsCount = handCount;
      var raisedNames = handElements.map(function(el) {
        var container = el.closest('[data-participant-id]') || el.parentElement;
        return (container ? container.innerText : '') || 'Học sinh';
      });
      sendToFlutter('RAISE_HANDS_UPDATE', { count: handCount, names: raisedNames });
    }

    // Admission requests ("Someone wants to join this call" / "Ai đó muốn tham gia")
    var admitButtons = Array.from(document.querySelectorAll('button')).filter(function(b) {
      var t = (b.innerText || b.textContent || '').trim().toLowerCase();
      var a = (b.getAttribute('aria-label') || '').toLowerCase();
      return t.includes('chấp nhận') || t.includes('admit') || a.includes('chấp nhận') || a.includes('admit');
    });

    if (admitButtons.length > 0) {
      sendToFlutter('ADMIT_REQUEST', { pendingCount: admitButtons.length });
    }
  }

  // Main Observer
  var observer = new MutationObserver(function() {
    scanChatMessages();
    scanHandsAndKnocks();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true
  });

  // Periodically attempt join until in-meeting
  var joinInterval = setInterval(function() {
    if (attemptAutoJoin()) {
      clearInterval(joinInterval);
    }
  }, 1000);

  // 4. REMOTE COMMANDS EXPOSED TO FLUTTER
  window.MeetBridge = {
    admitAll: function() {
      console.log('[MeetBridge] Executing admitAll...');
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
      console.log('[MeetBridge] Executing muteAll...');
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
      console.log('[MeetBridge] Triggering Screen Share Presentation...');
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
      console.log('[MeetBridge] Sending chat message:', message);
      if (!message || !message.trim()) return false;

      // Find chat input
      var input = document.querySelector('textarea[name="chatTextInput"], textarea[aria-label*="tin nhắn" i], textarea[aria-label*="message" i], [contenteditable="true"][aria-label*="tin nhắn" i]');
      if (!input) {
        // Try opening chat panel first
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

      // Find send button
      var sendBtn = document.querySelector('button[aria-label*="gửi" i], button[aria-label*="send" i], [data-tooltip*="gửi" i]');
      if (sendBtn) {
        sendBtn.click();
        return true;
      }
      return false;
    }
  };

  sendToFlutter('MEET_BRIDGE_READY', { status: 'ready', url: window.location.href });
})();
