// Synthetic DOM fixtures, not proof against live Google Meet. No Google traffic
// is sent: every fixture page is fulfilled locally by Playwright's route.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
function dartRaw(file) {
  return fs.readFileSync(path.join(__dirname, '..', 'lib', 'services', file), 'utf8').match(/r'''([\s\S]*?)'''/)[1];
}
const admission = dartRaw('meet_admission_bridge_script.dart');
const legacy = dartRaw('meet_bridge_script.dart');
const results = [];
function row(id, name, email = '') {
  return `<section role="listitem" data-participant-id="${id}" data-request-id="knock-${id}"><span data-requester-name="${name}">${name}</span><span>${email}</span><button>Admit</button><button>Deny</button></section>`;
}
async function queue(page) {
  return page.evaluate(() => window.__messages.filter(m => m.type === 'ADMISSION_QUEUE').at(-1).payload);
}
async function action(page, id, attemptId = 'attempt-1', documentId) {
  return page.evaluate(({id, attemptId, documentId}) => JSON.parse(window.MeetAdmissionBridge.admit({
    requestId: id, attemptId,
    documentId: documentId || window.__messages.find(m => m.type === 'ADMISSION_BRIDGE_READY').documentId,
  })), {id, attemptId, documentId});
}
async function installClick(page, id, evidence = true) {
  await page.evaluate(({id, evidence}) => {
    const node = document.querySelector(`[data-participant-id="${id}"]`);
    node.querySelector('button').onclick = () => {
      window.__clicks.push(id);
      const name = node.querySelector('[data-requester-name]').textContent;
      node.remove();
      if (evidence) {
        const joined = document.createElement('div');
        joined.setAttribute('data-participant-id', id);
        const label = document.createElement('span');
        label.setAttribute('data-participant-name', name);
        label.textContent = name;
        joined.append(label); document.body.append(joined);
      }
    };
  }, {id, evidence});
}
async function run(browser, name, body, test, full = false) {
  const page = await browser.newPage();
  await page.clock.install();
  await page.addInitScript(() => {
    window.__messages = []; window.__clicks = [];
    window.chrome = window.chrome || {};
    window.chrome.webview = {postMessage: raw => window.__messages.push(JSON.parse(raw))};
    window.__meetManualJoin = true;
  });
  await page.route('https://meet.google.com/**', route => route.fulfill({contentType:'text/html', body:
    `<html><head><meta charset="utf-8"><style>section{padding:12px}button{margin:4px;padding:8px}span{padding:4px}</style></head><body>${body}</body></html>`}));
  await page.goto('https://meet.google.com/abc-defg-hij');
  await page.evaluate(admission + (full ? legacy : ''));
  try { await test(page); results.push(name); } finally { await page.close(); }
}
(async () => {
  const browser = await chromium.launch({channel:'msedge', headless:true});
  try {
    await run(browser, 'in-call requests wait for teacher; explicit snapshot admits both with evidence', '<button aria-label="Leave call">Leave call</button><button id="permission">Allow</button>' + row('a','Alice') + row('b','Bob'), async page => {
      await installClick(page, 'a');
      await installClick(page, 'b');
      await page.evaluate(() => document.querySelector('#permission').onclick = () => window.__clicks.push('permission'));
      await page.clock.fastForward(2000);
      assert.deepEqual(await page.evaluate(() => window.__clicks), []);
      const pending = await queue(page);
      assert.equal(pending.requests.length, 2);
      for (const [i, request] of pending.requests.entries()) {
        assert.equal((await action(page, request.id, 'batch-' + i)).status, 'PENDING');
        await page.clock.fastForward(200);
      }
      assert.deepEqual(await page.evaluate(() => window.__clicks), ['a','b']);
      assert.equal(await page.evaluate(() => window.__messages.filter(m => m.type === 'ADMISSION_RESULT' && m.payload.status === 'CONFIRMED').length), 2);
      assert.equal((await queue(page)).requests.length, 0);
    }, true);
    await run(browser, 'exact selected row and positive join evidence', row('a','Alice') + row('b','Bob'), async page => {
      const pending = await queue(page);
      assert.deepEqual(pending.requests.map(r=>r.name), ['Alice','Bob']);
      await installClick(page, 'a');
      assert.equal((await action(page, pending.requests[0].id)).status, 'PENDING');
      await page.clock.fastForward(200);
      assert.deepEqual(await page.evaluate(()=>window.__clicks), ['a']);
      assert.equal(await page.evaluate(()=>window.__messages.find(m=>m.type==='ADMISSION_RESULT').payload.status), 'CONFIRMED');
      assert.deepEqual((await queue(page)).requests.map(r=>r.name), ['Bob']);
    });
    await run(browser, 'disappearance alone remains unconfirmed', row('a','Alice'), async page => {
      const pending = await queue(page);
      await installClick(page, 'a', false);
      await action(page, pending.requests[0].id);
      await page.clock.fastForward(9000);
      const statuses = await page.evaluate(()=>window.__messages.filter(m=>m.type==='ADMISSION_RESULT').map(m=>m.payload.status));
      assert.deepEqual(statuses, ['UNCONFIRMED']);
    });
    await run(browser, 'recycled DOM row cannot admit a different student', row('a','Alice'), async page => {
      const old = (await queue(page)).requests[0].id;
      await page.evaluate(() => {
        const named = document.querySelector('[data-requester-name]');
        named.setAttribute('data-requester-name','Bob'); named.textContent='Bob';
        document.querySelector('button').onclick=()=>window.__clicks.push('wrong-person');
        window.MeetAdmissionBridge.report();
      });
      assert.equal((await action(page, old)).status, 'NOT_FOUND');
      assert.deepEqual(await page.evaluate(()=>window.__clicks), []);
      assert.equal((await queue(page)).requests[0].name, 'Bob');
    });
    await run(browser, 'same-name recycled request ID is never rebound silently', row('a','Minh'), async page => {
      const old = (await queue(page)).requests[0].id;
      await page.evaluate(() => {
        document.querySelector('section').setAttribute('data-request-id','new-knock-same-name');
        document.querySelector('button').onclick=()=>window.__clicks.push('wrong-request');
        window.MeetAdmissionBridge.report();
      });
      assert.equal((await action(page,old)).status,'NOT_FOUND');
      assert.deepEqual(await page.evaluate(()=>window.__clicks),[]);
    });
    await run(browser, 'duplicate names select the exact ID and confirm by participant ID', row('a','Minh','a@example.com') + row('b','Minh','b@example.com'), async page => {
      const pending = await queue(page);
      assert.notEqual(pending.requests[0].id, pending.requests[1].id);
      await installClick(page, 'b');
      await action(page, pending.requests[1].id);
      await page.clock.fastForward(200);
      assert.deepEqual(await page.evaluate(()=>window.__clicks), ['b']);
      assert.equal(await page.evaluate(()=>window.__messages.find(m=>m.type==='ADMISSION_RESULT').payload.status), 'CONFIRMED');
    });
    await run(browser, 'Vietnamese dialog with nested controls and joined status', '<section role="dialog"><h2>Lê Văn C muốn tham gia cuộc họp</h2><div><button>Chấp nhận</button><button>Từ chối</button></div></section><button>Admit all</button><button style="display:none">Admit Hidden</button>', async page => {
      const pending = await queue(page);
      assert.equal(pending.requests.length, 1);
      assert.equal(pending.requests[0].name, 'Lê Văn C');
      await page.evaluate(() => {
        document.querySelector('section button').onclick=()=>{
          window.__clicks.push('C'); document.querySelector('section').remove();
          const status=document.createElement('div'); status.setAttribute('role','status'); status.textContent='Lê Văn C đã tham gia cuộc họp'; document.body.append(status);
        };
      });
      await action(page, pending.requests[0].id);
      await page.clock.fastForward(200);
      assert.equal(await page.evaluate(()=>window.__messages.find(m=>m.type==='ADMISSION_RESULT').payload.status), 'CONFIRMED');
    });
    await run(browser, 'unknown names fail closed and legacy admit-all cannot click', '<section role="dialog"><button>Admit</button><button>Deny</button></section>', async page => {
      assert.equal((await queue(page)).requests.length, 0);
      assert.equal((await queue(page)).unknownCount, 1);
      assert.equal(await page.evaluate(()=>window.MeetBridge.admitAll()), false);
      assert.equal((await action(page, 'nonexistent')).status, 'NOT_FOUND');
    }, true);
    await run(browser, 'disabled controls and stale document do not click', row('a','Alice'), async page => {
      const pending = await queue(page);
      assert.equal((await action(page, pending.requests[0].id, 'attempt-old', 'other-document')).status, 'STALE_DOCUMENT');
      await page.evaluate(()=>document.querySelector('button').disabled=true);
      assert.equal((await action(page, pending.requests[0].id)).status, 'NOT_CLICKABLE');
      assert.deepEqual(await page.evaluate(()=>window.__clicks), []);
    });
    await run(browser, 'duplicate commands and old participant evidence cannot confirm', row('a','Alice') + '<div data-participant-id="already-here"><span data-participant-name="Alice">Alice</span></div>', async page => {
      const pending = await queue(page);
      await installClick(page,'a',false);
      await action(page,pending.requests[0].id);
      // The first click removed the request; no unrelated old participant is proof.
      await page.clock.fastForward(9000);
      assert.equal(await page.evaluate(()=>window.__messages.find(m=>m.type==='ADMISSION_RESULT').payload.status), 'UNCONFIRMED');
    });
    await run(browser, 'double taps click once and zero queue is emitted', row('a','Alice'), async page => {
      const pending = await queue(page);
      await page.evaluate(()=>document.querySelector('button').onclick=()=>window.__clicks.push('once'));
      assert.equal((await action(page,pending.requests[0].id)).status,'PENDING');
      assert.equal((await action(page,pending.requests[0].id,'attempt-second')).status,'ALREADY_PENDING');
      assert.deepEqual(await page.evaluate(()=>window.__clicks),['once']);
      await page.evaluate(()=>{document.querySelector('section').remove();window.MeetAdmissionBridge.report();});
      assert.equal((await queue(page)).requests.length,0);
      assert.equal((await queue(page)).unknownCount,0);
    });
    await run(browser, 'account evidence uses Google account control, not roster or chat', '<button aria-label="Google Account: Teacher (teacher@example.com)">Account</button><section data-email="student@example.com">student@example.com</section>', async page => {
      await page.evaluate(() => window.MeetBridge.reportCallState());
      assert.equal(await page.evaluate(() => window.__messages.filter(m => m.type === 'MEET_ACCOUNT').at(-1).payload.email), 'teacher@example.com');
      await page.evaluate(() => document.querySelector('button').remove());
      await page.evaluate(() => window.MeetBridge.reportCallState());
      assert.equal(await page.evaluate(() => window.__messages.filter(m => m.type === 'MEET_ACCOUNT').at(-1).payload.email), null);
    }, true);
    await run(browser, 'ambiguous account controls remain unknown', '<button aria-label="Tài khoản Google: teacher@example.com">A</button><button aria-label="Google Account: other@example.com">B</button>', async page => {
      await page.evaluate(() => window.MeetBridge.reportCallState());
      assert.equal(await page.evaluate(() => window.__messages.filter(m => m.type === 'MEET_ACCOUNT').at(-1).payload.email), null);
    }, true);
    await run(browser, 'bridge does not reopen People while teacher is using Chat', '<button aria-label="Leave call">Leave</button><button aria-label="People">People</button><textarea name="chatTextInput"></textarea>', async page => {
      await page.evaluate(() => document.querySelector('[aria-label="People"]').onclick = () => window.__clicks.push('people'));
      await page.clock.fastForward(5000);
      assert.deepEqual(await page.evaluate(() => window.__clicks), []);
    }, true);
    await run(browser, 'visible empty roster clears snapshot, hidden panel stays unknown', '<button aria-label="Leave call">Leave</button><section role="tabpanel" aria-label="People"><div data-participant-id="student-1">Alice</div><div data-participant-id="self">Bạn</div></section>', async page => {
      await page.clock.fastForward(1000);
      assert.equal(await page.evaluate(() => window.__messages.filter(m => m.type === 'PARTICIPANTS_UPDATE').at(-1).payload[0].id), 'student-1');
      await page.evaluate(() => document.querySelector('[data-participant-id]').remove());
      await page.clock.fastForward(1000);
      assert.deepEqual(await page.evaluate(() => window.__messages.filter(m => m.type === 'PARTICIPANTS_UPDATE').at(-1).payload), []);
      await page.evaluate(() => document.querySelector('[role="tabpanel"]').style.display = 'none');
      await page.clock.fastForward(1000);
      assert.equal(await page.evaluate(() => window.__messages.filter(m => m.type === 'PARTICIPANTS_STATE').at(-1).payload.available), false);
    }, true);
    await run(browser, 'missing Chat input returns failure without opening another panel', '<button aria-label="Chat">Chat</button>', async page => {
      await page.evaluate(() => document.querySelector('button').onclick = () => window.__clicks.push('chat'));
      assert.equal(await page.evaluate(() => window.MeetBridge.sendChat('hello')), false);
      await page.clock.fastForward(2000);
      assert.deepEqual(await page.evaluate(() => window.__clicks), []);
    }, true);
    console.log(JSON.stringify({passed:results.length,fixtures:results,liveGoogleValidated:false},null,2));
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
