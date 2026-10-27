'use strict';
const query=document.querySelector('#query'),form=document.querySelector('#lookup'),source=document.querySelector('#source'),results=document.querySelector('#results'),suggestions=document.querySelector('#suggestions'),status=document.querySelector('#status'),toggle=document.querySelector('#selection'),selectionHelp=document.querySelector('#selection-help');
const target='dictionary_selection';let ready=false,enabled=false,revision=0,timer,metadata=[];
const sourceMenu=document.querySelector('#source-menu'),sourceLabel=document.querySelector('#source-label');source.value='all';
const dictionary=new DictionaryEngine.Dictionary(async path=>{const response=await fetch(path);if(!response.ok)throw Error('Không đọc được dữ liệu');return response.json();});
function element(tag,text,className){const node=document.createElement(tag);node.textContent=text;if(className)node.className=className;return node;}
function link(text,url){const node=element('a',text);if(/^https:\/\//.test(url||'')){node.href=url;node.target='_blank';node.rel='noopener noreferrer';}return node;}
function syncTool(active){enabled=active;toggle.setAttribute('aria-pressed',String(active));toggle.textContent=active?'Đang bật · Bôi đen từ để tra':'Bật tra từ khi bôi đen';selectionHelp.textContent=active?'Kéo chọn từ hoặc cụm từ trên PDF. Ô tra từ sẽ tự cập nhật.':'Bật công cụ rồi kéo chọn từ trên PDF có lớp văn bản.';}
async function search(){
  const current=++revision;results.replaceChildren();suggestions.replaceChildren();const text=DictionaryEngine.normalize(DictionaryEngine.cleanTerm(query.value));
  if(!ready){status.textContent='Đang tải chỉ mục; từ đã nhập sẽ được tra ngay khi sẵn sàng.';return;}
  if(!text){status.textContent=`${dictionary.index.words.length.toLocaleString('vi')} mục từ · Tra ngoại tuyến. Nhập từ hoặc bôi đen trên PDF.`;return;}
  if(text.length>200){status.textContent='Hãy chọn một từ hoặc cụm từ ngắn (tối đa 200 ký tự).';return;}
  status.textContent='Đang tra nghĩa…';
  try{const groups=await dictionary.lookup(text,source.value);if(current!==revision)return;
    status.textContent=groups.length?`Tìm thấy trong ${groups.length} nguồn. Hãy đối chiếu nghĩa với ngữ cảnh.`:'Chưa có mục từ khớp chính xác trong nguồn đã chọn.';
    for(const group of groups){const meta=metadata.find(item=>item.id===group.source);results.append(element('h2',group.word));const label=element('p','', 'source-label');label.append(link(meta.name,meta.url));if(group.source==='literature')label.append(element('span',' · Bản biên soạn thử, cần giáo viên duyệt','draft'));results.append(label);
      group.senses.forEach((sense,i)=>{const article=element('article','');article.append(element('div',`${i+1}. ${sense.pos||''}`,'pos'),element('p',sense.definition));if(sense.example)article.append(element('p',sense.example,'example'));if(sense.upstream)article.append(element('div','Nguồn trong bộ tổng hợp: '+sense.upstream,'origin'));if(sense.url)article.append(link('Tham khảo nguồn',sense.url));results.append(article);});
    }
    if(!groups.length){let words=dictionary.suggest(text,source.value);if(text==='đào lẵng')words=['đào lẳng',...words];for(const word of new Set(words)){const button=element('button',word);button.type='button';button.onclick=()=>{query.value=word;search();};suggestions.append(button);}}
  }catch(_){if(current===revision)status.textContent='Không tải được mục nghĩa. Hãy thử tra lại hoặc mở lại tiện ích.';}
}
function acceptText(text){if(typeof text!=='string')return;query.value=DictionaryEngine.cleanTerm(text);clearTimeout(timer);search();}
query.addEventListener('input',event=>{++revision;clearTimeout(timer);if(!event?.isComposing)timer=setTimeout(search,120);});form.addEventListener('submit',event=>{event.preventDefault();clearTimeout(timer);query.value=DictionaryEngine.cleanTerm(query.value);search();});
function addSourceChoice(id,name){const button=element('button',name);button.type='button';button.dataset.source=id;button.setAttribute('aria-pressed',String(source.value===id));button.addEventListener('click',()=>{source.value=id;sourceLabel.textContent=name;for(const item of source.children)item.setAttribute('aria-pressed',String(item.dataset.source===id));sourceMenu.open=false;sourceLabel.focus();clearTimeout(timer);search();});source.append(button);}
toggle.addEventListener('click',async()=>{const next=!enabled;toggle.disabled=true;try{await window.HocLuc.board.setTool(target,next);syncTool(next);}catch(_){selectionHelp.textContent='Không bật được công cụ. Hãy mở tiện ích trong Teacher Station rồi thử lại.';}finally{toggle.disabled=false;}});
window.HocLuc?.onHostEvent('board:tool_state',payload=>syncTool(payload.active_tool===target));
window.HocLuc?.onHostEvent('board:text_selected',payload=>{if(enabled&&payload.target===target)acceptText(payload.text);});
window.onSnippetCaptured=(text,capturedTarget)=>{if(capturedTarget===target)acceptText(text);};
dictionary.init().then(index=>{metadata=index.sources;addSourceChoice('all','Tất cả nguồn');for(const item of metadata)addSourceChoice(item.id,item.name);ready=true;search();}).catch(()=>{status.textContent='Không tải được chỉ mục. Hãy đóng và mở lại tiện ích.';});
window.HocLuc?.getContext().then(context=>{syncTool(context.activeTool===target);toggle.disabled=false;}).catch(()=>{selectionHelp.textContent='Không kết nối được với ứng dụng. Bạn vẫn có thể nhập từ để tra.';});
