const glassPresetValues = Object.freeze({
  clear: { opacity: '0.15', blur: '10px' },
  frosted: { opacity: '0.28', blur: '20px' },
  solid: { opacity: '0.85', blur: '28px' },
});
const glassPresetLatencySamples = [];
function applyGlassPreset(preset, payload = {}) {
  const values = glassPresetValues[preset]; if (!values) return false;
  const root = document.documentElement;
  root.dataset.glassPreset = preset;
  root.style.setProperty('--glass-bg-opacity', values.opacity);
  root.style.setProperty('--glass-blur', values.blur);
  const dispatchedAtEpochMs = Number(payload.dispatched_at_epoch_ms);
  if (Number.isFinite(dispatchedAtEpochMs) && dispatchedAtEpochMs > 0) {
    glassPresetLatencySamples.push({ latencyMs: performance.timeOrigin + performance.now() - dispatchedAtEpochMs });
    if (glassPresetLatencySamples.length > 120) glassPresetLatencySamples.shift();
  }
  return true;
}
window.__glassPresetLatencyReport = () => {
  const values = glassPresetLatencySamples.map((sample) => sample.latencyMs).sort((a, b) => a - b);
  if (!values.length) return { count: 0, medianMs: null, p95Ms: null, maxMs: null };
  return { count: values.length, medianMs: values[Math.floor((values.length - 1) / 2)], p95Ms: values[Math.ceil(values.length * .95) - 1], maxMs: values[values.length - 1] };
};
window.__resetGlassPresetLatencySamples = () => { glassPresetLatencySamples.length = 0; };
applyGlassPreset('frosted');
window.HocLuc?.onHostEvent?.('GLASS_PRESET_CHANGE', (payload = {}) => applyGlassPreset(payload.preset, payload));

const sourceInput = document.querySelector?.('#source-text') || { value: '' };
const analyzeButton = document.querySelector?.('#analyze-button') || { disabled: false, addEventListener() {} };
const statusNode = document.querySelector?.('#status') || { textContent: '' };
const resultsNode = document.querySelector?.('#results') || { replaceChildren() {}, append() {} };
let activeSection = 'overview';
let latestResult = null;
let requestSequence = 0;
let renderGeneration = 0;
const dictionaryEntries = new Map();

function node(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = String(text);
  return element;
}

function profile(result) { return result?.analysis || {}; }
function spans(result, id) {
  return (result?.spans || []).filter((span) => span?.style?.id === id);
}
function metadata(span) { return span?.style?.metadata || {}; }

async function loadDictionaryEntry(word) {
  const key = String(word || '').trim().toLowerCase();
  if (!key) return { status: 'not-found' };
  if (dictionaryEntries.has(key)) return dictionaryEntries.get(key);
  const request = fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(key)}`)
    .then(async (response) => {
      if (response.status === 404) return { status: 'not-found' };
      if (!response.ok) throw new Error(`Dictionary API returned ${response.status}`);
      const payload = await response.json();
      const entries = Array.isArray(payload) ? payload : [];
      return {
        status: 'found',
        phonetic: entries.find((entry) => entry.phonetic)?.phonetic ||
          entries.flatMap((entry) => entry.phonetics || []).find((item) => item.text)?.text || '',
        meanings: entries.flatMap((entry) => entry.meanings || []).flatMap((meaning) =>
          (meaning.definitions || []).slice(0, 3).map((definition) => ({
            partOfSpeech: meaning.partOfSpeech || '',
            definition: definition.definition || '',
            example: definition.example || '',
          })),
        ).slice(0, 8),
      };
    })
    .catch((error) => ({ status: 'failed', error: error?.message || 'Lookup failed' }));
  dictionaryEntries.set(key, request);
  return request;
}

async function renderDictionaryDetails(container, token) {
  container.replaceChildren(node('p', 'muted', 'Đang tra từ điển…'));
  const result = await loadDictionaryEntry(token.lemma || token.surface);
  container.replaceChildren();
  if (result.status === 'failed') {
    container.append(node('p', 'muted', `Không thể tra từ điển: ${result.error}`));
    return;
  }
  if (result.status !== 'found' || !result.meanings.length) {
    container.append(node('p', 'muted', 'Chưa có mục từ điển cho từ này.'));
    return;
  }
  if (result.phonetic) container.append(node('p', 'muted', result.phonetic));
  for (const meaning of result.meanings) {
    const item = node('div', 'definition');
    if (meaning.partOfSpeech) item.append(node('strong', '', meaning.partOfSpeech));
    item.append(node('p', '', meaning.definition));
    if (meaning.example) item.append(node('blockquote', '', meaning.example));
    container.append(item);
  }
}

function renderOverview(result) {
  const analysis = profile(result);
  const stats = analysis.statistics || {};
  const counts = analysis.cefrCounts || {};
  const reviewCount = (analysis.tokens || []).filter((token) =>
    token?.isAcademic || ['B2', 'C1', 'C2'].includes(token?.cefrLevel)
  ).length;
  const section = node('section', 'result-section');
  const metrics = node('div', 'metrics');
  for (const [label, value] of [
    ['Tổng số từ', stats.totalWords ?? 0],
    ['Từ khác nhau', analysis.lexicalDiversity?.uniqueWordCount ?? 0],
    ['Mục cần xem', reviewCount],
    ['Cấu trúc phát hiện', spans(result, 'grammar').length + spans(result, 'collocation').length],
  ]) {
    const item = node('div', 'metric');
    item.append(node('strong', '', value), node('span', '', label));
    metrics.append(item);
  }
  section.append(metrics, node('h3', '', 'Phân bố CEFR'));
  const distribution = node('div', 'distribution');
  for (const level of ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'Unknown']) {
    const count = Number(counts[level] || 0);
    if (!count) continue;
    const chip = node('span', 'level-chip', `${level} ${count}`);
    distribution.append(chip);
  }
  section.append(distribution);
  const warnings = (result.diagnostics || []).filter(Boolean);
  const longSentences = analysis.syntacticComplexity?.longSentences || 0;
  if (longSentences) warnings.push(`${longSentences} câu dài trên 25 từ.`);
  const unknown = Number(counts.Unknown || 0);
  if (unknown) warnings.push(`${unknown} từ chưa được xếp CEFR.`);
  section.append(node('h3', '', 'Cần lưu ý'));
  section.append(warnings.length
    ? node('ul', 'warning-list')
    : node('p', 'muted', 'Không có cảnh báo từ các bộ luật hiện có.'));
  if (warnings.length) warnings.forEach((warning) => section.querySelector('ul').append(node('li', '', warning)));
  return section;
}

function renderVocabulary(result) {
  const section = node('section', 'result-section');
  const controls = node('div', 'list-controls');
  const search = node('input', 'search');
  search.type = 'search'; search.placeholder = 'Tìm từ'; search.setAttribute('aria-label', 'Tìm từ vựng');
  const filter = node('select', 'search'); filter.setAttribute('aria-label', 'Lọc theo CEFR');
  for (const [value, label] of [['all', 'Tất cả mức'], ['review', 'Cần xem'], ['unknown', 'Chưa phân loại'], ...['A1','A2','B1','B2','C1','C2'].map((level) => [level, level])]) {
    const option = node('option', '', label); option.value = value; filter.append(option);
  }
  controls.append(search, filter); section.append(controls);
  const list = node('div', 'analysis-list'); section.append(list);
  const items = (profile(result).tokens || []).filter((token) => token && token.surface);
  const paint = () => {
    list.replaceChildren();
    const query = search.value.trim().toLowerCase();
    const selected = filter.value;
    const filtered = items.filter((token) => {
      const level = token.cefrLevel || 'Unknown';
      if (query && !`${token.surface} ${token.lemma || ''}`.toLowerCase().includes(query)) return false;
      if (selected === 'unknown' && level !== 'Unknown') return false;
      if (selected === 'review' && !(token.isAcademic || ['B2','C1','C2'].includes(level))) return false;
      if (['A1','A2','B1','B2','C1','C2'].includes(selected) && level !== selected) return false;
      return true;
    });
    for (const token of filtered) {
      const row = node('details', 'analysis-row');
      const summary = node('summary');
      summary.append(node('strong', '', token.surface), node('span', 'level-chip', token.cefrLevel || 'Chưa phân loại'));
      if (token.isAcademic) summary.append(node('span', 'tag', 'Học thuật'));
      row.append(summary);
      row.append(node('p', 'muted', `Lemma: ${token.lemma || token.surface} · POS: ${token.pos || 'chưa rõ'} · ${token.lexicalStatus || ''}`));
      const dictionaryPanel = node('div', 'dictionary-details');
      dictionaryPanel.hidden = true;
      row.append(dictionaryPanel);
      row.addEventListener('toggle', () => {
        if (!row.open || row.dataset.dictionaryLoaded) return;
        row.dataset.dictionaryLoaded = 'true';
        dictionaryPanel.hidden = false;
        renderDictionaryDetails(dictionaryPanel, token);
      });
      list.append(row);
    }
    if (!filtered.length) list.append(node('p', 'empty', 'Không tìm thấy từ phù hợp.'));
  };
  search.addEventListener('input', paint); filter.addEventListener('change', paint); paint();
  return section;
}

function renderAnnotations(result, id) {
  const section = node('section', 'result-section');
  const search = node('input', 'search'); search.type = 'search'; search.placeholder = 'Tìm cấu trúc hoặc collocation';
  const list = node('div', 'analysis-list'); section.append(search, list);
  const entries = spans(result, id);
  const paint = () => {
    list.replaceChildren();
    const query = search.value.trim().toLowerCase();
    const filtered = entries.filter((span) => `${span.text} ${metadata(span).label || ''} ${metadata(span).note || ''}`.toLowerCase().includes(query));
    for (const span of filtered) {
      const info = metadata(span);
      const row = node('details', 'analysis-row');
      row.append(node('summary', '', `${info.label || id} · ${span.text || ''}`));
      row.append(node('p', 'muted', info.note || info.description || 'Đã phát hiện trong đoạn văn.'));
      if (info.example) row.append(node('blockquote', '', info.example));
      list.append(row);
    }
    if (!filtered.length) list.append(node('p', 'empty', 'Không tìm thấy kết quả.'));
  };
  search.addEventListener('input', paint); paint(); return section;
}

function renderDifficulty(result) {
  const analysis = profile(result); const stats = analysis.statistics || {};
  const diversity = analysis.lexicalDiversity || {}; const syntax = analysis.syntacticComplexity || {};
  const section = node('section', 'result-section');
  section.append(node('h3', '', 'Độ dài câu'));
  section.append(node('p', '', `${stats.totalSentences ?? 0} câu · trung bình ${Number(stats.avgSentenceLength || 0).toFixed(1)} từ/câu · ${syntax.longSentences || 0} câu dài trên 25 từ.`));
  section.append(node('h3', '', 'Đa dạng từ vựng'));
  section.append(node('p', '', `TTR ${Number(diversity.ttr || 0).toFixed(3)} · MATTR ${Number(diversity.mattr || 0).toFixed(3)} · MTLD ${Number(diversity.mtld || 0).toFixed(2)}`));
  section.append(node('h3', '', 'Chỉ số readability'));
  for (const metric of analysis.readabilityMetrics || []) section.append(node('p', '', `${metric.name}: ${metric.score} (${metric.gradeLevelEquivalent}) — ${metric.limitations || metric.reliabilityNote || ''}`));
  section.append(node('p', 'notice-copy', 'Các chỉ số chỉ mô tả đặc điểm ngôn ngữ bề mặt. Chúng không đo trực tiếp kiến thức nền, mục tiêu đọc hoặc mức độ hiểu của học sinh.'));
  return section;
}

function renderSources() {
  const section = node('section', 'result-section');
  for (const text of [
    'CEFR-J Vocabulary Profile 1.5 (Tono, 2013) và Octanove Vocabulary Profile C1/C2 1.0. Một số nhãn được giữ từ ánh xạ legacy; chúng không phải đánh giá CEFR chính thức cho người học.',
    'CEFR-J yêu cầu trích dẫn và giữ bản quyền; dữ liệu Octanove được ghi nhận theo CC BY-SA 4.0. Hãy kiểm tra attribution trước khi phân phối lại.',
    'Academic Word List của Coxhead (2000) là tín hiệu từ vựng học thuật, không phải nhãn CEFR. Điều khoản phân phối của bản dữ liệu này chưa được xác minh.',
    'Tập từ sinh hoạt hằng ngày được đánh dấu là dữ liệu biên soạn cục bộ; nguồn gốc và điều khoản phân phối chưa rõ. Không dùng nhãn của tập này như bằng chứng xếp trình độ.',
    'Engine chạy ngoại tuyến. Bản dữ liệu được mang từ baseline 116510b; ngày truy xuất và quy trình cập nhật upstream chưa được ghi nhận.',
  ]) section.append(node('p', '', text));
  return section;
}

function render() {
  document.body?.classList.toggle('glass-region-active', Boolean(latestResult));
  if (!latestResult) return;
  resultsNode.replaceChildren();
  const renderers = {
    overview: () => renderOverview(latestResult),
    vocabulary: () => renderVocabulary(latestResult),
    grammar: () => {
      const section = node('section'); section.append(node('h3', '', 'Ngữ pháp'), renderAnnotations(latestResult, 'grammar'), node('h3', '', 'Collocation'), renderAnnotations(latestResult, 'collocation')); return section;
    },
    difficulty: () => renderDifficulty(latestResult),
    sources: renderSources,
  };
  resultsNode.append(renderers[activeSection]());
}

async function analyzeText(text, providedResult = null) {
  const cleaned = String(text || '').trim();
  if (!cleaned) { statusNode.textContent = 'Nhập hoặc chọn một đoạn văn trước.'; return; }
  const generation = ++renderGeneration;
  sourceInput.value = cleaned;
  analyzeButton.disabled = true; statusNode.textContent = 'Đang phân tích…';
  try {
    if (providedResult) latestResult = providedResult;
    else {
      const port = Number(new URLSearchParams(location.search).get('port'));
      if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Không tìm thấy cổng engine do host cấp.');
      const requestId = `ui-${Date.now()}-${++requestSequence}`;
      const selectionToken = `ui-selection-${requestSequence}`;
      const response = await fetch(`http://127.0.0.1:${port}/api/analyze`, {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ schemaVersion: 1, requestId, selectionToken, source: { kind: 'text', text: cleaned, offsetUnit: 'unicodeCodePoint' } }),
      });
      latestResult = await response.json();
      if (!response.ok || latestResult.status !== 'complete' || latestResult.requestId !== requestId || latestResult.selectionToken !== selectionToken) throw new Error(latestResult.error || 'Phân tích thất bại.');
    }
    if (generation !== renderGeneration) return;
    statusNode.textContent = 'Phân tích hoàn tất'; render();
  } catch (error) {
    if (generation !== renderGeneration) return;
    latestResult = null; resultsNode.replaceChildren(node('p', 'empty', error?.message || 'Không thể kết nối engine.'));
    document.body?.classList.remove('glass-region-active');
    statusNode.textContent = 'Engine chưa sẵn sàng';
  } finally { if (generation === renderGeneration) analyzeButton.disabled = false; }
}

analyzeButton.addEventListener('click', () => analyzeText(sourceInput.value));
document.querySelector?.('#sections')?.addEventListener('click', (event) => {
  const button = event.target.closest('button[data-section]'); if (!button) return;
  activeSection = button.dataset.section;
  document.querySelectorAll('#sections button').forEach((item) => item.classList.toggle('selected', item === button));
  render();
});
window.onSnippetCaptured = (text, _target, result) => analyzeText(text, result);
