/**
 * Central State Store (Single Source of Truth) for Học Lực Math Studio
 * Implements Action-Reducer-Subscriber pattern to eliminate global state in app.js
 */

import { analyzeFunction } from './math_cas.js';
import { solveIntegral } from './integral_solver.js';
import { computeFormulaFromDrag } from './curve_manipulator.js';

export class MathStudioStore {
  constructor(initialState = {}) {
    this.state = {
      formula: 'x^3 - 3*x',
      derFormulaLatex: "y' = 3x^2 - 3",
      derFormulaDisplay: "y' = 3x^2 - 3",
      analysis: null,
      integral: null,
      activeView: 'graph', // 'graph' | 'bbt' | 'geometry3d' | 'integral'
      bounds: { xMin: -6, xMax: 6, yMin: -4.1, yMax: 4.1 },
      tickSteps: { stepX: 2, stepY: 2 },
      markedPoints: [],
      showExtrema: true,
      showOxIntercept: false,
      showOyIntercept: false,
      integralBounds: { a: -1, b: 2 },
      editingStickerId: null,
      isRevolved: false,
      geom3dPreset: 'pyramid_tri',
      statusMsg: 'Học Lực Math Engine: Hợp lệ',
      isError: false,
      ...initialState
    };
    this.subscribers = new Set();
    this.init();
  }

  init() {
    this.recomputeAnalysis(this.state.formula, { keepBounds: false });
  }

  getState() {
    return this.state;
  }

  subscribe(listener) {
    this.subscribers.add(listener);
    return () => this.subscribers.delete(listener);
  }

  notify(changedKeys = []) {
    for (const listener of this.subscribers) {
      try {
        listener(this.state, changedKeys);
      } catch (err) {
        console.error('Lỗi subscriber Store:', err);
      }
    }
  }

  recomputeAnalysis(rawFormula, options = {}) {
    const { keepBounds = true } = options;
    const cleanFormula = rawFormula ? rawFormula.trim() : '';
    if (!cleanFormula) {
      this.state.formula = '';
      this.state.analysis = null;
      this.state.integral = null;
      this.state.derFormulaLatex = '';
      this.state.derFormulaDisplay = '';
      this.state.statusMsg = 'Chờ nhập hàm số';
      this.state.isError = false;
      this.notify(['formula', 'analysis', 'integral', 'status']);
      return;
    }

    try {
      const bounds = this.state.bounds;
      const ana = analyzeFunction(cleanFormula, bounds);
      this.state.formula = cleanFormula;
      this.state.analysis = ana;
      this.state.derFormulaLatex = ana.derLatex || "y' = f'(x)";
      this.state.derFormulaDisplay = ana.derDisplay || "y' = f'(x)";
      this.state.statusMsg = 'Học Lực Math Engine: Hợp lệ';
      this.state.isError = false;

      if (!keepBounds && ana.bounds) {
        this.state.bounds = { ...ana.bounds };
      }

      this.recomputeIntegral();
      this.notify(['formula', 'analysis', 'integral', 'bounds', 'status']);
    } catch (err) {
      this.state.analysis = null;
      this.state.statusMsg = `Lỗi biểu thức: ${err.message}`;
      this.state.isError = true;
      this.notify(['formula', 'analysis', 'error', 'status']);
    }
  }

  recomputeIntegral() {
    if (!this.state.analysis) {
      this.state.integral = null;
      return;
    }
    const { a, b } = this.state.integralBounds;
    this.state.integral = solveIntegral(this.state.analysis, a, b);
  }

  dispatch(action) {
    if (!action || !action.type) return;

    switch (action.type) {
      case 'SET_FORMULA':
        this.recomputeAnalysis(action.formula, { keepBounds: action.keepBounds ?? true });
        break;

      case 'SET_VIEW':
        if (this.state.activeView !== action.view) {
          this.state.activeView = action.view;
          this.notify(['activeView']);
        }
        break;

      case 'SET_BOUNDS':
        this.state.bounds = { ...this.state.bounds, ...action.bounds };
        if (action.tickSteps) {
          this.state.tickSteps = { ...this.state.tickSteps, ...action.tickSteps };
        }
        this.recomputeAnalysis(this.state.formula, { keepBounds: true });
        this.notify(['bounds', 'tickSteps']);
        break;

      case 'UPDATE_INTEGRAL_BOUND':
        if (action.bound === 'a') this.state.integralBounds.a = action.val;
        if (action.bound === 'b') this.state.integralBounds.b = action.val;
        this.recomputeIntegral();
        this.notify(['integral', 'integralBounds']);
        break;

      case 'UPDATE_DRAG_EXTREMUM': {
        const { idx, newX, newY } = action;
        if (!this.state.analysis) return;
        const newFormula = computeFormulaFromDrag(this.state.analysis, { type: 'extremum', idx }, newX, newY);
        if (newFormula && newFormula !== this.state.formula) {
          this.recomputeAnalysis(newFormula, { keepBounds: true });
        }
        break;
      }

      case 'TOGGLE_POINT_MARK':
        if (action.target === 'extrema') this.state.showExtrema = !this.state.showExtrema;
        if (action.target === 'ox') this.state.showOxIntercept = !this.state.showOxIntercept;
        if (action.target === 'oy') this.state.showOyIntercept = !this.state.showOyIntercept;
        this.notify(['markedPoints', 'pointToggles']);
        break;

      case 'ADD_MARKED_POINT':
        this.state.markedPoints.push(action.point);
        this.notify(['markedPoints']);
        break;

      case 'SET_GEOM3D_PRESET':
        this.state.geom3dPreset = action.preset;
        this.notify(['geom3dPreset']);
        break;

      case 'TOGGLE_REVOLVED':
        this.state.isRevolved = !this.state.isRevolved;
        this.notify(['isRevolved']);
        break;

      case 'LOAD_STICKER':
        if (action.stickerId) this.state.editingStickerId = action.stickerId;
        if (action.formula) {
          this.recomputeAnalysis(action.formula, { keepBounds: false });
        }
        this.notify(['editingStickerId', 'formula', 'analysis']);
        break;
    }
  }

  getCombinedMarkedPoints() {
    const pts = [...this.state.markedPoints];
    const ana = this.state.analysis;
    if (!ana) return pts;

    if (this.state.showOyIntercept && ana.intercepts && ana.intercepts.oy) {
      pts.push({ ...ana.intercepts.oy, color: '#16a34a' });
    }
    if (this.state.showOxIntercept && ana.intercepts && ana.intercepts.ox) {
      ana.intercepts.ox.forEach(p => pts.push({ ...p, color: '#2563eb' }));
    }
    return pts;
  }
}

export const store = new MathStudioStore();

