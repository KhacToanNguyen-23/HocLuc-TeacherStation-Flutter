const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../../../lib/features/classroom_meet/services/meet_bridge_script.dart'), 'utf8').match(/r'''([\s\S]*?)'''/)[1];

// Same node:vm pattern as the screen-share harness. No network or real Meet.
function fixture({prepare = true} = {}) {
  let now = 1000, joined = true, inputPresent = true;
  const nodes = [], messages = [];
  let mutations;
  const node = (attrs = {}, text = '') => ({
    attrs, innerText: text, textContent: text, isConnected: true, getClientRects() { return [{}]; },
    getAttribute(k) { return this.attrs[k] ?? null; },
    closest(selector) {
      return selector.split(',').some(s => {
        const m = s.match(/\[([^\]=]+)(?:="([^"]*)")?\]/);
        return m && this.attrs[m[1]] != null && (m[2] == null || this.attrs[m[1]] === m[2]);
      }) ? this : null;
    },
    querySelector() { return null; },
  });
  const input = Object.assign(node(), {value: '', dispatchEvent() {}});
  let clicks = 0;
  const send = Object.assign(node(), {click() { clicks++; input.value = ''; }});
  const leave = node();
  const context = vm.createContext({
    document: {body: {innerText: ''},
      querySelector(s) {
        if (s.startsWith('button[aria-label*="rời khỏi"')) return joined ? leave : null;
        if (s.startsWith('textarea')) return inputPresent ? input : null;
        if (s.startsWith('button[aria-label*="gửi"')) return send;
        if (s.startsWith('button[aria-label*="trò chuyện"')) return {click() { inputPresent = true; }};
        return null;
      },
      querySelectorAll(s) { return s.startsWith('[data-message-text]') ? nodes : []; },
    },
    location: {href: 'https://meet.google.com/abc-defg-hij'},
    chrome: {webview: {postMessage(raw) { messages.push(JSON.parse(raw)); }}},
    MutationObserver: class { constructor(fn) { mutations = fn; } observe() {} },
    setInterval() {}, clearInterval() {}, setTimeout() { throw Error('Unexpected retry'); },
    Event: class {}, console,
    Date: class extends Date { static now() { return now; } },
  });
  context.window = context;
  vm.runInContext(script, context);
  const command = {requestId: 'tutor-1', documentId: messages[0].documentId, url: context.location.href, text: 'hello', timeoutMs: 1000, expiresAt: 2000};
  const call = (method, arg = command) => JSON.parse(context.MeetBridge[method](arg));
  function echo(self, id, text = 'hello', sender = 'You') {
    const n = node({'data-message-id': id, 'data-message-text': text, 'data-sender-name': sender, ...(self ? {'data-is-self': 'true'} : {})}, text);
    nodes.push(n); mutations(); return n;
  }
  if (prepare) assert.equal(call('beginTutorObservation').status, 'READY');
  return {context, input, send, nodes, messages, command, call, echo, mutations: () => mutations(), clicks: () => clicks++, count: () => clicks,
    leave: () => {joined = false;}, closeInput: () => {inputPresent = false;}, expire: () => {now += 1001;}};
}

test('requires a fresh self echo; student named You and historical self text cannot confirm', () => {
  const f = fixture(); f.echo(true, 'old');
  assert.equal(f.call('sendTutor').status, 'PENDING');
  f.echo(false, 'student');
  assert.equal(f.call('tutorStatus').status, 'PENDING');
  f.echo(true, 'new');
  assert.equal(f.call('tutorStatus').status, 'CONFIRMED');
  assert.equal(f.count(), 1);
  assert.equal(f.messages.filter(m => m.type === 'CHAT_MESSAGE').at(-1).payload.isSelf, true);
});

test('stable message IDs preserve repeated identical messages without rescanning duplicates', () => {
  const f = fixture(); f.echo(false, 'one'); f.echo(false, 'two'); f.mutations();
  const chats = f.messages.filter(m => m.type === 'CHAT_MESSAGE');
  assert.equal(chats.length, 2); assert.notEqual(chats[0].payload.id, chats[1].payload.id);
  assert.equal(chats[0].payload.isSelf, false);
});

test('occupied, disabled, readonly, absent inputs and disabled send never click or retry', () => {
  for (const setup of [f => f.input.value = 'teacher draft', f => f.input.disabled = true, f => f.input.readOnly = true, f => f.closeInput(), f => f.send.disabled = true]) {
    const f = fixture(); setup(f); assert.notEqual(f.call('sendTutor').status, 'CONFIRMED'); assert.equal(f.count(), 0);
  }
});

test('stale identity, changed room, left call and deadline fail closed', () => {
  const f = fixture(); assert.equal(f.call('sendTutor', {...f.command, documentId: 'old'}).status, 'NOT_READY');
  assert.equal(f.call('sendTutor').status, 'PENDING');
  assert.equal(f.call('sendTutor', {...f.command, requestId: 'two'}).status, 'BUSY');
  f.context.location.href += '?changed'; f.echo(true, 'new');
  assert.equal(f.call('tutorStatus').status, 'STALE');
  const g = fixture(); g.call('sendTutor'); g.leave(); assert.equal(g.call('tutorStatus').status, 'STALE');
  const h = fixture(); h.call('sendTutor'); h.expire(); h.echo(true, 'late'); assert.equal(h.call('tutorStatus').status, 'TIMEOUT');
});

test('contenteditable input and reinjection retain document identity', () => {
  const f = fixture(); f.input.isContentEditable = true; delete f.input.value;
  assert.equal(f.call('sendTutor').status, 'PENDING');
  assert.equal(f.input.textContent, 'hello');
  vm.runInContext(script, f.context); f.echo(true, 'fresh');
  assert.equal(f.call('tutorStatus').status, 'CONFIRMED');
});

test('expired command cannot send even when script execution arrives late', () => {
  const f = fixture(); f.expire(); assert.equal(f.call('sendTutor').status, 'NOT_READY'); assert.equal(f.count(), 0);
});

test('enable handshake baselines first visible chat; fallback IDs reject historical remount replay', () => {
  const f = fixture({prepare: false});
  f.echo(false, undefined, 'old question', 'Student');
  assert.equal(f.messages.filter(m => m.type === 'CHAT_MESSAGE').at(-1).payload.isTutorEligible, false);
  assert.equal(f.call('sendTutor').status, 'NOT_READY');
  assert.equal(f.call('beginTutorObservation').status, 'READY');
  f.echo(false, undefined, 'old question', 'Student');
  assert.equal(f.messages.filter(m => m.type === 'CHAT_MESSAGE').length, 1);
  f.echo(false, 'fresh', 'new question', 'Student');
  const candidate = f.messages.filter(m => m.type === 'CHAT_MESSAGE').at(-1);
  assert.equal(candidate.payload.isTutorEligible, true);
  assert.equal(candidate.payload.sourceDocumentId, f.command.documentId);
});

test('missing panel cannot prepare; cancelled send cannot confirm a late echo', () => {
  const f = fixture(); f.closeInput();
  assert.equal(f.call('beginTutorObservation').status, 'NOT_READY');
  assert.equal(f.call('sendTutor').status, 'NOT_READY');
  const g = fixture(); g.call('sendTutor'); g.call('cancelTutor'); g.echo(true, 'late');
  assert.equal(g.call('tutorStatus').status, 'CANCELLED');
});

test('cancelled same-text attempt cannot be confirmed by its late echo on retry', () => {
  const f = fixture(); f.call('sendTutor'); f.call('cancelTutor');
  assert.equal(f.call('sendTutor', {...f.command, requestId: 'retry'}).status, 'UNCONFIRMED');
  f.echo(true, 'late'); assert.equal(f.count(), 1);
  assert.equal(f.call('sendTutor', {...f.command, requestId: 'different', text: 'different'}).status, 'PENDING');
});

test('closed chat opens only for preparation; second explicit handshake baselines loaded history', () => {
  const f = fixture({prepare: false}); f.closeInput();
  assert.equal(f.call('beginTutorObservation').status, 'NOT_READY');
  f.echo(false, 'history', 'old');
  assert.equal(f.call('sendTutor').status, 'NOT_READY');
  assert.equal(f.call('beginTutorObservation').status, 'READY');
  assert.equal(f.messages.filter(m => m.type === 'CHAT_MESSAGE').at(-1).payload.isTutorEligible, false);
  assert.equal(f.count(), 0);
});

test('self echo seen before sending stays excluded after it remounts', () => {
  const f = fixture(); f.echo(true, 'old'); f.nodes.length = 0;
  assert.equal(f.call('sendTutor').status, 'PENDING');
  f.echo(true, 'old'); assert.equal(f.call('tutorStatus').status, 'PENDING');
});

test('timeout permits a different reply but never retries the uncertain text', () => {
  const f = fixture(); f.call('sendTutor'); f.expire();
  assert.equal(f.call('tutorStatus').status, 'TIMEOUT');
  const next = {...f.command, requestId: 'next', expiresAt: 4000};
  assert.equal(f.call('sendTutor', next).status, 'UNCONFIRMED');
  assert.equal(f.call('sendTutor', {...next, text: 'next answer'}).status, 'PENDING');
  assert.equal(f.count(), 2);
});

test('confirmed attempts remain complete after their original deadline', () => {
  const f = fixture(); f.call('sendTutor'); f.echo(true, 'sent');
  assert.equal(f.call('tutorStatus').status, 'CONFIRMED'); f.expire();
  assert.equal(f.call('tutorStatus').status, 'CONFIRMED');
  assert.equal(f.call('sendTutor', {...f.command, requestId: 'next', text: 'next', expiresAt: 4000}).status, 'PENDING');
});

test('failed preparation restores only the AI draft and future sends recover', () => {
  for (const editable of [false, true]) {
    const f = fixture(); f.input.isContentEditable = editable;
    f.send.disabled = true;
    assert.equal(f.call('sendTutor').status, 'NOT_READY');
    assert.equal(editable ? f.input.textContent : f.input.value, '');
    f.send.disabled = false;
    assert.equal(f.call('sendTutor', {...f.command, requestId: 'retry'}).status, 'PENDING');
  }
  const f = fixture(); f.send.disabled = true;
  f.input.dispatchEvent = () => { f.input.value = 'teacher changed draft'; };
  f.call('sendTutor'); assert.equal(f.input.value, 'teacher changed draft');
});
