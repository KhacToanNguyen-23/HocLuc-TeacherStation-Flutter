/**
 * Học Lực Math Studio — Interactive JSXGraph Board Manager
 * Dedicated module for managing JSXGraph board lifecycle, coordinate grid,
 * axes, function curves, extrema, asymptotes, and integral glider layers.
 */

// Global cache to track JSXGraph boards by container ID
const activeBoards = new Map();

/**
 * Destroy existing JSXGraph board instance on container
 */
export function destroyJSXGraphBoard(container) {
  if (typeof window === 'undefined' || !window.JXG) return;
  const containerId = typeof container === 'string' ? container : container?.id;
  if (!containerId) return;

  const existingBoard = activeBoards.get(containerId);
  if (existingBoard) {
    try {
      window.JXG.JSXGraph.freeBoard(existingBoard);
    } catch (_) {}
    activeBoards.delete(containerId);
  }
}

/**
 * Render or Update Interactive JSXGraph Board
 */
export function renderJSXGraphBoard(container, analysis, integralResult = null, options = {}) {
  if (typeof window === 'undefined' || !window.JXG || !analysis) {
    return null;
  }

  const containerEl = typeof container === 'string' ? document.getElementById(container) : container;
  if (!containerEl) return null;
  const containerId = containerEl.id;

  // Cleanup prior board
  destroyJSXGraphBoard(containerId);

  const {
    theme = 'light',
    bounds = null,
    tickStepX = 2,
    tickStepY = 2,
    curveColor = null,
    markedPoints = [],
    onBoundChange = null
  } = options;

  const isChalkboard = theme === 'chalkboard';
  const isDark = theme === 'dark';
  const activeCurveColor = curveColor || (isChalkboard ? '#DC2626' : isDark ? '#f87171' : '#d32f2f');

  const colors = {
    bg: isChalkboard ? 'transparent' : isDark ? '#151722' : '#ffffff',
    grid: isChalkboard ? 'rgba(255, 255, 255, 0.12)' : isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(15, 23, 42, 0.08)',
    axis: isChalkboard ? '#ffffff' : isDark ? '#cbd5e1' : '#0f172a',
    axisLabel: isChalkboard ? '#f1f5f9' : isDark ? '#cbd5e1' : '#1f2937',
    curve: activeCurveColor,
    asymptote: isChalkboard ? '#fde047' : isDark ? '#fab387' : '#526984',
    extremumDot: isChalkboard ? '#1D4ED8' : isDark ? '#f38ba8' : '#0b3a82',
    projection: isChalkboard ? 'rgba(255, 255, 255, 0.50)' : 'rgba(100, 116, 139, 0.70)',
    integralFill: isChalkboard ? 'rgba(220, 38, 38, 0.22)' : isDark ? 'rgba(250, 179, 135, 0.35)' : 'rgba(224, 36, 36, 0.16)'
  };

  // Determine viewport bounds
  let xMin = bounds?.xMin ?? -6;
  let xMax = bounds?.xMax ?? 6;
  let yMin = bounds?.yMin ?? -4.1;
  let yMax = bounds?.yMax ?? 4.1;

  if (!bounds && analysis.extrema && analysis.extrema.length > 0) {
    const validYs = analysis.extrema.map(e => e.y).filter(y => isFinite(y) && Math.abs(y) <= 25);
    const xs = analysis.extrema.map(e => e.x).filter(x => isFinite(x) && Math.abs(x) <= 25);

    if (xs.length > 0) {
      xMin = Math.max(-12, Math.min(xMin, Math.min(...xs) - 2.5));
      xMax = Math.min(12, Math.max(xMax, Math.max(...xs) + 2.5));
    }
    if (validYs.length > 0) {
      yMin = Math.max(-10, Math.min(yMin, Math.min(...validYs) - 2.5));
      yMax = Math.min(10, Math.max(yMax, Math.max(...validYs) + 2.5));
    }
  }

  containerEl.classList.add('jxgbox');
  containerEl.style.backgroundColor = colors.bg;

  const board = window.JXG.JSXGraph.initBoard(containerId, {
    boundingbox: [xMin, yMax, xMax, yMin],
    axis: false,
    grid: false,
    showNavigation: false,
    showCopyright: false,
    keepaspectratio: false,
    text: { display: 'internal' },
    pan: { enabled: true, needShift: false },
    zoom: { factorX: 1.25, factorY: 1.25, wheel: true, needShift: false },
    defaultAxes: {
      x: { visible: false },
      y: { visible: false }
    }
  });

  activeBoards.set(containerId, board);

  // 1. SGK Coordinate Grid
  const sX = (tickStepX && tickStepX > 0) ? tickStepX : 2;
  const sY = (tickStepY && tickStepY > 0) ? tickStepY : 2;

  const gridObj = board.create('grid', [], {
    gridX: sX,
    gridY: sY,
    strokeColor: colors.grid,
    strokeWidth: 0.8,
    strokeOpacity: 1,
    highlight: false
  });
  if (gridObj && gridObj.rendNode) {
    gridObj.rendNode.setAttribute('data-export-grid', 'true');
  }

  // 2. SGK Axes with Gold-Ratio Arrows & Typography
  const xaxis = board.create('axis', [[0, 0], [1, 0]], {
    strokeColor: colors.axis,
    strokeWidth: 1.5,
    name: 'x',
    withLabel: true,
    highlight: false,
    label: {
      position: 'rt',
      offset: [-16, 12],
      color: colors.axis,
      fontSize: 13,
      cssClass: 'sgk-axis-label'
    },
    ticks: {
      ticksDistance: sX,
      minorTicks: 0,
      insertTicks: false,
      strokeColor: colors.axis,
      strokeWidth: 1.2,
      majorHeight: 6,
      drawZero: false,
      drawLabels: true,
      label: {
        color: colors.axisLabel,
        fontSize: 12,
        fontWeight: 'bold',
        offset: [-4, -14],
        cssClass: 'sgk-tick-label'
      }
    }
  });

  const yaxis = board.create('axis', [[0, 0], [0, 1]], {
    strokeColor: colors.axis,
    strokeWidth: 1.5,
    name: 'y',
    withLabel: true,
    highlight: false,
    label: {
      position: 'rt',
      offset: [12, -12],
      color: colors.axis,
      fontSize: 13,
      cssClass: 'sgk-axis-label'
    },
    ticks: {
      ticksDistance: sY,
      minorTicks: 0,
      insertTicks: false,
      strokeColor: colors.axis,
      strokeWidth: 1.2,
      majorHeight: 6,
      drawZero: false,
      drawLabels: true,
      label: {
        color: colors.axisLabel,
        fontSize: 12,
        fontWeight: 'bold',
        offset: [-18, -4],
        cssClass: 'sgk-tick-label'
      }
    }
  });

  // Origin 'O'
  board.create('text', [-0.35, -0.35, 'O'], {
    color: colors.axis,
    fontSize: 12,
    fontWeight: 'bold',
    fixed: true,
    highlight: false
  });

  // 3. Dynamic Function Curve Layer
  const getCurveVal = (x) => {
    if (typeof options.getEval === 'function') {
      const liveFn = options.getEval();
      if (typeof liveFn === 'function') {
        const val = liveFn(x);
        if (typeof val === 'number' && !isNaN(val)) return val;
      }
    }
    return analysis.eval(x);
  };

  let mainCurve = null;

  if (analysis.tableData?.hasSingularity) {
    const x0 = analysis.tableData.singularX;
    const delta = 0.005;
    board.create('functiongraph', [getCurveVal, () => board.getBoundingBox()[0], x0 - delta], {
      strokeColor: colors.curve,
      strokeWidth: 2.2,
      highlight: false
    });
    mainCurve = board.create('functiongraph', [getCurveVal, x0 + delta, () => board.getBoundingBox()[2]], {
      strokeColor: colors.curve,
      strokeWidth: 2.2,
      highlight: false
    });
  } else {
    mainCurve = board.create('functiongraph', [getCurveVal, () => board.getBoundingBox()[0], () => board.getBoundingBox()[2]], {
      strokeColor: colors.curve,
      strokeWidth: 2.2,
      highlight: false
    });
  }

  // 4. Asymptotes for Rational Functions
  if (analysis.asymptotes) {
    analysis.asymptotes.forEach(asym => {
      if (asym.isVertical) {
        board.create('line', [[asym.val, 0], [asym.val, 1]], {
          strokeColor: colors.asymptote,
          strokeWidth: 1.5,
          dash: 2,
          fixed: true,
          highlight: false,
          name: asym.eq,
          withLabel: true,
          label: { position: 'top', color: colors.asymptote, fontSize: 10, fontWeight: 'bold' }
        });
      } else if (asym.isHorizontal) {
        board.create('line', [[0, asym.val], [1, asym.val]], {
          strokeColor: colors.asymptote,
          strokeWidth: 1.5,
          dash: 2,
          fixed: true,
          highlight: false,
          name: asym.eq,
          withLabel: true,
          label: { position: 'rt', offset: [-50, -10], color: colors.asymptote, fontSize: 10, fontWeight: 'bold' }
        });
      } else if (asym.isOblique) {
        board.create('line', [[0, asym.beta], [1, asym.alpha + asym.beta]], {
          strokeColor: colors.asymptote,
          strokeWidth: 1.5,
          dash: 2,
          fixed: true,
          highlight: false,
          name: asym.eq,
          withLabel: true,
          label: { position: 'rt', offset: [-50, -10], color: colors.asymptote, fontSize: 10, fontWeight: 'bold' }
        });
      }
    });
  }

  // 5. SGK Projection Lines and White-Rim Extrema
  if (analysis.extrema) {
    analysis.extrema.forEach((ext, idx) => {
      const extPt = board.create('point', [ext.x, ext.y], {
        name: '',
        withLabel: false,
        size: 5,
        fillColor: colors.extremumDot,
        strokeColor: '#ffffff',
        strokeWidth: 2.2,
        fixed: false,
        highlight: true
      });

      const isCT = ext.type === 'CT';
      const offsetY = isCT ? -18 : 16;

      const extLabel = board.create('text', [
        () => extPt.X(),
        () => extPt.Y(),
        () => `${ext.type} (${extPt.X().toFixed(1)}; ${extPt.Y().toFixed(1)})`
      ], {
        offset: [0, offsetY],
        anchorX: 'middle',
        color: colors.extremumDot,
        strokeWidth: 0,
        fontSize: 11.5,
        fontWeight: 'bold',
        cssStyle: 'paint-order: stroke; stroke: #ffffff; stroke-width: 3px; stroke-linejoin: round; font-weight: 700;',
        fixed: true,
        highlight: false
      });
      if (extLabel && extLabel.rendNode) {
        extLabel.rendNode.setAttribute('data-label-role', 'extremum');
      }

      board.create('segment', [
        [() => extPt.X(), 0],
        [() => extPt.X(), () => extPt.Y()]
      ], {
        strokeColor: colors.projection,
        strokeWidth: 1.1,
        dash: 2,
        fixed: true,
        highlight: false
      });

      board.create('segment', [
        [0, () => extPt.Y()],
        [() => extPt.X(), () => extPt.Y()]
      ], {
        strokeColor: colors.projection,
        strokeWidth: 1.1,
        dash: 2,
        fixed: true,
        highlight: false
      });

      if (typeof options.onExtremumDrag === 'function') {
        extPt.on('drag', () => {
          options.onExtremumDrag(ext, idx, extPt.X(), extPt.Y(), board);
        });
      }
    });
  }

  // 6. Translucent Integral Area & Draggable Bound Gliders
  if (integralResult && typeof integralResult.a === 'number' && typeof integralResult.b === 'number' && mainCurve) {
    let aVal = integralResult.a;
    let bVal = integralResult.b;

    const gliderA = board.create('glider', [aVal, 0, xaxis], {
      name: '',
      withLabel: false,
      size: 5,
      fillColor: colors.curve,
      strokeColor: '#ffffff',
      strokeWidth: 2,
      fixed: false
    });
    if (gliderA && gliderA.rendNode) {
      gliderA.rendNode.setAttribute('data-export-ignore', 'true');
    }

    const gliderB = board.create('glider', [bVal, 0, xaxis], {
      name: '',
      withLabel: false,
      size: 5,
      fillColor: colors.curve,
      strokeColor: '#ffffff',
      strokeWidth: 2,
      fixed: false
    });
    if (gliderB && gliderB.rendNode) {
      gliderB.rendNode.setAttribute('data-export-ignore', 'true');
    }

    board.create('integral', [[() => Math.min(gliderA.X(), gliderB.X()), () => Math.max(gliderA.X(), gliderB.X())], mainCurve], {
      fillColor: colors.integralFill,
      fillOpacity: 0.85,
      strokeWidth: 0,
      highlight: false
    });

    const lblA = board.create('text', [() => gliderA.X(), -0.45, () => `a = ${gliderA.X().toFixed(1)}`], {
      anchorX: 'middle',
      fontSize: 11,
      fontWeight: 'bold',
      color: colors.curve,
      strokeWidth: 0,
      cssStyle: 'paint-order: stroke; stroke: #ffffff; stroke-width: 3px; stroke-linejoin: round; font-weight: 700;',
      highlight: false
    });
    if (lblA && lblA.rendNode) lblA.rendNode.setAttribute('data-label-role', 'bound');

    const lblB = board.create('text', [() => gliderB.X(), -0.45, () => `b = ${gliderB.X().toFixed(1)}`], {
      anchorX: 'middle',
      fontSize: 11,
      fontWeight: 'bold',
      color: colors.curve,
      strokeWidth: 0,
      cssStyle: 'paint-order: stroke; stroke: #ffffff; stroke-width: 3px; stroke-linejoin: round; font-weight: 700;',
      highlight: false
    });
    if (lblB && lblB.rendNode) lblB.rendNode.setAttribute('data-label-role', 'bound');

    const dispatchBound = (boundName, gliderObj, isDragging) => {
      const x = gliderObj.X();
      if (typeof options.onBoundChange === 'function') {
        options.onBoundChange(boundName, Number(x.toFixed(1)), isDragging);
      }
    };

    gliderA.on('drag', () => dispatchBound('a', gliderA, true));
    gliderB.on('drag', () => dispatchBound('b', gliderB, true));
  }

  return board;
}

