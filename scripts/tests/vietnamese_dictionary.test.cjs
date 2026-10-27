const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const {Dictionary,normalize,cleanTerm}=require('../../plugins/vietnamese_dictionary/ui/engine.js');
const ui=path.resolve(__dirname,'../../plugins/vietnamese_dictionary/ui');
const load=async file=>JSON.parse(await fs.readFile(path.join(ui,file),'utf8'));
const vm=require('node:vm');

test('offline meanings preserve literary meanings and distinct sources',async()=>{
  const dictionary=new Dictionary(load);await dictionary.init();
  const meanings=await dictionary.lookup('HỒNG QUÂN');
  assert(meanings.some(group=>group.senses.some(sense=>sense.definition.includes('trời'))));
  assert(meanings.some(group=>group.senses.some(sense=>sense.definition.includes('quân đội'))));
  const draft=await dictionary.lookup('đào thương','literature');
  assert.equal(draft.length,1);assert.match(draft[0].senses[0].definition,/nữ chín/);
  assert.equal((await dictionary.lookup('đào thương','vntk')).length,0);
});

test('normalizes decomposed Vietnamese and whitespace without stripping accents',async()=>{
  const dictionary=new Dictionary(load);await dictionary.init();
  assert.equal(normalize('  VÔ   HÌNH TRUNG  '.normalize('NFD')),'vô hình trung');
  assert((await dictionary.lookup('  VÔ   HÌNH TRUNG  '.normalize('NFD'))).length>0);
  assert.equal((await dictionary.lookup('')).length,0);
  assert.equal((await dictionary.lookup('x'.repeat(201))).length,0);
  assert.equal((await dictionary.lookup('<script>alert(1)</script>')).length,0);
  assert.equal((await dictionary.lookup('constructor')).length,0);
  assert.equal((await dictionary.lookup('__proto__')).length,0);
  assert.equal(cleanTerm(' , tiêu xảo.  '),'tiêu xảo');
  assert.equal(cleanTerm('TP.HCM'),'TP.HCM');
  assert.equal(cleanTerm('... , '),'');
  assert.deepEqual(await dictionary.lookup('đào thương.,'),await dictionary.lookup('đào thương'));
});

test('loads definitions lazily, bounds cache, and retries a failed shard',async()=>{
  const calls=[];let fail=true;
  const dictionary=new Dictionary(async file=>{calls.push(file);if(file.includes('shards')&&fail){fail=false;throw Error('temporary read failure');}return load(file);});
  await dictionary.init();assert.deepEqual(calls,['data/index.json']);
  await assert.rejects(dictionary.lookup('đào thương'));
  assert((await dictionary.lookup('đào thương')).length);
  const before=calls.length;await dictionary.lookup('đào thương');assert.equal(calls.length,before);
  for(const word of ['chào','học','văn','người','sách','đẹp','biển','trời'])await dictionary.lookup(word);
  assert(dictionary.cache.size<=4);
});

test('suggestions honor source filter and glossary labels',async()=>{
  const dictionary=new Dictionary(load);const index=await dictionary.init();
  assert(index.sources.some(source=>source.id==='literature'&&source.name.includes('bản thử')));
  const suggestions=dictionary.suggest('đào','literature');assert(suggestions.includes('đào thương'));
  for(const word of suggestions)assert((await dictionary.lookup(word,'literature')).length);
});

test('UI accepts active PDF selection, ignores inactive events, and handles activation acknowledgement',async()=>{
  class Element{
    constructor(){this.value='';this.children=[];this.listeners={};this.attributes={};this.dataset={};this.textContent='';}
    addEventListener(name,fn){this.listeners[name]=fn;}
    focus(){this.focused=true;}
    append(...nodes){this.children.push(...nodes);}
    replaceChildren(){this.children=[];}
    setAttribute(name,value){this.attributes[name]=value;}
  }
  const nodes=Object.fromEntries(['query','lookup','source','source-menu','source-label','results','suggestions','status','selection','selection-help'].map(id=>['#'+id,new Element()]));
  nodes['#source'].value='all';
  const events={};let releaseIndex;
  const indexGate=new Promise(resolve=>releaseIndex=resolve);
  const sdk={onHostEvent:(event,fn)=>events[event]=fn,getContext:async()=>({activeTool:null}),board:{setTool:async(target,active)=>{events['board:tool_state']({active_tool:active?target:null});}}};
  const context={document:{querySelector:id=>nodes[id],createElement:()=>new Element()},window:{HocLuc:sdk},DictionaryEngine:require('../../plugins/vietnamese_dictionary/ui/engine.js'),setTimeout,clearTimeout,
    fetch:async file=>{if(file==='data/index.json')await indexGate;return {ok:true,json:()=>load(file)};}};
  vm.runInNewContext(await fs.readFile(path.join(ui,'app.js'),'utf8'),context);
  events['board:text_selected']({target:'dictionary_selection',text:'ignored'});assert.equal(nodes['#query'].value,'');
  await nodes['#selection'].listeners.click();assert.equal(nodes['#selection'].attributes['aria-pressed'],'true');
  events['board:text_selected']({target:'dictionary_selection',text:'đào thương.,'});assert.equal(nodes['#query'].value,'đào thương');
  releaseIndex();
  for(let i=0;i<100&&!nodes['#results'].children.length;i++)await new Promise(resolve=>setTimeout(resolve,5));
  assert(nodes['#results'].children.length>0,'selection received during loading is looked up');
  const vntkChoice=nodes['#source'].children.find(button=>button.dataset.source==='vntk');
  vntkChoice.listeners.click();
  await new Promise(resolve=>setTimeout(resolve,20));
  assert.equal(nodes['#source'].value,'vntk');
  assert.equal(nodes['#source-label'].textContent,'VNTK');
  assert.equal(vntkChoice.attributes['aria-pressed'],'true');
  assert.equal(nodes['#results'].children.length,0,'source picker actually filters the displayed definitions');
  await nodes['#selection'].listeners.click();assert.equal(nodes['#selection'].attributes['aria-pressed'],'false');
  events['board:text_selected']({target:'dictionary_selection',text:'hồng quân'});assert.equal(nodes['#query'].value,'đào thương');
  nodes['#query'].value='vô ';
  nodes['#query'].listeners.input({isComposing:false});
  await new Promise(resolve=>setTimeout(resolve,160));
  assert.equal(nodes['#query'].value,'vô ','debounced lookup must preserve space and caret while typing');
});
