/// Observes Google's real display streams; never supplies fake media or skips
/// the browser's source picker. Installed before Meet's scripts execute.
class MeetScreenShareScript {
  static const script = r'''
(function() {
  if (location.origin !== 'https://meet.google.com' || window !== window.top) return;
  var devices = navigator.mediaDevices;
  if (!devices || !devices.getDisplayMedia || window.HocLucScreenShare) return;
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

