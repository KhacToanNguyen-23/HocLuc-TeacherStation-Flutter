/**
 * Học Lực Math Studio — Clean Modular Application Entrypoint
 * Dedicated Board per Tab & Elevated Fixed Sidebar
 * Compliant with Clean Architecture & <= 250-320 lines invariant.
 */

import { store } from './core/store.js';
import { generateBbtSvg } from './render/bbt_generator.js';
import { renderJSXGraphBoard, destroyJSXGraphBoard } from './board/graph_board.js';
import { renderJSXGraph3D, destroy3DBoard } from './board/view_3d_board.js';
import { pinLiveBoardToChalkboard } from './export/board_exporter.js';
import { insertToBoard } from './render/export_helper.js';

// DOM Elements: Sidebar Cards
const functionControlCard = document.getElementById('functionControlCard');
const pointsControlCard = document.getElementById('pointsControlCard');
const integralControlCard = document.getElementById('integralControlCard');
const geom3dControlCard = document.getElementById('geom3dControlCard');
const advancedAccordionCard = document.getElementById('advancedAccordionCard');

// DOM Elements: Dedicated Preview Panels
const graphBoardPanel = document.getElementById('graphBoardPanel');
const bbtBoardPanel = document.getElementById('bbtBoardPanel');
const geom3dBoardPanel = document.getElementById('geom3dBoardPanel');
const integralBoardPanel = document.getElementById('integralBoardPanel');

const graphContainer = document.getElementById('graphContainer');
const bbtContainer = document.getElementById('bbtContainer');
const geometry3dContainer = document.getElementById('geometry3dContainer');
const integralGraphContainer = document.getElementById('integralGraphContainer');

// Inputs & Buttons
const mathInput = document.getElementById('mathInput');
const btnClearFormula = document.getElementById('btnClearFormula');
const derFormulaBadge = document.getElementById('derFormulaBadge');
const statusInfo = document.getElementById('statusInfo');
const toastEl = document.getElementById('toast');

const btnAddPoint = document.getElementById('btnAddPoint');
const btnOxIntercept = document.getElementById('btnOxIntercept');
const btnOyIntercept = document.getElementById('btnOyIntercept');
const btnExtrema = document.getElementById('btnExtrema');
const extremaEditorContainer = document.getElementById('extremaEditorContainer');

const btnToggleAdvanced = document.getElementById('btnToggleAdvanced');
const advancedAccordionBody = document.getElementById('advancedAccordionBody');
const advancedArrow = document.getElementById('advancedArrow');

const viewXMin = document.getElementById('viewXMin');
const viewXMax = document.getElementById('viewXMax');
const viewYMin = document.getElementById('viewYMin');
const viewYMax = document.getElementById('viewYMax');
const viewStepX = document.getElementById('viewStepX');
const viewStepY = document.getElementById('viewStepY');

const modeTabs = document.querySelectorAll('.mode-tab[data-view]');
const shapeBtns = document.querySelectorAll('.shape-pill[data-preset]');
const boundAInput = document.getElementById('boundA');
const boundBInput = document.getElementById('boundB');
const btnRecalcIntegral = document.getElementById('btnRecalcIntegral');
const intFormulaDisplay = document.getElementById('intFormulaDisplay');
const intAreaResult = document.getElementById('intAreaResult');

const btnCloseDialog = document.getElementById('btnCloseDialog');
const btnCancelDialog = document.getElementById('btnCancelDialog');
const btnDoneDialog = document.getElementById('btnDoneDialog');

let isAddPointMode = false;

// 1. Toast Notification
function showToast(msg) {
  if (!toastEl) return;
  toastEl.textContent = msg;
  toastEl.classList.add('show');
  setTimeout(() => toastEl.classList.remove('show'), 2000);
}

// 2. View Rendering
function renderCurrentView(state) {
  const { activeView, analysis, integral, bounds, tickSteps, showExtrema, showOxIntercept, showOyIntercept } = state;

  // A. Bảng thông số nổi bên trái: ĐỨNG CỨNG, tự thích ứng hiển thị theo Tab
  if (functionControlCard) functionControlCard.classList.toggle('hidden', activeView === 'geometry3d');
  if (pointsControlCard) pointsControlCard.classList.toggle('hidden', activeView !== 'graph');
  if (integralControlCard) integralControlCard.classList.toggle('hidden', activeView !== 'integral');
  if (geom3dControlCard) geom3dControlCard.classList.toggle('hidden', activeView !== 'geometry3d');
  if (advancedAccordionCard) advancedAccordionCard.classList.toggle('hidden', activeView === 'geometry3d' || activeView === 'bbt');

  // B. Bảng đồ thị bên phải: MỖI BẢNG LÀ 1 ĐỒ THỊ RIÊNG BIỆT (Dedicated Boards)
  if (graphBoardPanel) graphBoardPanel.classList.toggle('hidden', activeView !== 'graph');
  if (bbtBoardPanel) bbtBoardPanel.classList.toggle('hidden', activeView !== 'bbt');
  if (geom3dBoardPanel) geom3dBoardPanel.classList.toggle('hidden', activeView !== 'geometry3d');
  if (integralBoardPanel) integralBoardPanel.classList.toggle('hidden', activeView !== 'integral');

  // C. Toggles & Badge
  if (btnExtrema) btnExtrema.classList.toggle('active', showExtrema);
  if (btnOxIntercept) btnOxIntercept.classList.toggle('active', showOxIntercept);
  if (btnOyIntercept) btnOyIntercept.classList.toggle('active', showOyIntercept);

  if (derFormulaBadge) {
    derFormulaBadge.textContent = state.derFormulaDisplay || '';
    derFormulaBadge.style.display = state.derFormulaDisplay ? 'inline-block' : 'none';
  }

  if (statusInfo) {
    statusInfo.textContent = state.statusMsg;
    statusInfo.classList.toggle('error', state.isError);
  }

  // D. Render từng Board riêng biệt
  // Board 1: Đồ thị 2D thuần túy
  if (activeView === 'graph') {
    if (analysis && graphContainer && typeof window !== 'undefined' && window.JXG) {
      renderJSXGraphBoard('graphContainer', analysis, null, {
        theme: 'light',
        bounds,
        tickStepX: tickSteps.stepX,
        tickStepY: tickSteps.stepY,
        markedPoints: store.getCombinedMarkedPoints(),
        onExtremumDrag: (ext, idx, newX, newY) => {
          store.dispatch({ type: 'UPDATE_DRAG_EXTREMUM', idx, newX, newY });
        }
      });
    }
  }

  // Board 2: Bảng biến thiên SGK độc lập
  if (activeView === 'bbt' && analysis && bbtContainer) {
    bbtContainer.innerHTML = generateBbtSvg(analysis, {
      width: bbtContainer.clientWidth || 540,
      height: 280,
      theme: 'paper'
    });
  }

  // Board 3: Hình học 3D SGK (JSXGraph View3D) độc lập
  if (activeView === 'geometry3d') {
    if (geometry3dContainer && typeof window !== 'undefined' && window.JXG) {
      renderJSXGraph3D('geometry3dContainer', state.geom3dPreset || 'pyramid_quad', { theme: 'light' });
    }
  }

  // Board 4: Tích phân & Diện tích riêng biệt
  if (activeView === 'integral') {
    if (analysis && integralGraphContainer && typeof window !== 'undefined' && window.JXG) {
      renderJSXGraphBoard('integralGraphContainer', analysis, integral, {
        theme: 'light',
        bounds,
        tickStepX: tickSteps.stepX,
        tickStepY: tickSteps.stepY,
        onBoundChange: (bound, val) => {
          store.dispatch({ type: 'UPDATE_INTEGRAL_BOUND', bound, val });
        }
      });
    }
  }

  // Extrema list
  renderExtremaEditor(state);

  // Integral numbers
  if (integral) {
    if (boundAInput && document.activeElement !== boundAInput) boundAInput.value = state.integralBounds.a;
    if (boundBInput && document.activeElement !== boundBInput) boundBInput.value = state.integralBounds.b;
    if (intFormulaDisplay) intFormulaDisplay.innerHTML = integral.formulaHtml || integral.formulaDisplay;
    if (intAreaResult) intAreaResult.textContent = `S ≈ ${integral.displayArea}`;
  }
}

function renderExtremaEditor(state) {
  if (!extremaEditorContainer) return;
  const { showExtrema, analysis } = state;
  if (!showExtrema || !analysis || !analysis.extrema || analysis.extrema.length === 0) {
    extremaEditorContainer.innerHTML = '';
    return;
  }
  let html = '';
  analysis.extrema.forEach((ext) => {
    const badgeClass = ext.type === 'CĐ' ? 'cd' : 'ct';
    html += `
      <div class="ext-row">
        <span class="ext-badge ${badgeClass}">${ext.type}</span>
        <div class="ext-coord-inputs">
          <span class="ext-coord-label">x: <span class="ext-val">${ext.displayX}</span></span>
          <span class="ext-coord-label">y: <span class="ext-val">${ext.displayY}</span></span>
        </div>
      </div>
    `;
  });
  extremaEditorContainer.innerHTML = html;
}

// 3. User Interaction Listeners
function setupListeners() {
  if (mathInput) {
    mathInput.addEventListener('input', () => store.dispatch({ type: 'SET_FORMULA', formula: mathInput.value }));
  }

  if (btnClearFormula) {
    btnClearFormula.addEventListener('click', () => {
      if (mathInput) { mathInput.value = ''; mathInput.focus(); }
      store.dispatch({ type: 'SET_FORMULA', formula: '' });
    });
  }

  modeTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      modeTabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      store.dispatch({ type: 'SET_VIEW', view: tab.dataset.view });
    });
  });

  if (btnExtrema) btnExtrema.addEventListener('click', () => store.dispatch({ type: 'TOGGLE_POINT_MARK', target: 'extrema' }));
  if (btnOxIntercept) btnOxIntercept.addEventListener('click', () => store.dispatch({ type: 'TOGGLE_POINT_MARK', target: 'ox' }));
  if (btnOyIntercept) btnOyIntercept.addEventListener('click', () => store.dispatch({ type: 'TOGGLE_POINT_MARK', target: 'oy' }));

  if (btnAddPoint) {
    btnAddPoint.addEventListener('click', () => {
      isAddPointMode = !isAddPointMode;
      btnAddPoint.classList.toggle('active', isAddPointMode);
      showToast(isAddPointMode ? 'Nhấp vào đồ thị để gắn điểm' : 'Đã tắt gắn điểm');
    });
  }

  if (btnToggleAdvanced && advancedAccordionBody) {
    btnToggleAdvanced.addEventListener('click', () => {
      advancedAccordionBody.classList.toggle('hidden');
      if (advancedArrow) {
        advancedArrow.textContent = advancedAccordionBody.classList.contains('hidden') ? '▾' : '▴';
      }
    });
  }

  [viewXMin, viewXMax, viewYMin, viewYMax, viewStepX, viewStepY].forEach(inp => {
    if (inp) inp.addEventListener('change', () => {
      const xMin = parseFloat(viewXMin?.value);
      const xMax = parseFloat(viewXMax?.value);
      const yMin = parseFloat(viewYMin?.value);
      const yMax = parseFloat(viewYMax?.value);
      const sX = parseFloat(viewStepX?.value);
      const sY = parseFloat(viewStepY?.value);
      if (xMin < xMax && yMin < yMax && sX > 0 && sY > 0) {
        store.dispatch({ type: 'SET_BOUNDS', bounds: { xMin, xMax, yMin, yMax }, tickSteps: { stepX: sX, stepY: sY } });
      }
    });
  });

  shapeBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      shapeBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      store.dispatch({ type: 'SET_GEOM3D_PRESET', preset: btn.dataset.preset });
      showToast(`Mô hình: ${btn.textContent.trim()}`);
    });
  });

  if (btnRecalcIntegral) {
    btnRecalcIntegral.addEventListener('click', () => {
      const a = parseFloat(boundAInput?.value) || -1;
      const b = parseFloat(boundBInput?.value) || 2;
      store.dispatch({ type: 'UPDATE_INTEGRAL_BOUND', bound: 'a', val: a });
      store.dispatch({ type: 'UPDATE_INTEGRAL_BOUND', bound: 'b', val: b });
      showToast('Đã cập nhật tích phân');
    });
  }

  // Hướng 3: Ghim đúng bảng tương ứng với Tab hiện tại
  const handlePin = async () => {
    const state = store.getState();
    const { activeView, analysis, editingStickerId } = state;
    if (activeView !== 'geometry3d' && !analysis) { showToast('Vui lòng nhập hàm số trước'); return; }

    try {
      if (activeView === 'bbt') {
        const svg = generateBbtSvg(analysis, { width: 540, height: 260, theme: 'chalkboard' });
        await insertToBoard({
          stickerId: editingStickerId,
          title: `Bảng biến thiên: ${analysis.formulaLatex}`,
          rawText: `Bảng biến thiên: ${analysis.formulaLatex}`,
          svgContent: svg,
          aspectRatio: 540 / 260
        });
      } else if (activeView === 'integral') {
        await pinLiveBoardToChalkboard({
          containerId: 'integralGraphContainer',
          editingStickerId,
          title: `Tích phân S = ${state.integral ? state.integral.displayArea : ''}: ${analysis.formulaLatex}`,
          rawText: `Tích phân S: ${analysis.formulaLatex}`
        });
      } else if (activeView === 'geometry3d') {
        await pinLiveBoardToChalkboard({
          containerId: 'geometry3dContainer',
          editingStickerId,
          title: `Hình 3D SGK: ${state.geom3dPreset || '3D'}`,
          rawText: `Hình 3D SGK`
        });
      } else {
        await pinLiveBoardToChalkboard({
          containerId: 'graphContainer',
          editingStickerId,
          title: `Đồ thị: ${analysis.formulaLatex}`,
          rawText: `Đồ thị: ${analysis.formulaLatex}`
        });
      }
      showToast(editingStickerId ? 'Đã cập nhật lên bảng' : 'Đã ghim lên bảng');
    } catch (err) {
      showToast(`Lỗi ghim lên bảng: ${err.message}`);
    }
  };

  if (btnDoneDialog) btnDoneDialog.addEventListener('click', handlePin);
  window.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); handlePin(); }
  });

  const closeDialog = () => { if (typeof window.HocLuc !== 'undefined') window.HocLuc.close(); };
  if (btnCloseDialog) btnCloseDialog.addEventListener('click', closeDialog);
  if (btnCancelDialog) btnCancelDialog.addEventListener('click', closeDialog);
}

// 4. Initialization
document.addEventListener('DOMContentLoaded', () => {
  setupListeners();

  store.subscribe((state) => {
    if (mathInput && document.activeElement !== mathInput && state.formula !== mathInput.value) {
      mathInput.value = state.formula;
    }
    renderCurrentView(state);
  });

  // Initial render
  renderCurrentView(store.getState());

  if (typeof window.HocLuc !== 'undefined') {
    window.HocLuc.onMessage((msg) => {
      if (msg && (msg.action === 'edit' || msg.type === 'edit')) {
        store.dispatch({
          type: 'LOAD_STICKER',
          stickerId: msg.stickerId || msg.id,
          formula: msg.formula || (msg.metadata && msg.metadata.formula)
        });
      }
    });
  }
});
