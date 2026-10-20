// Exercises the injected script with media fixtures, without contacting Google.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../../lib/features/classroom_meet/services/meet_screen_share_script.dart'), 'utf8').match(/r'''([\s\S]*?)'''/)[1];

function fixture({ reject = false, deferred = false, origin = 'https://meet.google.com' } = {}) {
  const messages = [];
  const calls = [];
  const tracks = ['video', 'audio'].map(kind => ({
    kind, readyState: 'live', listeners: {},
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
    chrome: { webview: { postMessage(msg) { messages.push(JSON.parse(msg)); } } },
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
  assert.equal(f.messages.length, 0);
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
  assert.equal(await pending, f.stream);
  assert.equal(f.tracks.every(t => t.readyState === 'ended'), true);
  assert.equal(f.messages.some(m => m.payload.active), false);
});

test('installation is idempotent and restricted to the top-level Meet origin', () => {
  const f = fixture();
  const wrapped = f.devices.getDisplayMedia;
  vm.runInContext(script, f.context);
  assert.equal(f.devices.getDisplayMedia, wrapped);
  assert.equal(fixture({ origin: 'https://accounts.google.com' }).context.HocLucScreenShare, undefined);
});
