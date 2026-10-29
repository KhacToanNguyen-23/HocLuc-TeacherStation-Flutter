(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.DictionaryEngine=factory();})(typeof self!=='undefined'?self:this,function(){
  'use strict';
  function normalize(text){return typeof text==='string'?text.normalize('NFC').trim().replace(/\s+/g,' ').toLocaleLowerCase('vi'):'';}
  function cleanTerm(text){return typeof text==='string'?text.normalize('NFC').replace(/^[\s.,，。]+|[\s.,，。]+$/gu,'').replace(/\s+/g,' '):'';}
  function bucket(text){let h=0;for(const char of normalize(text))h=(Math.imul(h,31)+char.codePointAt(0))>>>0;return (h%128).toString(16).padStart(2,'0');}
  class Dictionary{
    constructor(load){this.load=load;this.cache=new Map();this.index=null;}
    async init(){this.index=await this.load('data/index.json');return this.index;}
    async lookup(text,source='all'){
      const key=normalize(cleanTerm(text));if(!key||key.length>200)return [];
      const id=bucket(key);let promise=this.cache.get(id);
      if(!promise){promise=this.load(`data/shards/${id}.json`).catch(error=>{this.cache.delete(id);throw error;});this.cache.set(id,promise);if(this.cache.size>4)this.cache.delete(this.cache.keys().next().value);}
      const shard=await promise;
      const groups=Object.hasOwn(shard,key)&&Array.isArray(shard[key])?shard[key]:[];
      return groups.filter(group=>source==='all'||group.source===source);
    }
    suggest(text,source='all'){
      const key=normalize(cleanTerm(text));if(!key||!this.index)return [];
      return this.index.words.filter(row=>row[0].startsWith(key)&&(source==='all'||row[1].includes(source))).slice(0,8).map(row=>row[0]);
    }
  }
  return {normalize,cleanTerm,bucket,Dictionary};
});
