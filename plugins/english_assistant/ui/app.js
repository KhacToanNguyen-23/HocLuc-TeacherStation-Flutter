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
let registeredResultsElement = null;

function syncGlassResultRegion() {
  if (!resultsCard || resultsCard.style.display === 'none') {
    document.body?.classList.remove('glass-region-active');
    if (registeredResultsElement) {
      window.HocLuc?.glass?.unregisterRegion?.('analysis-result-card');
      registeredResultsElement = null;
    }
    return;
  }

  const glass = window.HocLuc?.glass;
  if (!glass?.registerRegion) return;
  document.body?.classList.add('glass-region-active');
  if (registeredResultsElement !== resultsCard) {
    registeredResultsElement = resultsCard;
    glass.registerRegion('analysis-result-card', resultsCard);
  } else {
    glass.updateRegion?.('analysis-result-card');
  }
}

const glassPresetValues = Object.freeze({
  clear: { opacity: '0.15', blur: '10px' },
  frosted: { opacity: '0.28', blur: '20px' },
  solid: { opacity: '0.85', blur: '28px' },
});
const glassPresetLatencySamples = [];

function applyGlassPreset(preset, payload = {}) {
  const values = glassPresetValues[preset];
  if (!values) return false;

  const root = document.documentElement;
  root.dataset.glassPreset = preset;
  root.style.setProperty('--glass-bg-opacity', values.opacity);
  root.style.setProperty('--glass-blur', values.blur);

  const updatedAtEpochMs = performance.timeOrigin + performance.now();
  const dispatchedAtEpochMs = Number(payload.dispatched_at_epoch_ms);
  if (Number.isFinite(dispatchedAtEpochMs) && dispatchedAtEpochMs > 0) {
    glassPresetLatencySamples.push({
      preset,
      dispatchedAtEpochMs,
      updatedAtEpochMs,
      latencyMs: updatedAtEpochMs - dispatchedAtEpochMs,
    });
    if (glassPresetLatencySamples.length > 120) glassPresetLatencySamples.shift();
  }
  return true;
}

function percentile(sortedSamples, fraction) {
  return sortedSamples[Math.max(0, Math.ceil(sortedSamples.length * fraction) - 1)];
}

window.__glassPresetLatencyReport = function() {
  const sorted = glassPresetLatencySamples
    .map((sample) => sample.latencyMs)
    .sort((left, right) => left - right);
  if (sorted.length === 0) {
    return { count: 0, medianMs: null, p95Ms: null, maxMs: null };
  }
  const median = sorted.length % 2 === 0
    ? (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2
    : sorted[Math.floor(sorted.length / 2)];
  return {
    count: sorted.length,
    medianMs: median,
    p95Ms: percentile(sorted, 0.95),
    maxMs: sorted[sorted.length - 1],
  };
};
window.__resetGlassPresetLatencySamples = function() {
  glassPresetLatencySamples.length = 0;
};

applyGlassPreset('frosted');
window.HocLuc?.onHostEvent?.('GLASS_PRESET_CHANGE', (payload = {}) => {
  applyGlassPreset(payload.preset, payload);
});

// Lấy port động do Host cấp phát qua URL query (?port=xxxxx)
const urlParams = new URLSearchParams(window.location.search);
const backendPort = urlParams.get('port');
const backendBaseUrl = backendPort ? `http://127.0.0.1:${backendPort}` : null;

// PrtSc Snipping Tool Trigger
btnSnipSvo?.addEventListener('click', async () => {
  try {
    await window.HocLuc?.board?.startSnipSelection('svo');
  } catch (error) {
    console.error('[EnglishAssistant] Snip request failed:', error);
  }
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
    if (backendBaseUrl) {
      const response = await fetch(`${backendBaseUrl}/analyze`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text }),
        signal: AbortSignal.timeout(1500),
      });

      if (response.ok) {
        const data = await response.json();
        currentAnalysis = data;
        backendBadge.textContent = `spaCy (${backendPort})`;
        backendBadge.style.color = '#86efac';
        renderResults(data);
        return;
      }
    }
  } catch (_) {
    // Fallback to offline heuristic
  } finally {
    btnAnalyze.disabled = false;
    btnAnalyze.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg><span>Phân tích cú pháp S-V-O</span>';
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
    pill.className = 'token-pill liquid-gem-token' + (t.role ? ` role-${t.role.toLowerCase()}` : '');

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
  syncGlassResultRegion();
}

btnPinToBoard?.addEventListener('click', async () => {
  if (!currentAnalysis) return;

  const annotationPayload = {
    type: 'sticker',
    data: {
      pluginId: 'com.hocluc.plugin.english',
      text: currentAnalysis.text,
      tokens: currentAnalysis.tokens,
      grammarIssue: currentAnalysis.grammarIssue,
    }
  };

  // Send board annotations through the Host SDK.
  try {
    await window.HocLuc.board.insertAnnotation(annotationPayload);
  } catch (error) {
    console.error('[EnglishAssistant] Annotation request failed:', error);
  }
});
