/// Small, idempotent style injection for the embedded Google Meet surface.
/// It only runs on meet.google.com and hides optional Gemini promotions.
class MeetFocusStyleScript {
  static const String script = r'''
(function() {
  var host = window.location.hostname.toLowerCase();
  if (host !== 'meet.google.com' && !host.endsWith('.meet.google.com')) {
    return false;
  }

  var styleId = 'hocluc-meet-focus-style-v2';
  if (!document.getElementById(styleId)) {
    var style = document.createElement('style');
    style.id = styleId;
    style.textContent = `
      div[aria-label*="Gemini" i],
      div[data-promo-anchor-id],
      div:has(> svg path[d*="gemini"]),
      .google-meet-footer-promo {
        display: none !important;
        visibility: hidden !important;
        height: 0 !important;
        pointer-events: none !important;
      }
      html, body {
        overflow-y: auto !important;
        overflow-x: hidden !important;
      }
    `;
    (document.head || document.documentElement).appendChild(style);
  }

  if (!window.__hoclucMeetCompactUiV1) {
    var observeTarget = document.body || document.documentElement;
    if (!observeTarget) return true;

    window.__hoclucMeetCompactUiV1 = true;

    var normalize = function(value) {
      return String(value || '')
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/\u0111/g, 'd')
        .replace(/\s+/g, ' ')
        .trim();
    };

    var fitAccountSwitcher = function(element, text) {
      if (!/(switch account|change account|chuyen doi tai khoan)/.test(text)) {
        return;
      }

      element.style.setProperty('min-width', '0', 'important');
      element.style.setProperty('max-width', '100%', 'important');
      element.style.setProperty('white-space', 'normal', 'important');
      element.style.setProperty('overflow-wrap', 'anywhere', 'important');

      for (var current = element, depth = 0; current && depth < 5; depth++) {
        var bounds = current.getBoundingClientRect();
        if (bounds.right <= window.innerWidth + 1 && bounds.width <= window.innerWidth) {
          break;
        }
        var availableWidth = Math.max(0, window.innerWidth - Math.max(0, bounds.left));
        current.style.setProperty('min-width', '0', 'important');
        current.style.setProperty('max-width', availableWidth + 'px', 'important');
        current.style.setProperty('box-sizing', 'border-box', 'important');
        current = current.parentElement;
      }
    };

    var inspectElement = function(element) {
      if (!element || element.nodeType !== 1) return;
      var text = normalize(element.innerText || element.textContent);
      if (!text || text.length > 700) return;

      fitAccountSwitcher(element, text);
      if (element.dataset.hoclucGeminiHidden || !text.includes('gemini')) return;

      var isNotesPromotion =
        /(ghi chu|take notes|meeting notes|share notes|chia se ghi chu)/.test(text);
      var isAnalysisNotice =
        /(cuoc tro chuyen|cuoc hop|conversation|meeting)/.test(text) &&
        /(phan tich|analy[sz]|quyen truy cap|temporary access|nguoi to chuc|organizer)/.test(text);
      if (!isNotesPromotion && !isAnalysisNotice) return;

      var bounds = element.getBoundingClientRect();
      if (bounds.width < 180 || bounds.height < 24 || bounds.height > 260) return;

      element.dataset.hoclucGeminiHidden = 'true';
      element.style.setProperty('display', 'none', 'important');
      element.style.setProperty('visibility', 'hidden', 'important');
      element.style.setProperty('pointer-events', 'none', 'important');
    };

    var scanSubtree = function(root) {
      if (!root || root.nodeType !== 1) return;
      inspectElement(root);
      if (root.querySelectorAll) {
        root.querySelectorAll(
          'div, section, aside, footer, span, a, button, [role="note"]',
        ).forEach(
          inspectElement,
        );
      }
    };

    scanSubtree(document.body);

    var pendingNodes = new Set();
    var pendingSubtrees = new Set();
    var scanTimer = 0;
    var queueAncestors = function(node) {
      var element = node && node.nodeType === 1 ? node : node && node.parentElement;
      for (var depth = 0; element && element !== observeTarget && depth < 8; depth++) {
        pendingNodes.add(element);
        element = element.parentElement;
      }
    };
    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        if (mutation.type === 'characterData') {
          queueAncestors(mutation.target);
        } else {
          mutation.addedNodes.forEach(function(node) {
            if (node.nodeType === 1) {
              pendingSubtrees.add(node);
              queueAncestors(node);
            }
          });
          queueAncestors(mutation.target);
        }
      });

      if (!scanTimer && pendingNodes.size) {
        scanTimer = window.setTimeout(function() {
          scanTimer = 0;
          pendingNodes.forEach(inspectElement);
          pendingSubtrees.forEach(scanSubtree);
          pendingNodes.clear();
          pendingSubtrees.clear();
        }, 180);
      }
    });
    observer.observe(observeTarget, {
      childList: true,
      characterData: true,
      subtree: true,
    });
  }
  return true;
})();
''';
}
