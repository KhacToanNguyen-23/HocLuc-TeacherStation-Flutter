// Exercises the injected script with media fixtures, without contacting Google.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../../lib/features/classroom_meet/services/meet_screen_share_script.dart'), 'utf8').match(/r'''([\s\S]*?)'''/)[1];

function fixture({ reject = false, deferred = false, acknowledge = true, origin = 'https://meet.google.com' } = {}) {
  const messages = [];
  const calls = [];
  const tracks = ['video', 'audio'].map(kind => ({
    kind, readyState: 'live', enabled:true, label:kind==='video' ? 'HocLuc Audience session' : '', listeners: {},
    getSettings() { return {displaySurface:'window'}; },
    stop() { this.readyState = 'ended'; },
    addEventListener(event, fn) { this.listeners[event] = fn; },
  }));
  const stream = { getTracks: () => tracks, getVideoTracks: () => [tracks[0]] };
  let resolveCapture;
  const devices = { getDisplayMedia(options) {
    calls.push({ receiver: this, options });
    if (deferred) return new Promise(resolve => { resolveCapture = () => resolve(stream); });
    return reject ? Promise.reject(new Error('NotAllowedError')) : Promise.resolve(stream);
  } };
  let poll;
  const context = vm.createContext({
    location: { origin, href: `${origin}/abc-defg-hij` },
    navigator: { mediaDevices: devices },
    setInterval(fn) { poll = fn; },
    setTimeout(fn, ms) { return setTimeout(fn, Math.min(ms,50)); }, clearTimeout, DOMException,
    chrome: { webview: { postMessage(msg) {
      const message=JSON.parse(msg); messages.push(message);
      if (acknowledge && message.payload.selecting) queueMicrotask(()=>context.HocLucScreenShare.confirmPrivacyGuard(message.payload.generation));
    } } },
  });
  context.window = context;
  context.top = context;
  vm.runInContext(script, context);
  return { context, devices, stream, tracks, messages, calls, poll: () => poll(), resolveCapture: () => resolveCapture() };
}

test('forwards user capture synchronously with unchanged options and real stream', async () => {
  const f = fixture();
  const options = { video: true, audio: true };
  const pending = f.devices.getDisplayMedia(options);
  assert.equal(f.calls.length, 1);
  assert.equal(f.calls[0].receiver, f.devices);
  assert.equal(f.calls[0].options, options);
  assert.equal(f.messages[0].payload.selecting, true);
  assert.equal(await pending, f.stream);
  assert.equal(f.messages.at(-1).payload.active, true);
  assert.equal(f.messages.at(-1).url, 'https://meet.google.com/abc-defg-hij');
});

test('picker cancellation propagates and never reports sharing active', async () => {
  const f = fixture({ reject: true });
  await assert.rejects(f.devices.getDisplayMedia({ video: true }), /NotAllowedError/);
  f.poll();
  assert.equal(f.messages.some(m => m.payload.active), false);
});

test('browser stop and Meet track.stop both clear sharing status', async () => {
  for (const stopWithEvent of [true, false]) {
    const f = fixture();
    await f.devices.getDisplayMedia();
    f.tracks[0].stop();
    if (stopWithEvent) f.tracks[0].listeners.ended();
    else f.poll();
    assert.equal(f.messages.at(-1).payload.active, false);
  }
});

test('app stop ends display audio and video, without touching camera media', async () => {
  const f = fixture();
  await f.devices.getDisplayMedia();
  f.context.HocLucScreenShare.stop();
  assert.equal(f.tracks.every(t => t.readyState === 'ended'), true);
  assert.equal(f.messages.at(-1).payload.active, false);
});

test('a picker approved after pause cannot start a new broadcast', async () => {
  const f = fixture({ deferred: true });
  const pending = f.devices.getDisplayMedia();
  f.context.HocLucScreenShare.stop();
  f.resolveCapture();
  await assert.rejects(pending,/Privacy guard/);
  assert.equal(f.tracks.every(t => t.readyState === 'ended'), true);
  assert.equal(f.messages.some(m => m.payload.active), false);
});

test('withholds capture until native guard paints; timeout stops every real track', async()=>{
  const f=fixture({acknowledge:false});
  await assert.rejects(f.devices.getDisplayMedia(),/Privacy guard/);
  assert.equal(f.tracks.every(t=>t.readyState==='ended'),true);
  assert.equal(f.messages.some(m=>m.payload.active),false);
});

test('reports actual track surface and label, and invalidates on a new picker',async()=>{
  const f=fixture();
  await f.devices.getDisplayMedia();
  const source=f.messages.at(-1).payload.sources[0];
  assert.equal(source.surface,'window');
  assert.equal(source.label,'HocLuc Audience session');
  const next=f.devices.getDisplayMedia();
  assert.equal(f.messages.at(-1).payload.selecting,true);
  await next;
});

test('installation is idempotent and restricted to the top-level Meet origin', () => {
  const f = fixture();
  const wrapped = f.devices.getDisplayMedia;
  vm.runInContext(script, f.context);
  assert.equal(f.devices.getDisplayMedia, wrapped);
  assert.equal(fixture({ origin: 'https://accounts.google.com' }).context.HocLucScreenShare, undefined);
});
