/// Observes Google's real display streams; never supplies fake media or skips
/// the browser's source picker. Installed before Meet's scripts execute.
class MeetScreenShareScript {
  static const script = r'''
(function() {
  if (location.origin !== 'https://meet.google.com' || window !== window.top) return;
  var devices = navigator.mediaDevices;
  if (!devices || !devices.getDisplayMedia || window.HocLucScreenShare) return;
  // Keep Meet's presentation companion in the existing renderer/session.
  var companion = null;
  var panelVisible = false;
  function showPanel(visible) {
    panelVisible = !!visible;
    if (companion) companion.style.display = panelVisible ? 'block' : 'none';
  }
  var pip = window.documentPictureInPicture;
  if (pip) {
    try {
      Object.defineProperty(pip, 'requestWindow', { configurable: true, value: function() {
        if (!companion) {
          companion = document.createElement('iframe');
          companion.title = 'Google Meet — Chia sẻ';
          companion.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;border:0;background:#202124;z-index:2147483647';
          (document.body || document.documentElement).appendChild(companion);
          var child = companion.contentWindow;
          child.document.body.style.cssText = 'margin:0;width:100vw;height:100vh;overflow:auto';
          var frame = companion;
          var closed = false;
          child.close = function() {
            if (closed) return;
            closed = true;
            if (companion === frame) companion = null;
            child.dispatchEvent(new Event('pagehide'));
            frame.remove();
          };
        }
        showPanel(panelVisible);
        var event = new Event('enter');
        Object.defineProperty(event, 'window', { value: companion.contentWindow });
        var result = companion.contentWindow;
        return Promise.resolve(result).then(function() {
          pip.dispatchEvent(event);
          return result;
        });
      }});
      Object.defineProperty(pip, 'window', { configurable: true, get: function() {
        return companion ? companion.contentWindow : null;
      }});
    } catch (_) { /* Unsupported runtimes retain Google's native behavior. */ }
  }
  var streams = new Set();
  var generation = 0;
  function report() {
    streams.forEach(function(stream) {
      if (!stream.getVideoTracks().some(function(track) { return track.readyState === 'live'; })) streams.delete(stream);
    });
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(JSON.stringify({
        type: 'MEET_SCREEN_SHARE_STATE', url: location.href,
        payload: { active: streams.size > 0 }
      }));
    }
  }
  var original = devices.getDisplayMedia;
  devices.getDisplayMedia = function() {
    var requestGeneration = generation;
    // Call synchronously to preserve transient activation from the user's click.
    return original.apply(this, arguments).then(function(stream) {
      // Pause may happen while the source picker is still open.
      if (requestGeneration !== generation) {
        stream.getTracks().forEach(function(track) { track.stop(); });
        report();
        return stream;
      }
      streams.add(stream);
      stream.getTracks().forEach(function(track) {
        track.addEventListener('ended', report);
      });
      report();
      return stream;
    });
  };
  window.HocLucScreenShare = {
    showPanel: showPanel,
    stop: function() {
      generation++;
      streams.forEach(function(stream) {
        stream.getTracks().forEach(function(track) { track.stop(); });
      });
      streams.clear();
      report();
    }
  };
  // track.stop() does not emit ended; Meet may stop its own tracks directly.
  setInterval(report, 1000);
})();
''';
}
