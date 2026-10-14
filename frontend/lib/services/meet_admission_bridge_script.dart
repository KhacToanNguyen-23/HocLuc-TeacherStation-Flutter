/// Conservative DOM adapter. Unknown layouts and ambiguous identities fail
/// closed; live Google Meet DOM still requires acceptance on a real account.
class MeetAdmissionBridgeScript {
  static const String script = r'''
(function() {
  if (location.hostname !== 'meet.google.com' || !/^\/[a-z]{3}-[a-z]{4}-[a-z]{3}$/.test(location.pathname)) return;
  if (window.MeetAdmissionBridge && window.MeetAdmissionBridge.version === 1) {
    window.MeetAdmissionBridge.report();
    return;
  }
  var documentId = 'doc-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2);
  var sequence = 0, nextId = 0, lastQueue = '', scanTimer = null;
  var identities = new WeakMap(), attempts = new Map();

  function text(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
  function lower(value) { return text(value).toLocaleLowerCase(); }
  function visible(node) {
    if (!node || !node.isConnected || node.closest('[hidden], [aria-hidden="true"]')) return false;
    var style = getComputedStyle(node), rect = node.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  }
  function emit(type, payload) {
    if (window.chrome && window.chrome.webview) window.chrome.webview.postMessage(JSON.stringify({
      type: type, payload: payload, documentId: documentId, url: location.href, sequence: ++sequence
    }));
  }
  function label(button) { return text(button.getAttribute('aria-label') || button.innerText || button.textContent); }
  function admitButton(button) {
    if (!visible(button)) return false;
    var value = lower(label(button));
    return /^(admit|bring in|chấp nhận|cho vào)(\s|$)/.test(value) &&
      !/^(admit all|bring everyone|chấp nhận tất cả|cho vào tất cả)/.test(value);
  }
  function buttons(node) { return Array.from(node.querySelectorAll('button, [role="button"]')).filter(admitButton); }
  function namedLabel(button) {
    var value = label(button);
    var name = text(value.replace(/^(admit|bring in|chấp nhận|cho vào)\s+/i, ''));
    return name !== value && name.length > 0 ? name : '';
  }
  function contextFor(button) {
    var semantic = button.closest('[data-request-id], [data-participant-id], [role="listitem"], [role="row"]');
    if (semantic && buttons(semantic).length === 1 && identityFor(semantic, button)) return semantic;
    var node = button.parentElement;
    for (var depth = 0; node && node !== document.body && depth < 9; depth++, node = node.parentElement) {
      if (buttons(node).length !== 1) continue;
      var deny = Array.from(node.querySelectorAll('button, [role="button"]')).some(function(b) {
        return /^(deny|reject|don't admit|từ chối|không cho vào|không chấp nhận)(\s|$)/.test(lower(label(b)));
      });
      var pending = /wants to join|asking to join|waiting room|muốn tham gia|yêu cầu tham gia|xin vào|phòng chờ/i.test(node.innerText || '');
      if ((deny || pending || node.matches('[data-request-id], [data-participant-id], [role="listitem"]') || namedLabel(button)) && identityFor(node, button)) return node;
    }
    return null;
  }
  function identityFor(node, button) {
    var named = node.querySelector('[data-requester-name], [data-participant-name], [data-display-name]');
    var name = namedLabel(button);
    if (named) name = text(named.getAttribute('data-requester-name') || named.getAttribute('data-participant-name') || named.getAttribute('data-display-name') || named.textContent);
    var clone = node.cloneNode(true);
    clone.querySelectorAll('button, [role="button"]').forEach(function(b) { b.remove(); });
    var content = text(clone.textContent);
    var emailMatch = content.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/);
    if (!name) name = text(content.replace(/(wants to join|is asking to join|asking to join|muốn tham gia|yêu cầu tham gia|xin vào)(.*)$/i, '')
      .replace(/(waiting room|phòng chờ|đang chờ)/ig, '').replace(emailMatch ? emailMatch[0] : '', ''));
    if (!name || name.length > 160 || /^(admit|chấp nhận|cho vào)$/i.test(name)) return null;
    var googleId = node.getAttribute('data-participant-id') || '';
    var key = name + '\n' + (emailMatch ? emailMatch[0] : '') + '\n' + googleId + '\n' + (node.getAttribute('data-request-id') || '');
    var old = identities.get(node);
    if (!old || old.key !== key) {
      old = {key: key, id: documentId + '-request-' + (++nextId)};
      identities.set(node, old);
    }
    return {id: old.id, name: name, detail: emailMatch ? emailMatch[0] : '', googleId: googleId, node: node, button: button};
  }
  function collect() {
    var requests = [], nodes = new Set(), unknownCount = 0;
    Array.from(document.querySelectorAll('button, [role="button"]')).filter(admitButton).forEach(function(button) {
      var node = contextFor(button), request = node ? identityFor(node, button) : null;
      if (!request) { unknownCount++; return; }
      if (nodes.has(node)) return;
      nodes.add(node); requests.push(request);
    });
    return {requests: requests, unknownCount: unknownCount};
  }
  function joinedEvidence(request, duplicateName) {
    var result = new Set();
    Array.from(document.querySelectorAll('[data-participant-id]')).forEach(function(node) {
      if (!visible(node) || buttons(node).length || node.matches('[data-request-id]')) return;
      if (request.googleId && node.getAttribute('data-participant-id') === request.googleId) { result.add(node); return; }
      var named = node.querySelector('[data-participant-name], [data-display-name], [data-self-name]');
      var name = node.getAttribute('data-participant-name') || (named && (named.getAttribute('data-participant-name') || named.getAttribute('data-display-name') || named.getAttribute('data-self-name') || named.textContent));
      if (!duplicateName && lower(name) === lower(request.name)) result.add(node);
    });
    if (!duplicateName) Array.from(document.querySelectorAll('[role="status"], [role="alert"]')).forEach(function(node) {
      var value = text(node.innerText || node.textContent);
      var name = text(value.replace(/\s+(has joined(?: the (?:call|meeting))?|đã tham gia(?: cuộc (?:gọi|họp))?)[.!]?$/i, ''));
      if (visible(node) && name !== value && lower(name) === lower(request.name)) result.add(node);
    });
    return result;
  }
  function finish(attempt, status) {
    attempts.delete(attempt.request.id);
    clearTimeout(attempt.timer);
    emit('ADMISSION_RESULT', {attemptId: attempt.id, requestId: attempt.request.id, status: status});
  }
  function scan(force) {
    var queue = collect();
    attempts.forEach(function(attempt) {
      var stillPending = queue.requests.some(function(r) { return r.id === attempt.request.id; });
      var evidence = joinedEvidence(attempt.request, attempt.duplicateName);
      var newEvidence = Array.from(evidence).some(function(node) { return !attempt.baseline.has(node); });
      if (!stillPending && newEvidence) finish(attempt, 'CONFIRMED');
    });
    var payload = {requests: queue.requests.map(function(r) { return {id: r.id, name: r.name, detail: r.detail}; }), unknownCount: queue.unknownCount};
    var encoded = JSON.stringify(payload);
    if (force || encoded !== lastQueue) { lastQueue = encoded; emit('ADMISSION_QUEUE', payload); }
  }
  function schedule() {
    if (scanTimer !== null) return;
    scanTimer = setTimeout(function() { scanTimer = null; scan(false); }, 100);
  }
  window.MeetAdmissionBridge = {
    version: 1,
    report: function() { emit('ADMISSION_BRIDGE_READY', {version: 1}); scan(true); },
    admit: function(command) {
      if (!command || command.documentId !== documentId) return JSON.stringify({status: 'STALE_DOCUMENT'});
      if (attempts.has(command.requestId)) return JSON.stringify({status: 'ALREADY_PENDING'});
      var queue = collect(), request = queue.requests.find(function(r) { return r.id === command.requestId; });
      if (!request) { scan(true); return JSON.stringify({status: 'NOT_FOUND'}); }
      if (request.button.disabled || request.button.getAttribute('aria-disabled') === 'true') return JSON.stringify({status: 'NOT_CLICKABLE'});
      var duplicateName = queue.requests.filter(function(r) { return lower(r.name) === lower(request.name); }).length !== 1;
      var attempt = {id: command.attemptId, request: request, duplicateName: duplicateName, baseline: joinedEvidence(request, duplicateName)};
      attempt.timer = setTimeout(function() { scan(false); if (attempts.has(request.id)) finish(attempt, 'UNCONFIRMED'); }, 8000);
      attempts.set(request.id, attempt);
      try { request.button.click(); } catch (_) { finish(attempt, 'NOT_CLICKABLE'); }
      schedule();
      return JSON.stringify({status: 'PENDING'});
    }
  };
  new MutationObserver(schedule).observe(document.body, {childList: true, subtree: true, attributes: true, characterData: true});
  // DOM observers survive closing the Flutter panel: controller and page stay alive.
  var interval = setInterval(function() { scan(false); }, 1000);
  window.addEventListener('pagehide', function() {
    clearInterval(interval); clearTimeout(scanTimer);
    attempts.forEach(function(attempt) { finish(attempt, 'STALE_DOCUMENT'); });
  }, {once: true});
  window.MeetAdmissionBridge.report();
})();
''';
}
