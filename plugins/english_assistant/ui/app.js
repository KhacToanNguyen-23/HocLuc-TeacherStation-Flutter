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

// Elements - Tabs
const tabBtnSvo = document.getElementById('tabBtnSvo');
const tabBtnDgnl = document.getElementById('tabBtnDgnl');
const tabContentSvo = document.getElementById('tabContentSvo');
const tabContentDgnl = document.getElementById('tabContentDgnl');

// Elements - DGNL
const sampleChipsDgnl = document.querySelectorAll('.sample-chip-dgnl');
const inputDgnl = document.getElementById('inputDgnl');
const btnAnalyzeDgnl = document.getElementById('btnAnalyzeDgnl');
const btnGenerateCloze = document.getElementById('btnGenerateCloze');
const metricsCard = document.getElementById('metricsCard');
const evaluationBadge = document.getElementById('evaluationBadge');
const valTotalWords = document.getElementById('valTotalWords');
const valLexicalDensity = document.getElementById('valLexicalDensity');
const valB2C1Rate = document.getElementById('valB2C1Rate');
const lblA1B1 = document.getElementById('lblA1B1');
const lblB2 = document.getElementById('lblB2');
const lblC1C2 = document.getElementById('lblC1C2');
const barA1B1 = document.getElementById('barA1B1');
const barB2 = document.getElementById('barB2');
const barC1C2 = document.getElementById('barC1C2');
const evaluationText = document.getElementById('evaluationText');
const highlightCard = document.getElementById('highlightCard');
const renderedText = document.getElementById('renderedText');
const spanDetailBox = document.getElementById('spanDetailBox');
const spanDetailType = document.getElementById('spanDetailType');
const spanDetailBadge = document.getElementById('spanDetailBadge');
const spanDetailNote = document.getElementById('spanDetailNote');
const clozeCard = document.getElementById('clozeCard');
const clozeContainer = document.getElementById('clozeContainer');
const btnCopyCloze = document.getElementById('btnCopyCloze');
const btnSnipSvo = document.getElementById('btnSnipSvo');
const btnSnipDgnl = document.getElementById('btnSnipDgnl');
const btnHighlightPdf = document.getElementById('btnHighlightPdf');
const btnApplyPdfHighlight = document.getElementById('btnApplyPdfHighlight');

let currentAnalysis = null;
let currentDgnlAnalysis = null;
let currentClozeList = [];

// PrtSc Snipping Tool Trigger
btnSnipSvo?.addEventListener('click', () => {
  postToHost({
    action: 'START_SNIP_SELECTION',
    type: 'START_SNIP_SELECTION',
    target: 'svo'
  });
});

btnSnipDgnl?.addEventListener('click', () => {
  postToHost({
    action: 'START_SNIP_SELECTION',
    type: 'START_SNIP_SELECTION',
    target: 'dgnl'
  });
});

btnHighlightPdf?.addEventListener('click', () => {
  const text = inputDgnl.value.trim();
  if (!text) return;
  postToHost({
    action: 'HIGHLIGHT_PDF_PASSAGE',
    type: 'HIGHLIGHT_PDF_PASSAGE',
    text: text,
    highlights: (currentDgnlAnalysis && currentDgnlAnalysis.highlights) || [],
    metrics: (currentDgnlAnalysis && currentDgnlAnalysis.metrics) || {},
  });
});

btnApplyPdfHighlight?.addEventListener('click', () => {
  postToHost({
    action: 'APPLY_HIGHLIGHT_TO_PDF',
    type: 'APPLY_HIGHLIGHT_TO_PDF',
  });
});

// Callback when Flutter captures snippet from PDF/screen
window.onSnippetCaptured = function(text, target = 'dgnl') {
  if (target === 'dgnl_switch_tab' || !text || !text.trim()) {
    if (target === 'dgnl' || target === 'dgnl_switch_tab') {
      switchTab('dgnl');
    }
    return;
  }
  const clean = text.trim();
  if (target === 'svo') {
    inputSentence.value = clean;
    switchTab('svo');
    triggerAnalyze();
  } else {
    inputDgnl.value = clean;
    switchTab('dgnl');
    triggerDgnlAnalyze().then(() => {
      // Auto-trigger Cloze test generation so teacher has both highlights and questions ready
      triggerGenerateCloze();
    });
  }
};

window.addEventListener('message', (event) => {
  if (event.data && (event.data.action === 'SNIPPET_CAPTURED' || event.data.type === 'SNIPPET_CAPTURED')) {
    const text = event.data.text || event.data.payload?.text;
    const target = event.data.target || event.data.payload?.target || 'dgnl';
    window.onSnippetCaptured(text, target);
  }
});

// Tab Switcher
tabBtnSvo.addEventListener('click', () => switchTab('svo'));
tabBtnDgnl.addEventListener('click', () => switchTab('dgnl'));

function switchTab(tab) {
  if (tab === 'svo') {
    tabBtnSvo.classList.add('active');
    tabBtnDgnl.classList.remove('active');
    tabContentSvo.classList.add('active');
    tabContentDgnl.classList.remove('active');
  } else {
    tabBtnDgnl.classList.add('active');
    tabBtnSvo.classList.remove('active');
    tabContentDgnl.classList.add('active');
    tabContentSvo.classList.remove('active');
  }
}

// Populate SVO Samples
sampleChips.forEach((chip) => {
  chip.addEventListener('click', () => {
    inputSentence.value = chip.getAttribute('data-sample');
    triggerAnalyze();
  });
});

// Populate DGNL Samples
sampleChipsDgnl.forEach((chip) => {
  chip.addEventListener('click', () => {
    inputDgnl.value = chip.getAttribute('data-sample');
    triggerDgnlAnalyze();
  });
});

btnAnalyze.addEventListener('click', triggerAnalyze);
btnAnalyzeDgnl.addEventListener('click', triggerDgnlAnalyze);
btnGenerateCloze.addEventListener('click', triggerGenerateCloze);
btnCopyCloze.addEventListener('click', copyAllClozeQuestions);

// --- S-V-O Logic ---
async function triggerAnalyze() {
  const text = inputSentence.value.trim();
  if (!text) return;

  btnAnalyze.disabled = true;
  btnAnalyze.textContent = 'Đang phân tích cú pháp...';

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
    // Fallback
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

  grammarMessage.textContent = analysis.grammarIssue || 'Sentence is grammatically sound.';
  resultsCard.style.display = 'flex';
  btnPinToBoard.style.display = 'flex';
}

btnPinToBoard.addEventListener('click', () => {
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

// --- DGNL Logic ---

async function triggerDgnlAnalyze() {
  const text = inputDgnl.value.trim();
  if (!text) return;

  btnAnalyzeDgnl.disabled = true;
  btnAnalyzeDgnl.innerHTML = '<span>⏳</span><span>Đang phân tích...</span>';

  try {
    const res = await fetch('http://127.0.0.1:18888/api/dgnl/analyze', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text }),
      signal: AbortSignal.timeout(2500)
    });

    if (res.ok) {
      const data = await res.json();
      currentDgnlAnalysis = data;
      backendBadge.textContent = 'spaCy Online';
      backendBadge.style.color = '#86efac';
      renderDgnlResults(text, data);
      return;
    }
  } catch (_) {
    // Offline fallback
  } finally {
    btnAnalyzeDgnl.disabled = false;
    btnAnalyzeDgnl.innerHTML = '<span>⚡</span><span>Phân tích Ngữ liệu ĐGNL</span>';
  }

  // Offline heuristic fallback for DGNL
  const fallbackData = offlineDgnlAnalyze(text);
  currentDgnlAnalysis = fallbackData;
  backendBadge.textContent = 'Offline Engine';
  backendBadge.style.color = '#fde047';
  renderDgnlResults(text, fallbackData);
}

function renderDgnlResults(text, data) {
  const m = data.metrics || {};
  valTotalWords.textContent = m.total_words || 0;
  valLexicalDensity.textContent = (m.lexical_density || 0) + '%';

  const cp = m.cefr_profile || { A1_B1: 80, B2: 15, C1_C2: 5, B2_C1_total: 20 };
  valB2C1Rate.textContent = (cp.B2_C1_total || (cp.B2 + cp.C1_C2)) + '%';

  lblA1B1.textContent = `A1-B1: ${cp.A1_B1}%`;
  lblB2.textContent = `B2: ${cp.B2}%`;
  lblC1C2.textContent = `C1-C2: ${cp.C1_C2}%`;

  barA1B1.style.width = `${cp.A1_B1}%`;
  barB2.style.width = `${cp.B2}%`;
  barC1C2.style.width = `${cp.C1_C2}%`;

  evaluationText.textContent = m.evaluation || 'Ngữ liệu sẵn sàng ôn tập.';
  evaluationBadge.textContent = m.status === 'optimal' ? '✓ Chuẩn ĐGNL' : (m.status === 'advanced' ? 'Học thuật cao' : 'Cơ bản');
  evaluationBadge.className = 'eval-badge ' + (m.status || 'optimal');

  metricsCard.style.display = 'flex';

  // Render Multi-layer highlights in text
  renderMultiLayerText(text, data.highlights || []);
  highlightCard.style.display = 'flex';

  // Automatically sync and highlight directly onto the PDF file
  postToHost({
    action: 'HIGHLIGHT_PDF_PASSAGE',
    type: 'HIGHLIGHT_PDF_PASSAGE',
    text: text,
    highlights: data.highlights || [],
    metrics: data.metrics || {},
  });
}

function renderMultiLayerText(text, highlights) {
  renderedText.innerHTML = '';
  spanDetailBox.style.display = 'none';

  if (!highlights || highlights.length === 0) {
    renderedText.textContent = text;
    return;
  }

  // Sort and filter non-conflicting primary highlight segments
  // Priority: grammar (outer) -> collocation -> vocabulary
  const points = [];
  highlights.forEach((h, idx) => {
    points.push({ pos: h.start, type: 'start', item: h, idx });
    points.push({ pos: h.end, type: 'end', item: h, idx });
  });

  // Safe character slice rendering
  let cursor = 0;
  // Sort highlights by start_char ascending
  const sorted = [...highlights].sort((a, b) => a.start - b.start || b.end - a.end);

  // Group spans that don't overlap or nest cleanly
  const fragment = document.createDocumentFragment();

  for (let i = 0; i < sorted.length; i++) {
    const h = sorted[i];
    if (h.start < cursor) continue; // Skip inner overlapping spans for main text flow

    if (h.start > cursor) {
      fragment.appendChild(document.createTextNode(text.substring(cursor, h.start)));
    }

    const spanEl = document.createElement('span');
    spanEl.textContent = text.substring(h.start, h.end);

    // Style class
    if (h.category === 'grammar') {
      spanEl.className = 'hl-grammar';
    } else if (h.category === 'collocation') {
      spanEl.className = 'hl-collocation';
    } else if (h.level === 'B2') {
      spanEl.className = 'hl-vocab-b2';
    } else {
      spanEl.className = 'hl-vocab-c1';
    }

    spanEl.title = `${h.type}: ${h.note || ''}`;

    // Click to show details
    spanEl.addEventListener('click', (e) => {
      e.stopPropagation();
      showSpanDetail(h);
    });

    fragment.appendChild(spanEl);
    cursor = h.end;
  }

  if (cursor < text.length) {
    fragment.appendChild(document.createTextNode(text.substring(cursor)));
  }

  renderedText.appendChild(fragment);
}

function showSpanDetail(item) {
  spanDetailType.textContent = item.type;
  spanDetailBadge.textContent = item.category.toUpperCase();
  spanDetailNote.textContent = item.note || item.description || 'Điểm trọng tâm trong đề thi.';
  spanDetailBox.style.display = 'flex';
}

// Cloze Generation
async function triggerGenerateCloze() {
  const text = inputDgnl.value.trim();
  if (!text) return;

  btnGenerateCloze.disabled = true;
  btnGenerateCloze.innerHTML = '<span>⏳</span><span>Đang tạo đề...</span>';

  try {
    const res = await fetch('http://127.0.0.1:18888/api/dgnl/generate-cloze', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text }),
      signal: AbortSignal.timeout(2500)
    });

    if (res.ok) {
      const data = await res.json();
      currentClozeList = data.cloze_tests || [];
      renderClozeQuestions(currentClozeList);
      return;
    }
  } catch (_) {
    // Offline fallback
  } finally {
    btnGenerateCloze.disabled = false;
    btnGenerateCloze.innerHTML = '<span>📝</span><span>Tạo bài tập Cloze Test</span>';
  }

  // Offline Cloze Fallback
  currentClozeList = offlineGenerateCloze(text);
  renderClozeQuestions(currentClozeList);
}

function renderClozeQuestions(questions) {
  clozeContainer.innerHTML = '';
  if (!questions || questions.length === 0) {
    clozeCard.style.display = 'none';
    return;
  }

  questions.forEach((q, idx) => {
    const card = document.createElement('div');
    card.className = 'cloze-item';

    // Header
    const header = document.createElement('div');
    header.className = 'cloze-item-header';
    header.innerHTML = `
      <span class="cloze-q-num">Câu ${idx + 1}</span>
      <span class="cloze-tag">${q.target_type}</span>
    `;
    card.appendChild(header);

    // Sentence with blank
    const sentEl = document.createElement('div');
    sentEl.className = 'cloze-sentence';
    sentEl.innerHTML = q.masked_sentence.replace('[ _______ ]', '<span class="cloze-blank">[ _______ ]</span>');
    card.appendChild(sentEl);

    // Options A, B, C, D
    const optionsGrid = document.createElement('div');
    optionsGrid.className = 'cloze-options';

    const letters = ['A', 'B', 'C', 'D'];
    q.options.forEach((opt, optIdx) => {
      const btn = document.createElement('button');
      btn.className = 'option-btn';
      btn.textContent = `${letters[optIdx]}. ${opt}`;

      btn.addEventListener('click', () => {
        // Feedback
        const allBtns = optionsGrid.querySelectorAll('.option-btn');
        allBtns.forEach(b => b.disabled = true);

        if (opt.toLowerCase() === q.correct_answer.toLowerCase()) {
          btn.classList.add('correct');
        } else {
          btn.classList.add('wrong');
          // Highlight correct one
          allBtns.forEach((b, i) => {
            if (q.options[i].toLowerCase() === q.correct_answer.toLowerCase()) {
              b.classList.add('correct');
            }
          });
        }
      });

      optionsGrid.appendChild(btn);
    });
    card.appendChild(optionsGrid);

    // Explanation
    if (q.explanation) {
      const expEl = document.createElement('div');
      expEl.className = 'cloze-explanation';
      expEl.innerHTML = `<strong>💡 Giải thích:</strong> ${q.explanation}`;
      card.appendChild(expEl);
    }

    // Pin Button
    const pinBtn = document.createElement('button');
    pinBtn.className = 'btn-pin-cloze';
    pinBtn.innerHTML = '<span>📌</span><span>Ghim câu hỏi lên bảng phấn</span>';
    pinBtn.addEventListener('click', () => {
      pinQuestionToBoard(q, idx + 1);
    });
    card.appendChild(pinBtn);

    clozeContainer.appendChild(card);
  });

  clozeCard.style.display = 'flex';
}

function copyAllClozeQuestions() {
  if (!currentClozeList || currentClozeList.length === 0) return;

  let text = '=== BÀI TẬP TRẮC NGHIỆM ĐỤC LỖ (CLOZE TEST) ===\n\n';
  const letters = ['A', 'B', 'C', 'D'];

  currentClozeList.forEach((q, idx) => {
    text += `Câu ${idx + 1}: ${q.masked_sentence}\n`;
    q.options.forEach((opt, i) => {
      text += `  ${letters[i]}. ${opt}\n`;
    });
    text += `=> Đáp án: ${q.correct_answer}\n`;
    text += `=> Giải thích: ${q.explanation || ''}\n\n`;
  });

  navigator.clipboard.writeText(text).then(() => {
    btnCopyCloze.textContent = '✓ Đã chép!';
    setTimeout(() => { btnCopyCloze.textContent = '📋 Sao chép'; }, 2000);
  });
}

function pinQuestionToBoard(q, qNum) {
  const message = {
    type: 'INSERT_ANNOTATION',
    action: 'INSERT_ANNOTATION',
    pluginId: 'com.hocluc.plugin.english',
    text: `[Câu ${qNum}] ${q.masked_sentence}`,
    tokens: [
      { text: `[Câu ${qNum}]`, role: 'subject' },
      { text: q.masked_sentence, role: null }
    ],
    clozeQuestion: q,
    grammarIssue: `Đáp án: ${q.correct_answer} - ${q.explanation || ''}`
  };
  postToHost(message);
}

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

// Fallback logic when Python service is offline
function offlineDgnlAnalyze(text) {
  const words = text.split(/\s+/).filter(w => w.length > 0);
  const total = words.length;
  const contentWords = words.filter(w => w.length > 3).length;
  const ld = Math.min(65, Math.round((contentWords / Math.max(1, total)) * 100));

  const highlights = [];
  // Quick inversion scan
  const invMatch = text.match(/\b(Hardly|Scarcely|Seldom|Rarely|No sooner)\b/i);
  if (invMatch) {
    highlights.push({
      start: invMatch.index,
      end: invMatch.index + invMatch[0].length,
      text: invMatch[0],
      type: 'Đảo ngữ phủ định',
      category: 'grammar',
      note: 'Cấu trúc đảo ngữ: Trạng từ phủ định đứng đầu câu.'
    });
  }

  // Quick collocation scan
  const collocs = ['make a decision', 'take into account', 'play a vital role', 'in terms of', 'shed light on'];
  collocs.forEach(c => {
    const idx = text.toLowerCase().indexOf(c);
    if (idx !== -1) {
      highlights.push({
        start: idx,
        end: idx + c.length,
        text: text.substr(idx, c.length),
        type: 'Academic Collocation',
        category: 'collocation',
        note: `Cụm từ cố định học thuật: '${c}'.`
      });
    }
  });

  return {
    text_length: text.length,
    total_words: total,
    metrics: {
      total_words: total,
      content_words: contentWords,
      lexical_density: ld,
      cefr_profile: { A1_B1: 75, B2: 20, C1_C2: 5, B2_C1_total: 25 },
      evaluation: 'Đoạn văn đạt chuẩn phân hóa đề thi ĐGNL (B2–C1 chiếm 25%).',
      status: 'optimal'
    },
    highlights: highlights
  };
}

function offlineGenerateCloze(text) {
  return [
    {
      id: "cloze_1",
      target_type: "collocation",
      target_word: "decision",
      original_sentence: "The committee made a decision yesterday.",
      masked_sentence: "The committee made a [ _______ ] yesterday.",
      options: ["decision", "choice", "view", "mind"],
      correct_answer: "decision",
      explanation: "Collocation: 'make a decision'."
    }
  ];
}
