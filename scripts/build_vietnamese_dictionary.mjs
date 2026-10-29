// Convert the evaluated local demo snapshot into bounded, lazy-loaded shards.
// Usage: node scripts/build_vietnamese_dictionary.mjs <demo-directory>
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url);
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const plugin=path.join(root,'plugins/vietnamese_dictionary');
const {normalize,bucket}=require(path.join(plugin,'ui/engine.js'));
const demo=process.argv[2];
if(!demo)throw Error('Pass the evaluated demo directory containing data/combined.json');
const sources=JSON.parse(fs.readFileSync(path.join(demo,'data/combined.json'),'utf8'));
sources.push({id:'literature',name:'Ghi chú Ngữ văn · bản thử',license:'Original editorial draft; teacher review required',url:'',entries:JSON.parse(fs.readFileSync(path.join(plugin,'literature-glossary.json'),'utf8'))});
const shards=Array.from({length:128},()=>Object.create(null));
const words=new Map();
for(const source of sources){
  for(const [word,senses] of Object.entries(source.entries)){
    const key=normalize(word);if(!key||!Array.isArray(senses))continue;
    const valid=senses.filter(s=>typeof s.definition==='string'&&s.definition.trim());if(!valid.length)continue;
    const shard=shards[parseInt(bucket(key),16)];
    (shard[key]??=[]).push({source:source.id,word,senses:valid});
    if(!words.has(key))words.set(key,new Set());words.get(key).add(source.id);
  }
}
const data=path.join(plugin,'ui/data');fs.mkdirSync(path.join(data,'shards'),{recursive:true});
for(let i=0;i<128;i++)fs.writeFileSync(path.join(data,'shards',`${i.toString(16).padStart(2,'0')}.json`),JSON.stringify(shards[i])+'\n');
const metadata=sources.map(({entries,...source})=>source);
fs.writeFileSync(path.join(data,'index.json'),JSON.stringify({sources:metadata,words:[...words].sort(([a],[b])=>a.localeCompare(b,'vi')).map(([word,ids])=>[word,[...ids]])})+'\n');
const licenses=path.join(plugin,'licenses');fs.mkdirSync(licenses,{recursive:true});
for(const file of ['LICENSE-vntk.txt','LICENSE-minhqnd.txt'])fs.copyFileSync(path.join(demo,'data',file),path.join(licenses,file));
// The Wiktionary snapshot is used under CC BY-SA 4.0; include its legal text too.
fs.copyFileSync(path.join(demo,'data/LICENSE-minhqnd.txt'),path.join(licenses,'CC-BY-SA-4.0.txt'));
console.log(`${words.size} normalized headwords; ${sources.length} sources; 128 definition shards.`);
