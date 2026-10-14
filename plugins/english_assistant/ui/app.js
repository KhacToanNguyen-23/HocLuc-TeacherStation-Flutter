// Elements - SVO
const inputSentence = document.getElementById('inputSentence');
const btnAnalyze = document.getElementById('btnAnalyze');
const resultsCard = document.getElementById('resultsCard');
const tokensContainer = document.getElementById('tokensContainer');
const grammarAlert = document.getElementById('grammarAlert');
const grammarMessage = document.getElementById('grammarMessage');
const btnPinToBoard = document.getElementById('btnPinToBoard');
const backendBadge = document.getElementById('backendBadge');
const sampleChips = document.querySelectorAll('.sample-chip');
const btnSnipSvo = document.getElementById('btnSnipSvo');

let currentAnalysis = null;

// PrtSc Snipping Tool Trigger
btnSnipSvo?.addEventListener('click', () => {
  postToHost({
    action: 'START_SNIP_SELECTION',
    type: 'START_SNIP_SELECTION',
    target: 'svo'
  });
});

// Callback when Flutter captures snippet from PDF/screen
window.onSnippetCaptured = function(text, target = 'svo') {
  if (target === 'svo' && text && text.trim()) {
    inputSentence.value = text.trim();
    triggerAnalyze();
  }
};

window.addEventListener('message', (event) => {
  if (event.data && (event.data.action === 'SNIPPET_CAPTURED' || event.data.type === 'SNIPPET_CAPTURED')) {
    const text = event.data.text || event.data.payload?.text;
    const target = event.data.target || event.data.payload?.target || 'svo';
    window.onSnippetCaptured(text, target);
  }
});

// Populate SVO Samples
sampleChips.forEach((chip) => {
  chip.addEventListener('click', () => {
    inputSentence.value = chip.getAttribute('data-sample');
    triggerAnalyze();
  });
});

btnAnalyze?.addEventListener('click', triggerAnalyze);

// --- S-V-O Logic ---
async function triggerAnalyze() {
  const text = inputSentence.value.trim();
  if (!text) return;

  btnAnalyze.disabled = true;
  btnAnalyze.innerHTML = '<span>⏳</span><span>Đang phân tích cú pháp...</span>';

  try {
    const response = await fetch('http://127.0.0.1:18888/analyze', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text }),
      signal: AbortSignal.timeout(1500),
    });

    if (response.ok) {
      const data = await response.json();
      currentAnalysis = data;
      backendBadge.textContent = 'spaCy Online';
      backendBadge.style.color = '#86efac';
      renderResults(data);
      return;
    }
  } catch (_) {
    // Fallback to offline heuristic
  } finally {
    btnAnalyze.disabled = false;
    btnAnalyze.innerHTML = '<span>⚡</span><span>Phân tích cú pháp S-V-O</span>';
  }

  currentAnalysis = offlineAnalyze(text);
  backendBadge.textContent = 'Offline Engine';
  backendBadge.style.color = '#fde047';
  renderResults(currentAnalysis);
}

function offlineAnalyze(text) {
  const words = text.split(/\s+/);
  const commonVerbs = new Set(['is', 'are', 'am', 'was', 'were', 'reads', 'read', 'plays', 'played', 'writes', 'wrote', 'teaches', 'taught', 'learns', 'runs', 'ran', 'sees', 'saw', 'has', 'have', 'had', 'makes', 'made', 'explained', 'explains']);
  const commonSubjects = new Set(['i', 'you', 'he', 'she', 'it', 'we', 'they', 'student', 'teacher', 'cat', 'dog']);

  let foundVerb = false;
  let foundSubject = false;

  const tokens = words.map((w, index) => {
    const clean = w.replace(/[^a-zA-Z]/g, '').toLowerCase();
    let role = null;
    if (!foundSubject && (commonSubjects.has(clean) || (index > 0 && commonSubjects.has(words[index - 1].toLowerCase())))) {
      role = 'subject';
      foundSubject = true;
    } else if (!foundVerb && commonVerbs.has(clean)) {
      role = 'verb';
      foundVerb = true;
    } else if (foundVerb && role === null && clean.length > 2 && !['in', 'on', 'at', 'the', 'a', 'an', 'to', 'for'].includes(clean)) {
      role = 'object';
    }
    return { text: w, role: role };
  });

  return {
    text: text,
    tokens: tokens,
    grammarIssue: 'Cú pháp câu văn rõ ràng, chuẩn xác (S-V-O).'
  };
}

function renderResults(analysis) {
  tokensContainer.innerHTML = '';
  analysis.tokens.forEach((t) => {
    const pill = document.createElement('div');
    pill.className = 'token-pill' + (t.role ? ` role-${t.role.toLowerCase()}` : '');

    const wordSpan = document.createElement('span');
    wordSpan.textContent = t.text;
    pill.appendChild(wordSpan);

    if (t.role) {
      const roleTag = document.createElement('span');
      roleTag.className = 'role-tag';
      roleTag.textContent = t.role.toUpperCase() === 'SUBJECT' ? 'S' : (t.role.toUpperCase() === 'VERB' ? 'V' : 'O');
      pill.appendChild(roleTag);
    }
    tokensContainer.appendChild(pill);
  });

  grammarMessage.textContent = analysis.grammarIssue || 'Câu chuẩn xác ngữ pháp.';
  resultsCard.style.display = 'flex';
  btnPinToBoard.style.display = 'flex';
}

btnPinToBoard?.addEventListener('click', () => {
  if (!currentAnalysis) return;
  const message = {
    type: 'INSERT_ANNOTATION',
    action: 'INSERT_ANNOTATION',
    pluginId: 'com.hocluc.plugin.english',
    text: currentAnalysis.text,
    tokens: currentAnalysis.tokens,
    grammarIssue: currentAnalysis.grammarIssue,
  };
  postToHost(message);
});

function postToHost(message) {
  // Bridge to Windows WebView2 Host
  if (window.chrome && window.chrome.webview) {
    try {
      window.chrome.webview.postMessage(message);
    } catch (_) {
      try {
        window.chrome.webview.postMessage(JSON.stringify(message));
      } catch (err) {
        console.error('WebView postMessage error', err);
      }
    }
  }
  // Bridge to Web Iframe Host
  if (window.parent) {
    window.parent.postMessage(message, '*');
  }
}
