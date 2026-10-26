import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SDK observes, updates, and releases a registered DOM region', () async {
    final sdk = File('assets/scripts/hocluc-plugin-sdk.js').absolute;
    final result = await Process.run('node', [
      '-e',
      r'''
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[1], 'utf8');
const sent = [];
const raf = [];
const listeners = new Map();
let resizeObserver;
let mutationObserver;
let computedStyle = { display: 'block', visibility: 'visible', opacity: '1' };
let parentStyle = { display: 'block', visibility: 'visible', opacity: '1' };
const parent = {};

class ResizeObserverFake {
  constructor(callback) { this.callback = callback; this.disconnected = false; resizeObserver = this; }
  observe(target) { this.target = target; }
  disconnect() { this.disconnected = true; }
}
class MutationObserverFake {
  constructor(callback) { this.callback = callback; this.disconnected = false; this.observations = []; mutationObserver = this; }
  observe(target, options) { this.target = target; this.options = options; this.observations.push({ target, options }); }
  disconnect() { this.disconnected = true; }
}

const window = {
  __HocLucHostGeneration: 0,
  innerWidth: 1000,
  innerHeight: 700,
  chrome: { webview: {
    addEventListener() {},
    postMessage(raw) {
    const message = JSON.parse(raw);
    sent.push(message);
    window.__hocluc_handle_response({ id: message.id, success: true, data: { accepted: true } });
  } } },
  addEventListener(name, handler) { listeners.set(name, handler); },
  removeEventListener(name) { listeners.delete(name); },
  requestAnimationFrame(callback) { raf.push(callback); return raf.length; },
  cancelAnimationFrame() {},
  getComputedStyle(target) { return target === parent ? parentStyle : computedStyle; },
};
const document = { documentElement: { clientWidth: 1000, clientHeight: 700 }, body: {} };
vm.runInNewContext(source, {
  window,
  self: window,
  document,
  ResizeObserver: ResizeObserverFake,
  MutationObserver: MutationObserverFake,
  console,
  setTimeout,
  clearTimeout,
}, { filename: 'hocluc-plugin-sdk.js' });

function flushFrame() { const callback = raf.shift(); assert.ok(callback); callback(16); }
async function tick() { await Promise.resolve(); await Promise.resolve(); }

(async () => {
  const element = {
    isConnected: true,
    parentElement: parent,
    getBoundingClientRect() { return { x: 120, y: 90, width: 240, height: 120 }; },
  };
  const dispose = window.HocLuc.glass.registerRegion('result-card', element);
  flushFrame();
  await tick();
  assert.equal(sent.length, 0, 'registration waits for the host document generation');
  window.__HocLucHostGeneration = 42;
  window.HocLuc.glass.refreshRegions();
  flushFrame();
  await tick();
  assert.equal(sent[0].action, 'glass:register');
  assert.equal(sent[0].host_generation, 42);
  assert.equal(sent[0].payload.region_id, 'result-card');
  assert.equal(sent[0].payload.viewport.width, 1000);
  assert.equal(sent[0].payload.visible, true);
  assert.deepEqual(sent[0].payload.bounds, { x: 120, y: 90, width: 240, height: 120 });
  assert.equal(resizeObserver.target, element);
  assert.ok(mutationObserver.observations.some((item) =>
    item.target === parent && item.options.attributes && item.options.childList && item.options.subtree));

  element.getBoundingClientRect = () => ({ x: 130, y: 100, width: 260, height: 130 });
  resizeObserver.callback();
  flushFrame();
  await tick();
  assert.equal(sent[1].action, 'glass:update');
  assert.equal(sent[1].payload.bounds.width, 260);

  computedStyle = { display: 'none', visibility: 'visible', opacity: '1' };
  mutationObserver.callback();
  flushFrame();
  await tick();
  assert.equal(sent[2].action, 'glass:update');
  assert.equal(sent[2].payload.visible, false);

  computedStyle = { display: 'block', visibility: 'visible', opacity: '1' };
  mutationObserver.callback();
  flushFrame();
  await tick();
  assert.equal(sent[3].payload.visible, true);

  parentStyle = { display: 'block', visibility: 'visible', opacity: '0' };
  mutationObserver.callback();
  flushFrame();
  await tick();
  assert.equal(sent[4].action, 'glass:update');
  assert.equal(sent[4].payload.visible, false);
  parentStyle = { display: 'block', visibility: 'visible', opacity: '1' };
  mutationObserver.callback();
  flushFrame();
  await tick();
  assert.equal(sent[5].payload.visible, true);

  element.isConnected = false;
  mutationObserver.callback();
  flushFrame();
  await tick();
  assert.equal(sent[6].action, 'glass:unregister');
  assert.equal(resizeObserver.disconnected, true);
  assert.equal(mutationObserver.disconnected, true);
  assert.equal(listeners.has('scroll'), false);
  assert.equal(listeners.has('resize'), false);

  const replacement = { ...element, isConnected: true };
  const disposeReplacement = window.HocLuc.glass.registerRegion('result-card', replacement);
  flushFrame();
  await tick();
  assert.equal(sent[7].action, 'glass:register');
  await dispose();
  assert.equal(sent.length, 8, 'stale disposer must not unregister a replacement');
  await disposeReplacement();
  assert.equal(sent[8].action, 'glass:unregister');
})().catch((error) => { console.error(error); process.exitCode = 1; });
''',
      sdk.path,
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
  });
}
