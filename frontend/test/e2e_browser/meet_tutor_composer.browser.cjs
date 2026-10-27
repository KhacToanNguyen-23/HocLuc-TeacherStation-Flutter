// Real Edge DOM fixtures based on the observed Meet composer. All requests are
// fulfilled locally; these checks never send chat to a Google meeting.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');
const script = fs.readFileSync(path.join(__dirname, '../../lib/features/classroom_meet/services/meet_bridge_script.dart'), 'utf8').match(/r'''([\s\S]*?)'''/)[1];

function html({placeholderOnly = false, hiddenLegacy = true, english = false, disabled = false, ariaDisabled = false, unrelated = false} = {}) {
  return `<html><head><meta charset="utf-8"></head><body>
    <button aria-label="Rời khỏi cuộc gọi">Leave</button>
    <button aria-label="Cho phép người tham gia gửi tin nhắn" onclick="window.traps++">Setting</button>
    <button aria-label="Gửi biểu tượng cảm xúc" onclick="window.traps++">Emoji</button>
    ${hiddenLegacy ? '<textarea name="chatTextInput" style="display:none"></textarea><button aria-label="Gửi thư" style="display:none" onclick="window.traps++">Hidden send</button>' : ''}
    <textarea id="composer" ${placeholderOnly ? '' : `aria-label="${unrelated ? 'Ghi chú riêng' : english ? 'Send a message' : 'Gửi thư'}"`} placeholder="${unrelated ? 'Ghi chú riêng' : english ? 'Send a message' : 'Gửi thư'}"></textarea>
    <button id="send" aria-label="${english ? 'Send' : 'Gửi thư'}" ${ariaDisabled ? 'aria-disabled="true"' : ''} disabled>Send</button>
    <div id="messages"></div>
    <script>
      window.traps=0; window.sends=0; window.bridgeMessages=[];
      window.chrome.webview={postMessage(value){window.bridgeMessages.push(JSON.parse(value));}};
      const input=document.getElementById('composer'), send=document.getElementById('send');
      input.addEventListener('input',()=>{send.disabled=${disabled} || !input.value.trim();});
      send.onclick=()=>{
        window.sends++;
        const row=document.createElement('div');
        row.setAttribute('data-message-id','self-'+window.sends);
        row.setAttribute('data-message-text',input.value);
        row.setAttribute('data-is-self','true');
        row.setAttribute('data-sender-name','Teacher');
        document.getElementById('messages').appendChild(row);
        input.value='';
      };
    </script>
  </body></html>`;
}

(async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true});
  const passed=[];
  try {
    async function fixture(options={}) {
      const page=await browser.newPage();
      page.on('pageerror',error=>console.error('Fixture script error:',error.message));
      await page.route('**/*',route=>route.fulfill({contentType:'text/html; charset=utf-8',body:html(options)}));
      await page.goto('https://meet.google.com/meet/abc-defg-hij');
      await page.evaluate(script);
      await page.evaluate(()=>{
        const ready=window.bridgeMessages.find(m=>m.type==='MEET_BRIDGE_READY');
        window.command={documentId:ready.documentId,url:location.href,observationId:'fixture',requestId:'send-1',text:'Fixture reply.',expiresAt:Date.now()+10000};
      });
      if(!options.unrelated) {
        try { await page.waitForFunction(()=>JSON.parse(window.MeetBridge.beginTutorObservation(window.command)).status==='READY',null,{timeout:4000}); }
        catch(error) {
          console.error(await page.evaluate(()=>({state:window.MeetBridge.beginTutorObservation(window.command),command:window.command,inputs:Array.from(document.querySelectorAll('textarea')).map(n=>({label:n.getAttribute('aria-label'),visible:!!n.getClientRects().length})),events:window.bridgeMessages.map(m=>({type:m.type,payload:m.payload}))})));
          throw error;
        }
      }
      return page;
    }
    for(const [name,options] of [
      ['Vietnamese composer and exact send ignore hidden controls, permissions and emoji',{}],
      ['Vietnamese placeholder-only composer is supported',{placeholderOnly:true}],
      ['English composer remains compatible behind a hidden legacy textarea',{english:true}],
    ]) {
      const page=await fixture(options);
      const result=await page.evaluate(()=>JSON.parse(window.MeetBridge.sendTutor(window.command)));
      assert.equal(result.status,'CONFIRMED',name);
      assert.deepEqual(await page.evaluate(()=>({sends:window.sends,traps:window.traps})),{sends:1,traps:0});
      passed.push(name); await page.close();
    }
    for(const options of [{disabled:true},{ariaDisabled:true}]) {
      const page=await fixture(options);
      const result=await page.evaluate(()=>JSON.parse(window.MeetBridge.sendTutor(window.command)));
      assert.notEqual(result.status,'CONFIRMED');
      assert.deepEqual(await page.evaluate(()=>({sends:window.sends,traps:window.traps,draft:document.getElementById('composer').value})),{sends:0,traps:0,draft:''});
      passed.push(options.disabled?'Disabled real send never falls back to settings':'ARIA-disabled real send never falls back to emoji'); await page.close();
    }
    {
      const page=await fixture(); await page.locator('#composer').fill('Teacher draft');
      assert.equal(await page.evaluate(()=>JSON.parse(window.MeetBridge.sendTutor(window.command)).status),'INPUT_BUSY');
      assert.equal(await page.locator('#composer').inputValue(),'Teacher draft');
      assert.equal(await page.evaluate(()=>window.sends+window.traps),0);
      passed.push('Teacher draft is preserved'); await page.close();
    }
    {
      const page=await fixture();
      assert.equal(await page.evaluate(()=>window.MeetBridge.sendChat('Manual fixture reply.')),true);
      assert.deepEqual(await page.evaluate(()=>({sends:window.sends,traps:window.traps})),{sends:1,traps:0});
      passed.push('Explicit manual chat shares localized safe controls'); await page.close();
    }
    {
      const page=await fixture({unrelated:true});
      assert.equal(await page.evaluate(()=>JSON.parse(window.MeetBridge.beginTutorObservation(window.command)).status),'PENDING');
      assert.equal(await page.evaluate(()=>window.sends+window.traps),0);
      passed.push('An unrelated textarea is never treated as Meet chat'); await page.close();
    }
    console.log(JSON.stringify({passed:passed.length,fixtures:passed,liveGoogleValidated:false},null,2));
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
