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
  var selecting = false;
  var guards = new Map();
  function report() {
    streams.forEach(function(stream) {
      if (!stream.getVideoTracks().some(function(track) { return track.readyState === 'live'; })) streams.delete(stream);
    });
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(JSON.stringify({
        type: 'MEET_SCREEN_SHARE_STATE', url: location.href,
        payload: { active: streams.size > 0, selecting: selecting, generation: generation,
          sources: Array.from(streams).flatMap(function(s) {
            return s.getVideoTracks().map(function(t) {
              var settings = t.getSettings ? t.getSettings() : {};
              return {label:t.label || '',surface:settings.displaySurface || ''};
            });
          }) }
      }));
    }
  }
  var original = devices.getDisplayMedia;
  devices.getDisplayMedia = function() {
    var requestGeneration = ++generation;
    selecting = true;
    var guard = new Promise(function(resolve) { guards.set(requestGeneration, resolve); });
    report();
    // Call synchronously to preserve transient activation from the user's click.
    var request;
    try { request = original.apply(this, arguments); }
    catch (error) { selecting=false; guards.delete(requestGeneration); report(); throw error; }
    return request.then(async function(stream) {
      // Do not hand Meet a single frame before the native notes guard has painted.
      var tracks=stream.getVideoTracks();
      var enabled=tracks.map(function(t) { var v=t.enabled; t.enabled=false; return v; });
      var timer;
      var allowed=await Promise.race([guard,new Promise(function(resolve) {
        timer=setTimeout(function() { resolve(false); },3000);
      })]);
      clearTimeout(timer);
      guards.delete(requestGeneration);
      // Pause may happen while the source picker is still open.
      if (!allowed || requestGeneration !== generation) {
        stream.getTracks().forEach(function(track) { track.stop(); });
        selecting=false;
        report();
        throw new DOMException('Privacy guard not ready','NotAllowedError');
      }
      tracks.forEach(function(t,i) { t.enabled=enabled[i]; });
      streams.add(stream);
      selecting=false;
      stream.getTracks().forEach(function(track) {
        track.addEventListener('ended', report);
      });
      report();
      return stream;
    }).catch(function(error) {
      guards.delete(requestGeneration);
      if (requestGeneration===generation) selecting=false;
      report();
      throw error;
    });
  };
  window.HocLucScreenShare = {
    confirmPrivacyGuard: function(value) {
      var resolve=guards.get(value);
      if (resolve) resolve(true);
    },
    stop: function() {
      generation++;
      selecting=false;
      guards.forEach(function(resolve) { resolve(false); });
      guards.clear();
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

