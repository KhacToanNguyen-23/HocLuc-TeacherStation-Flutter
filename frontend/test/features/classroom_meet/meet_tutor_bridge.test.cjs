const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../../../lib/features/classroom_meet/services/meet_bridge_script.dart'), 'utf8').match(/r'''([\s\S]*?)'''/)[1];

// Same node:vm pattern as the screen-share harness. No network or real Meet.
function fixture({prepare = true, overflow = false, hiddenDirect = false, delayedMenu = false, delayedInput = false, chatLabel = 'In-call messages', menuLabel = 'More options', englishEditable = false, directExpanded = false, directPressed = false, menuExpanded = false, joinedInitially = true, hangupVisible = true, hangupConnected = true, hiddenHangupFirst = false, hangupStyle = {visibility: 'visible', display: 'block'}, bodyText = ''} = {}) {
  let now = 1000, joined = joinedInitially, inputPresent = true;
  const nodes = [], messages = [];
  let mutations;
  const intervals = [];
  let chatClicks = 0, peopleClicks = 0, menuClicks = 0, hiddenClicks = 0, menuOpen = menuExpanded && !delayedMenu;
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
  let input = Object.assign(node(), {value: '', dispatchEvent() {}});
  if (englishEditable) { input.isContentEditable = true; input.attrs['aria-label'] = 'Send a message'; }
  let clicks = 0;
  const send = Object.assign(node(), {click() { clicks++; input.value = ''; }});
  const leave = Object.assign(node({'aria-label': 'Leave call'}), {isConnected: hangupConnected, getClientRects() { return hangupVisible ? [{}] : []; }});
  const hiddenLeave = Object.assign(node({'aria-label': 'Leave call'}), {getClientRects() { return []; }});
  const chatButton = Object.assign(node({'aria-label': chatLabel, 'aria-expanded': String(directExpanded), 'aria-pressed': String(directPressed)}), {click() { chatClicks++; if (!delayedInput) inputPresent = !inputPresent; }});
  const hiddenChatButton = Object.assign(node({'aria-label': 'Chat with everyone'}), {getClientRects() { return []; }, click() { hiddenClicks++; }});
  const menuButton = Object.assign(node({'aria-label': menuLabel, 'aria-expanded': String(menuExpanded)}), {click() { menuClicks++; if (!delayedMenu) menuOpen = !menuOpen; }});
  const context = vm.createContext({
    document: {body: {innerText: bodyText},
      querySelector(s) {
        if (s.startsWith('button[aria-label*="rời khỏi"')) return joined ? leave : null;
        if (s.startsWith('textarea')) return inputPresent && (!englishEditable || s.includes('[contenteditable="true"][aria-label*="message" i]')) ? input : null;
        if (s.startsWith('button[aria-label*="gửi"')) return send;
        if (s.startsWith('button[aria-label*="trò chuyện"')) return hiddenDirect ? hiddenChatButton : overflow ? null : chatButton;
        if (s.startsWith('button[aria-label*="mọi người"')) return {click() { peopleClicks++; inputPresent = false; menuOpen = false; }};
        return null;
      },
      querySelectorAll(s) {
        if (s.startsWith('button[aria-label*="rời khỏi"')) return joined ? [...(hiddenHangupFirst ? [hiddenLeave] : []), leave] : [];
        if (s.startsWith('[data-message-text]')) return nodes;
        if (s.startsWith('button,')) return overflow ? [hiddenChatButton, menuButton, ...(menuOpen ? [chatButton] : [])] : [chatButton];
        return [];
      },
    },
    location: {href: 'https://meet.google.com/abc-defg-hij'},
    chrome: {webview: {postMessage(raw) { messages.push(JSON.parse(raw)); }}},
    MutationObserver: class { constructor(fn) { mutations = fn; } observe() {} },
    setInterval(fn) { intervals.push(fn); }, clearInterval() {}, setTimeout() { throw Error('Unexpected retry'); },
    Event: class {}, console,
    getComputedStyle() { return hangupStyle; },
    Date: class extends Date { static now() { return now; } },
  });
  context.window = context;
  vm.runInContext(script, context);
  const command = {requestId: 'tutor-1', observationId: 'legacy', documentId: messages[0].documentId, url: context.location.href, text: 'hello', timeoutMs: 1000, expiresAt: 2000};
  const call = (method, arg = command) => JSON.parse(context.MeetBridge[method](arg));
  function echo(self, id, text = 'hello', sender = 'You') {
    const n = node({'data-message-id': id, 'data-message-text': text, 'data-sender-name': sender, ...(self ? {'data-is-self': 'true'} : {})}, text);
    nodes.push(n); mutations(); return n;
  }
  function tick(ms = 300) { now += ms; intervals.forEach(fn => fn()); }
  function ready(arg = command) { call('beginTutorObservation', arg); tick(); assert.equal(call('beginTutorObservation', arg).status, 'READY'); }
  if (prepare) ready();
  return {context, input, send, nodes, messages, command, call, echo, ready, tick, chatClicks: () => chatClicks, peopleClicks: () => peopleClicks,
    panels: () => ({chatClicks, peopleClicks, menuClicks, hiddenClicks, menuOpen}), showMenu: () => {menuOpen = true;}, openInput: () => {inputPresent = true;},
    mutations: () => mutations(), clicks: () => clicks++, count: () => clicks,
    leave: () => {joined = false;}, remountInput: () => { input = Object.assign(node(), {value: 'teacher draft', dispatchEvent() {}}); inputPresent = true; }, closeInput: () => {inputPresent = false;}, expire: () => {now += 1001;}};
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
  f.ready();
  f.echo(false, undefined, 'old question', 'Student');
  assert.equal(f.messages.filter(m => m.type === 'CHAT_MESSAGE').length, 1);
  f.echo(false, 'fresh', 'new question', 'Student');
  const candidate = f.messages.filter(m => m.type === 'CHAT_MESSAGE').at(-1);
  assert.equal(candidate.payload.isTutorEligible, true);
  assert.equal(candidate.payload.sourceDocumentId, f.command.documentId);
});

test('missing panel cannot prepare; cancelled send cannot confirm a late echo', () => {
  const f = fixture(); f.closeInput();
  assert.equal(f.call('beginTutorObservation').status, 'PENDING');
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

test('closed chat automatically opens and baselines loaded history after stability', () => {
  const f = fixture({prepare: false}); f.closeInput();
  assert.equal(f.call('beginTutorObservation').status, 'PENDING');
  f.echo(false, 'history', 'old');
  assert.equal(f.call('sendTutor').status, 'NOT_READY');
  f.ready();
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


test('closed-chat lease polls remain pending until history is stable and never rebaseline READY', () => {
  const f = fixture({prepare: false}); f.closeInput();
  const lease = {...f.command, observationId: 'lease-a'};
  const pending = f.call('beginTutorObservation', lease);
  assert.equal(pending.status, 'PENDING');
  assert.equal(pending.observationId, 'lease-a');
  assert.equal(pending.documentId, lease.documentId);
  assert.equal(pending.url, lease.url);
  assert.equal(f.chatClicks(), 1);
  f.echo(false, 'history-a', 'old');
  f.tick(200);
  f.echo(false, 'history-b', 'also old');
  f.tick(200);
  assert.equal(f.call('beginTutorObservation', lease).status, 'PENDING');
  f.tick(60);
  assert.equal(f.call('beginTutorObservation', lease).status, 'READY');
  assert.ok(f.messages.filter(m => m.type === 'CHAT_MESSAGE').every(m => !m.payload.isTutorEligible));
  f.call('beginTutorObservation', lease);
  f.echo(false, 'live-a', 'new');
  assert.equal(f.messages.at(-1).payload.isTutorEligible, true);
  assert.equal(f.chatClicks(), 1);
  assert.equal(f.peopleClicks(), 0);
});

test('active lease opens once per recovery episode without toggling a slow chat shut', () => {
  const f = fixture();
  f.closeInput(); f.mutations();
  assert.equal(f.chatClicks(), 1);
  // Simulate a slow panel that remains absent after the first click.
  f.closeInput(); f.mutations(); f.mutations(); f.tick(100);
  assert.equal(f.chatClicks(), 1);
  assert.equal(f.peopleClicks(), 0);
  f.tick(1000);
  assert.equal(f.chatClicks(), 1);
  f.openInput(); f.mutations(); f.tick(260);
  // Only a later observed close starts another opening transition.
  f.closeInput(); f.mutations();
  assert.equal(f.chatClicks(), 2);
});

test('recovery emits correlated READY before deferred new rows, retaining IDs and no replay', () => {
  const f = fixture({prepare: false});
  const lease = {...f.command, observationId: 'recover'};
  f.ready(lease);
  const old = f.echo(false, 'old', 'already read');
  const oldId = f.messages.at(-1).payload.id;
  f.closeInput(); f.mutations();
  assert.equal(f.messages.at(-1).type, 'TUTOR_OBSERVATION_STATE');
  assert.equal(f.messages.at(-1).payload.ready, false);
  assert.equal(f.messages.at(-1).payload.observationId, 'recover');
  f.echo(false, 'during-loss', 'do not drop');
  // Even a row removed before recovery must be released after readiness.
  f.nodes.pop();
  f.remountInput(); f.mutations();
  f.tick(260);
  const chat = f.messages.filter(m => m.type === 'CHAT_MESSAGE');
  assert.equal(chat.length, 2);
  assert.equal(chat[0].payload.id, oldId);
  assert.equal(chat[1].payload.text, 'do not drop');
  assert.equal(chat[1].payload.isTutorEligible, true);
  const released = f.messages.findIndex(m => m.type === 'CHAT_MESSAGE' && m.payload.text === 'do not drop');
  assert.equal(f.messages[released - 1].type, 'TUTOR_OBSERVATION_STATE');
  assert.equal(f.messages[released - 1].payload.ready, true);
  f.nodes.length = 0; f.nodes.push(old); f.mutations();
  assert.equal(f.messages.filter(m => m.type === 'CHAT_MESSAGE').length, 2);
});

test('new lease baselines pending history and stale end cannot stop the current lease', () => {
  const f = fixture({prepare: false});
  const first = {...f.command, observationId: 'first'};
  const second = {...f.command, observationId: 'second'};
  f.ready(first);
  assert.equal(f.call('beginTutorObservation', second).status, 'PENDING');
  f.echo(false, 'between', 'history for new lease');
  assert.equal(f.messages.at(-1).payload.isTutorEligible, false);
  assert.equal(f.context.MeetBridge.endTutorObservation(first), false);
  f.tick(260);
  assert.equal(f.call('beginTutorObservation', second).status, 'READY');
  assert.equal(f.context.MeetBridge.endTutorObservation({...second, url: second.url + '?stale'}), false);
  assert.equal(f.context.MeetBridge.endTutorObservation({...second, documentId: 'stale'}), false);
  f.echo(false, 'new-second', 'eligible');
  assert.equal(f.messages.at(-1).payload.isTutorEligible, true);
  assert.equal(f.context.MeetBridge.endTutorObservation(second), true);
  const opens = f.chatClicks();
  f.closeInput(); f.tick(2000); f.mutations();
  assert.equal(f.chatClicks(), opens);
  f.echo(false, 'after-stop', 'inactive');
  assert.equal(f.messages.at(-1).payload.isTutorEligible, false);
  assert.equal(f.call('sendTutor').status, 'NOT_READY');
});


test('end before delayed begin tombstones the cancelled lease without stopping a newer lease', () => {
  const f = fixture({prepare: false});
  const cancelled = {...f.command, observationId: 'cancelled', expiresAt: 10000};
  f.closeInput();
  assert.equal(f.context.MeetBridge.endTutorObservation(cancelled), false);
  const before = f.messages.length;
  assert.equal(f.call('beginTutorObservation', cancelled).status, 'NOT_READY');
  assert.equal(f.messages.length, before);
  assert.equal(f.chatClicks(), 0);
  const newer = {...cancelled, observationId: 'newer'};
  f.call('beginTutorObservation', newer); f.mutations(); f.tick(260);
  assert.equal(f.call('beginTutorObservation', newer).status, 'READY');
  assert.equal(f.context.MeetBridge.endTutorObservation(cancelled), false);
  assert.equal(f.call('beginTutorObservation', cancelled).status, 'NOT_READY');
  f.echo(false, 'still-active', 'new lease still active');
  assert.equal(f.messages.at(-1).payload.isTutorEligible, true);
});

test('expired or invalid begin deadlines cause no opening or lease changes', () => {
  const f = fixture({prepare: false}); f.closeInput();
  for (const expiresAt of [1000, 999, null, '5000', Infinity, NaN]) {
    const before = f.messages.length;
    assert.equal(f.call('beginTutorObservation', {...f.command, observationId: 'expired', expiresAt}).status, 'NOT_READY');
    assert.equal(f.messages.length, before);
    assert.equal(f.chatClicks(), 0);
  }
  const live = {...f.command, observationId: 'live', expiresAt: 10000};
  f.call('beginTutorObservation', live); f.mutations(); f.tick(260);
  assert.equal(f.call('beginTutorObservation', live).status, 'READY');
  assert.equal(f.call('beginTutorObservation', {...live, observationId: 'expired', expiresAt: 1000}).status, 'NOT_READY');
  f.echo(false, 'live-row', 'still eligible');
  assert.equal(f.messages.at(-1).payload.isTutorEligible, true);
  // Bounded tombstones may evict the oldest ID, but its expired command stays rejected.
  f.context.MeetBridge.endTutorObservation({...live, observationId: 'old'});
  for (let i = 0; i < 300; i++) f.context.MeetBridge.endTutorObservation({...live, observationId: `stop-${i}`});
  assert.equal(f.call('beginTutorObservation', {...live, observationId: 'old', expiresAt: 1000}).status, 'NOT_READY');
  assert.equal(f.call('beginTutorObservation', live).status, 'READY');
});


test('delayed send from an ended lease cannot execute after re-enable', () => {
  const f = fixture();
  f.context.MeetBridge.endTutorObservation(f.command);
  const next = {...f.command, observationId: 'next', requestId: 'next-send', expiresAt: 10000};
  f.ready(next);
  assert.equal(f.call('sendTutor', {...f.command, expiresAt: 10000}).status, 'NOT_READY');
  assert.equal(f.call('sendTutor', {...next, observationId: undefined}).status, 'NOT_READY');
  assert.equal(f.count(), 0);
  assert.equal(f.call('sendTutor', next).status, 'PENDING');
  assert.equal(f.count(), 1);
});

test('fresh toggle tags every chat row with its lease and never replays old history', () => {
  const f = fixture({prepare: false});
  const chats = () => f.messages.filter(m => m.type === 'CHAT_MESSAGE');
  f.echo(false, 'before-toggle', 'historical');
  assert.equal(chats().at(-1).payload.observationId, null);
  const first = {...f.command, observationId: 'toggle-one', expiresAt: 10000};
  f.ready(first);
  f.echo(false, 'first-live', 'first question');
  assert.equal(chats().at(-1).payload.observationId, 'toggle-one');
  assert.equal(chats().at(-1).payload.isTutorEligible, true);
  f.context.MeetBridge.endTutorObservation(first);
  const second = {...first, observationId: 'toggle-two'};
  assert.equal(f.call('beginTutorObservation', second).status, 'PENDING');
  f.echo(false, 'second-baseline', 'loaded during baseline');
  assert.equal(chats().at(-1).payload.observationId, 'toggle-two');
  assert.equal(chats().at(-1).payload.isTutorEligible, false);
  f.tick(260);
  assert.equal(f.call('beginTutorObservation', second).status, 'READY');
  const count = chats().length;
  f.echo(false, 'before-toggle', 'historical');
  f.echo(false, 'first-live', 'first question');
  f.echo(false, 'second-baseline', 'loaded during baseline');
  assert.equal(chats().length, count);
  f.echo(false, 'second-live', 'new question');
  assert.equal(chats().length, count + 1);
  assert.equal(chats().at(-1).payload.observationId, 'toggle-two');
  assert.equal(chats().at(-1).payload.isTutorEligible, true);
});

test('periodic participant scans never close the teacher overflow menu while AI is off', () => {
  const f = fixture({prepare: false});
  f.showMenu(); f.tick(2000); f.tick(2000);
  assert.equal(f.peopleClicks(), 0);
  assert.equal(f.panels().menuOpen, true);
  assert.equal(f.chatClicks(), 0);
});

test('English and Vietnamese overflow chat actions remain usable behind a hidden direct button', () => {
  for (const chatLabel of ['In-call messages', 'Tin nhắn trong cuộc gọi']) {
    const menuLabel = chatLabel === 'In-call messages' ? 'More options' : 'Tùy chọn khác';
    const f = fixture({prepare: false, overflow: true, hiddenDirect: true, chatLabel, menuLabel}); f.closeInput();
    const lease = {...f.command, observationId: 'overflow', expiresAt: 10000};
    assert.equal(f.call('beginTutorObservation', lease).status, 'PENDING');
    f.mutations(); f.mutations(); f.tick(300);
    assert.equal(f.call('beginTutorObservation', lease).status, 'READY');
    assert.equal(f.panels().menuClicks, 1);
    assert.equal(f.panels().hiddenClicks, 0);
    assert.equal(f.chatClicks(), 1);
    assert.equal(f.peopleClicks(), 0);
  }
});

test('delayed overflow and chat input never toggle an already requested panel shut', () => {
  const f = fixture({prepare: false, overflow: true, delayedMenu: true, delayedInput: true}); f.closeInput();
  const lease = {...f.command, observationId: 'slow-open', expiresAt: 10000};
  f.call('beginTutorObservation', lease);
  f.tick(1200); f.tick(1200);
  assert.equal(f.panels().menuClicks, 1);
  f.showMenu(); f.mutations();
  assert.equal(f.chatClicks(), 1);
  f.tick(1200); f.tick(1200);
  assert.equal(f.chatClicks(), 1);
  f.openInput(); f.mutations(); f.tick(300);
  assert.equal(f.call('beginTutorObservation', lease).status, 'READY');
});

test('pause stops delayed overflow opening and a fresh lease can recover', () => {
  const f = fixture({prepare: false, overflow: true, delayedMenu: true}); f.closeInput();
  const ended = {...f.command, observationId: 'ended', expiresAt: 10000};
  f.call('beginTutorObservation', ended);
  assert.equal(f.panels().menuClicks, 1);
  assert.equal(f.context.MeetBridge.endTutorObservation(ended), true);
  f.showMenu(); f.tick(1500); f.mutations();
  assert.equal(f.chatClicks(), 0);
  assert.equal(f.call('beginTutorObservation', ended).status, 'NOT_READY');
  const next = {...ended, observationId: 're-enabled'};
  f.call('beginTutorObservation', next); f.mutations(); f.tick(300);
  assert.equal(f.call('beginTutorObservation', next).status, 'READY');
  assert.equal(f.chatClicks(), 1);
  f.echo(false, 'after-re-enable', 'new question');
  assert.equal(f.messages.at(-1).payload.observationId, 're-enabled');
  assert.equal(f.messages.at(-1).payload.isTutorEligible, true);
});

test('English contenteditable chat retains teacher draft protection and sends only from an empty input', () => {
  const f = fixture({englishEditable: true});
  f.input.textContent = 'teacher draft';
  assert.equal(f.call('sendTutor').status, 'INPUT_BUSY');
  assert.equal(f.input.textContent, 'teacher draft');
  assert.equal(f.count(), 0);
  f.input.textContent = '';
  assert.equal(f.call('sendTutor').status, 'PENDING');
  assert.equal(f.count(), 1);
});

test('overflow opener does not click unrelated chat settings actions', () => {
  const f = fixture({prepare: false, overflow: true, hiddenDirect: true, chatLabel: 'Chat settings'}); f.closeInput();
  const lease = {...f.command, observationId: 'unrelated-action', expiresAt: 10000};
  f.call('beginTutorObservation', lease); f.mutations(); f.tick(1200);
  assert.equal(f.call('beginTutorObservation', lease).status, 'PENDING');
  assert.equal(f.panels().menuClicks, 1);
  assert.equal(f.chatClicks(), 0);
  assert.equal(f.panels().hiddenClicks, 0);
});

test('already expanded or pressed chat waits for its delayed composer without clicking it closed', () => {
  for (const state of [{directExpanded: true}, {directPressed: true}]) {
    const f = fixture({prepare: false, delayedInput: true, ...state}); f.closeInput();
    const lease = {...f.command, observationId: 'already-open', expiresAt: 10000};
    f.call('beginTutorObservation', lease); f.tick(1500); f.mutations();
    assert.equal(f.chatClicks(), 0);
    f.openInput(); f.mutations(); f.tick(300);
    assert.equal(f.call('beginTutorObservation', lease).status, 'READY');
    assert.equal(f.chatClicks(), 0);
  }
});

test('already expanded teacher overflow menu is not clicked shut while items load', () => {
  const f = fixture({prepare: false, overflow: true, menuExpanded: true, delayedMenu: true}); f.closeInput();
  const lease = {...f.command, observationId: 'teacher-menu', expiresAt: 10000};
  f.call('beginTutorObservation', lease); f.tick(1500); f.mutations();
  assert.equal(f.panels().menuClicks, 0);
  assert.equal(f.chatClicks(), 0);
  f.showMenu(); f.mutations(); f.mutations(); f.tick(300);
  assert.equal(f.call('beginTutorObservation', lease).status, 'READY');
  assert.equal(f.panels().menuClicks, 0);
  assert.equal(f.chatClicks(), 1);
});

test('a visible close-chat or chat-settings button is never treated as an opener', () => {
  for (const chatLabel of ['Close chat', 'Chat settings']) {
    const f = fixture({prepare: false, chatLabel}); f.closeInput();
    f.call('beginTutorObservation'); f.mutations(); f.tick(300);
    assert.equal(f.chatClicks(), 0);
  }
});

test('initial bridge installation reports READY before an already joined call without clicks', () => {
  const f = fixture({prepare: false});
  assert.deepEqual(f.messages.map(m => m.type), ['MEET_BRIDGE_READY', 'MEET_JOINED']);
  assert.equal(f.messages[0].documentId, f.messages[1].documentId);
  assert.equal(f.chatClicks(), 0);
  assert.equal(f.panels().menuClicks, 0);
  assert.equal(f.peopleClicks(), 0);
});

test('retained bridge reinjection resyncs READY then Joined with stable identity and current lease', () => {
  const f = fixture();
  const before = f.messages.length;
  vm.runInContext(script, f.context);
  const resync = f.messages.slice(before);
  assert.deepEqual(resync.map(m => m.type), ['MEET_BRIDGE_READY', 'MEET_JOINED']);
  assert.ok(resync.every(m => m.documentId === f.command.documentId && m.url === f.command.url));
  assert.equal(f.call('beginTutorObservation').status, 'READY');
  f.echo(false, 'after-resync', 'new question');
  assert.equal(f.messages.at(-1).payload.observationId, f.command.observationId);
  assert.equal(f.messages.at(-1).payload.isTutorEligible, true);
  assert.equal(f.chatClicks(), 0);
  assert.equal(f.panels().menuClicks, 0);
});

test('unrelated waiting text cannot veto a visible connected hangup control', () => {
  for (const bodyText of ['Student: asking to join means what?', 'Chat: wait until the host replies.', 'vui lòng đợi cho đến khi người tổ chức']) {
    const f = fixture({prepare: false, bodyText, hiddenHangupFirst: true});
    assert.equal(f.messages.at(-1).type, 'MEET_JOINED');
    f.ready();
    assert.equal(f.call('beginTutorObservation').status, 'READY');
  }
});

test('prejoin without a genuine hangup does not report Joined or enable observation', () => {
  const f = fixture({prepare: false, joinedInitially: false, bodyText: 'Asking to join. Wait until the host lets you in.'});
  assert.deepEqual(f.messages.map(m => m.type), ['MEET_BRIDGE_READY']);
  assert.equal(f.context.MeetBridge.attemptAutoJoin(), false);
  assert.equal(f.call('beginTutorObservation').status, 'NOT_READY');
  f.context.MeetBridge.reportCallState();
  assert.equal(f.messages.some(m => m.type === 'MEET_JOINED'), false);
});

test('hidden or detached hangup controls are not evidence that the teacher joined', () => {
  for (const state of [{hangupVisible: false}, {hangupConnected: false}, {hangupStyle: {visibility: 'hidden', display: 'block'}}, {hangupStyle: {visibility: 'visible', display: 'none'}}]) {
    const f = fixture({prepare: false, ...state});
    assert.deepEqual(f.messages.map(m => m.type), ['MEET_BRIDGE_READY']);
    assert.equal(f.call('beginTutorObservation').status, 'NOT_READY');
    f.context.MeetBridge.reportCallState();
    assert.equal(f.messages.some(m => m.type === 'MEET_JOINED'), false);
  }
});
