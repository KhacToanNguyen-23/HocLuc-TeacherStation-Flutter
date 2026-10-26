/**
 * Học Lực Math Studio — Industrial Grade Graph Plotter Engine
 * Dual-Mode Graph Engine:
 * 1. High-Performance Interactive JSXGraph Board (v1.9.2 from Uni Bayreuth) for live WebView2 Canvas.
 * 2. Ultra-Crisp Vector SVG Generator for NoteRenderer Chalkboard & Board Pinning.
 */
import { generateRevolutionSolidSvg } from './revolution_solid_plotter.js';

// Global cache to track JSXGraph boards by container ID
export { renderJSXGraphBoard, destroyJSXGraphBoard } from "../board/graph_board.js";

export function generateGraphSvg(analysis, integralResult = null, options = {}) {
  const {
    width = 440,
    height = 280,
    theme = 'light',
    bounds = null,
    cursorPos = null,
    isRevolved = false,
    tickStepX = null,
    tickStepY = null,
    curveColor = null,
    markedPoints = []
  } = options;

  const isChalkboard = theme === 'chalkboard';
  const isDark = theme === 'dark';
  const activeCurveColor = curveColor || (isChalkboard ? '#DC2626' : isDark ? '#f87171' : '#d32f2f');

  const colors = {
    bg: isChalkboard ? 'transparent' : isDark ? '#151722' : '#ffffff',
    grid: isChalkboard ? 'rgba(255, 255, 255, 0.18)' : isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(15, 23, 42, 0.08)',
    axis: isChalkboard ? '#ffffff' : isDark ? '#cbd5e1' : '#0f172a',
    axisLabel: isChalkboard ? '#ffffff' : isDark ? '#cbd5e1' : '#1f2937',
    curve: activeCurveColor,
    asymptote: isChalkboard ? '#fde047' : isDark ? '#fab387' : '#526984',
    extremumDot: isChalkboard ? '#38bdf8' : isDark ? '#f38ba8' : '#0b3a82',
    extremumLabel: isChalkboard ? '#fde047' : isDark ? '#cdd6f4' : '#0b2348',
    projection: isChalkboard ? 'rgba(255, 255, 255, 0.45)' : 'rgba(100, 116, 139, 0.7)',
    integralFill: isChalkboard ? 'rgba(220, 38, 38, 0.22)' : isDark ? 'rgba(250, 179, 135, 0.35)' : 'rgba(224, 36, 36, 0.16)',
    integralStroke: isChalkboard ? '#DC2626' : isDark ? '#fab387' : '#e02424',
    crosshair: isChalkboard ? 'rgba(220, 38, 38, 0.7)' : isDark ? 'rgba(137, 180, 250, 0.6)' : 'rgba(11, 58, 130, 0.5)'
  };

  let xMin = bounds?.xMin ?? -5.5;
  let xMax = bounds?.xMax ?? 5.5;
  let yMin = bounds?.yMin ?? -5.0;
  let yMax = bounds?.yMax ?? 5.0;

  if (!bounds && analysis.extrema && analysis.extrema.length > 0) {
    const validYs = analysis.extrema.map(e => e.y).filter(y => isFinite(y) && Math.abs(y) <= 25);
    const xs = analysis.extrema.map(e => e.x).filter(x => isFinite(x) && Math.abs(x) <= 25);

    if (xs.length > 0) {
      const minExtX = Math.min(...xs), maxExtX = Math.max(...xs);
      xMin = Math.max(-12, Math.min(xMin, minExtX - 2.5));
      xMax = Math.min(12, Math.max(xMax, maxExtX + 2.5));
    }
    if (validYs.length > 0) {
      const minExtY = Math.min(...validYs), maxExtY = Math.max(...validYs);
      yMin = Math.max(-10, Math.min(yMin, minExtY - 2.5));
      yMax = Math.min(10, Math.max(yMax, maxExtY + 2.5));
    } else {
      yMin = -6;
      yMax = 6;
    }
  }

  const pad = 24;
  const plotW = width - pad * 2;
  const plotH = height - pad * 2;

  const toScreenX = (x) => pad + ((x - xMin) / (xMax - xMin)) * plotW;
  const toScreenY = (y) => pad + ((yMax - y) / (yMax - yMin)) * plotH;

  const originX = toScreenX(0);
  const originY = toScreenY(0);

  let svg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="100%" height="100%" style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <defs>
    <clipPath id="graphClip">
      <rect x="${pad}" y="${pad}" width="${plotW}" height="${plotH}" rx="4"/>
    </clipPath>
    <filter id="dotShadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="1" stdDeviation="1.5" flood-color="#0b2348" flood-opacity="0.25"/>
    </filter>
    <marker id="axisArrowX" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="${colors.axis}"/>
    </marker>
    <marker id="axisArrowY" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="${colors.axis}"/>
    </marker>
  </defs>

  <rect x="0" y="0" width="${width}" height="${height}" fill="${colors.bg}" rx="8"/>
`;

  // 1. Grid Lines (Omitted on Chalkboard so it blends with the native chalkboard grid)
  const spanX = xMax - xMin;
  const spanY = yMax - yMin;
  const xStep = (tickStepX && tickStepX > 0) ? tickStepX : (spanX > 18 ? 4 : spanX > 10 ? 2 : 1);
  const yStep = (tickStepY && tickStepY > 0) ? tickStepY : (spanY > 18 ? 4 : spanY > 10 ? 2 : 1);

  if (!isChalkboard) {
    svg += `<g stroke="${colors.grid}" stroke-width="0.8">\n`;
    for (let x = Math.ceil(xMin / xStep) * xStep; x <= Math.floor(xMax / xStep) * xStep; x += xStep) {
      if (x === 0) continue;
      const sx = toScreenX(x);
      svg += `<line x1="${sx.toFixed(1)}" y1="${pad}" x2="${sx.toFixed(1)}" y2="${height - pad}"/>\n`;
    }

    for (let y = Math.ceil(yMin / yStep) * yStep; y <= Math.floor(yMax / yStep) * yStep; y += yStep) {
      if (y === 0) continue;
      const sy = toScreenY(y);
      svg += `<line x1="${pad}" y1="${sy.toFixed(1)}" x2="${width - pad}" y2="${sy.toFixed(1)}"/>\n`;
    }
    svg += '</g>\n';
  }

  // 2. Axes Lines & Tick Marks (Solid 1.5px)
  svg += `
  <g stroke="${colors.axis}" stroke-width="1.5">
    <line x1="${pad - 4}" y1="${originY}" x2="${width - pad + 6}" y2="${originY}" marker-end="url(#axisArrowX)"/>
    <line x1="${originX}" y1="${height - pad + 4}" x2="${originX}" y2="${pad - 6}" marker-end="url(#axisArrowY)"/>
  </g>
  <g stroke="${colors.axis}" stroke-width="1.3">
`;
  for (let x = Math.ceil(xMin / xStep) * xStep; x <= Math.floor(xMax / xStep) * xStep; x += xStep) {
    if (x === 0) continue;
    const sx = toScreenX(x);
    svg += `<line x1="${sx.toFixed(1)}" y1="${(originY - 3).toFixed(1)}" x2="${sx.toFixed(1)}" y2="${(originY + 3).toFixed(1)}"/>\n`;
  }
  for (let y = Math.ceil(yMin / yStep) * yStep; y <= Math.floor(yMax / yStep) * yStep; y += yStep) {
    if (y === 0) continue;
    const sy = toScreenY(y);
    svg += `<line x1="${(originX - 3).toFixed(1)}" y1="${sy.toFixed(1)}" x2="${(originX + 3).toFixed(1)}" y2="${sy.toFixed(1)}"/>\n`;
  }
  svg += '</g>\n';

  // 3. Tick Numbers & Origin Label (Pure text, no stroke inheritance)
  svg += `<g fill="${colors.axisLabel}" stroke="none" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-weight="600">\n`;
  for (let x = Math.ceil(xMin / xStep) * xStep; x <= Math.floor(xMax / xStep) * xStep; x += xStep) {
    if (x === 0) continue;
    const sx = toScreenX(x);
    svg += `<text x="${sx.toFixed(1)}" y="${Math.min(Math.max(originY + 16, pad + 14), height - pad - 4).toFixed(1)}" font-size="12" text-anchor="middle">${x}</text>\n`;
  }
  for (let y = Math.ceil(yMin / yStep) * yStep; y <= Math.floor(yMax / yStep) * yStep; y += yStep) {
    if (y === 0) continue;
    const sy = toScreenY(y);
    svg += `<text x="${Math.min(Math.max(originX - 7, pad + 14), width - pad - 4).toFixed(1)}" y="${(sy + 4).toFixed(1)}" font-size="12" text-anchor="end">${y}</text>\n`;
  }
  svg += `<text x="${originX - 10}" y="${originY + 14}" font-size="12" font-weight="bold">O</text>\n`;
  svg += '</g>\n';

  svg += `
  <text x="${width - pad + 10}" y="${originY + 4}" fill="${colors.axis}" font-size="14" font-family="'Cambria Math', 'Times New Roman', serif" font-weight="bold" font-style="italic">x</text>
  <text x="${originX + 6}" y="${pad - 8}" fill="${colors.axis}" font-size="14" font-family="'Cambria Math', 'Times New Roman', serif" font-weight="bold" font-style="italic">y</text>
`;

  svg += `<g clip-path="url(#graphClip)">\n`;

  if (integralResult && typeof integralResult.a === 'number' && typeof integralResult.b === 'number') {
    const { a, b } = integralResult;
    const f = analysis.eval;
    const areaSteps = 80;
    const step = (b - a) / areaSteps;

    let pathD = `M ${toScreenX(a)} ${toScreenY(0)}`;
    for (let i = 0; i <= areaSteps; i++) {
      const x = a + i * step;
      const y = f(x);
      if (!isNaN(y) && isFinite(y)) {
        pathD += ` L ${toScreenX(x)} ${toScreenY(y)}`;
      }
    }
    pathD += ` L ${toScreenX(b)} ${toScreenY(0)} Z`;

    svg += `<path d="${pathD}" fill="${colors.integralFill}"/>\n`;

    const sXa = toScreenX(a);
    const sXb = toScreenX(b);
    const yAtA = toScreenY(f(a) || 0);
    const yAtB = toScreenY(f(b) || 0);

    svg += `
    <line x1="${sXa.toFixed(1)}" y1="${Math.min(originY, yAtA).toFixed(1)}" x2="${sXa.toFixed(1)}" y2="${Math.max(originY, yAtA).toFixed(1)}" stroke="${colors.integralStroke || colors.curve}" stroke-width="1.2" stroke-dasharray="4,3" opacity="0.85"/>
    <line x1="${sXb.toFixed(1)}" y1="${Math.min(originY, yAtB).toFixed(1)}" x2="${sXb.toFixed(1)}" y2="${Math.max(originY, yAtB).toFixed(1)}" stroke="${colors.integralStroke || colors.curve}" stroke-width="1.2" stroke-dasharray="4,3" opacity="0.85"/>

    <g class="drag-handle bound-handle" data-handle-type="bound" data-bound="a" data-math-x="${a}" style="cursor: ew-resize;">
      <circle cx="${sXa.toFixed(1)}" cy="${originY.toFixed(1)}" r="14" fill="transparent"/>
      <circle cx="${sXa.toFixed(1)}" cy="${originY.toFixed(1)}" r="4.5" fill="${colors.integralStroke || colors.curve}" stroke="#ffffff" stroke-width="2" filter="url(#dotShadow)"/>
      <rect x="${(sXa - 19).toFixed(1)}" y="${(originY + 6).toFixed(1)}" width="38" height="15" rx="3" fill="${isChalkboard ? 'rgba(15, 23, 42, 0.85)' : colors.bg}" fill-opacity="0.9" stroke="${colors.integralStroke || colors.curve}" stroke-width="0.8"/>
      <text x="${sXa.toFixed(1)}" y="${(originY + 17).toFixed(1)}" fill="${isChalkboard ? '#f87171' : colors.curve}" font-size="10" font-weight="700" text-anchor="middle">a = ${a}</text>
    </g>
    <g class="drag-handle bound-handle" data-handle-type="bound" data-bound="b" data-math-x="${b}" style="cursor: ew-resize;">
      <circle cx="${sXb.toFixed(1)}" cy="${originY.toFixed(1)}" r="14" fill="transparent"/>
      <circle cx="${sXb.toFixed(1)}" cy="${originY.toFixed(1)}" r="4.5" fill="${colors.integralStroke || colors.curve}" stroke="#ffffff" stroke-width="2" filter="url(#dotShadow)"/>
      <rect x="${(sXb - 19).toFixed(1)}" y="${(originY + 6).toFixed(1)}" width="38" height="15" rx="3" fill="${isChalkboard ? 'rgba(15, 23, 42, 0.85)' : colors.bg}" fill-opacity="0.9" stroke="${colors.integralStroke || colors.curve}" stroke-width="0.8"/>
      <text x="${sXb.toFixed(1)}" y="${(originY + 17).toFixed(1)}" fill="${isChalkboard ? '#f87171' : colors.curve}" font-size="10" font-weight="700" text-anchor="middle">b = ${b}</text>
    </g>
    `;
  }

  if (isRevolved) {
    svg += generateRevolutionSolidSvg(analysis, integralResult, {
      toScreenX,
      toScreenY,
      originY,
      colors,
      xMin,
      xMax,
      plotH
    });
  }

  const hasSingularity = analysis.tableData?.hasSingularity;
  const singularX = analysis.tableData?.singularX;

  const f = analysis.eval;
  const samples = 260;

  const generatePathSegment = (fromX, toX) => {
    let d = '';
    let started = false;
    const subSamples = Math.max(10, Math.round(((toX - fromX) / (xMax - xMin)) * samples));
    const subStep = (toX - fromX) / subSamples;

    for (let x = fromX; x <= toX; x += subStep) {
      const y = f(x);
      if (isNaN(y) || !isFinite(y)) continue;
      const sx = toScreenX(x);
      const sy = toScreenY(y);
      const clampedSy = Math.max(-plotH * 2, Math.min(plotH * 3, sy));

      if (!started) {
        d += `M ${sx.toFixed(1)} ${clampedSy.toFixed(1)}`;
        started = true;
      } else {
        d += ` L ${sx.toFixed(1)} ${clampedSy.toFixed(1)}`;
      }
    }
    return d;
  };

  if (!hasSingularity) {
    const d = generatePathSegment(xMin, xMax);
    svg += `<path d="${d}" fill="none" stroke="${colors.curve}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>\n`;
  } else {
    const delta = 0.05;
    const dLeft = generatePathSegment(xMin, singularX - delta);
    const dRight = generatePathSegment(singularX + delta, xMax);
    svg += `<path d="${dLeft}" fill="none" stroke="${colors.curve}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>\n`;
    svg += `<path d="${dRight}" fill="none" stroke="${colors.curve}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>\n`;
  }

  let formulaRaw = analysis.rawInput || analysis.formulaClean || analysis.formulaLatex || '';
  formulaRaw = formulaRaw.replace(/^y\s*=\s*/i, '').trim();
  formulaRaw = formulaRaw.replace(/(\d+\.\d{3,})/g, (m) => Number(parseFloat(m).toFixed(2)).toString());
  if (formulaRaw) {
    const safeFormula = formulaRaw
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
    const formattedSvg = safeFormula.replace(/\^([0-9a-zA-Z]+)/g, '<tspan baseline-shift="super" font-size="70%">$1</tspan>');
    const badgeW = Math.min(plotW - 80, formulaRaw.length * 8.5 + 46);
    svg += `
    <g class="graph-formula-tag" style="pointer-events: none;">
      <rect x="${pad + 6}" y="${pad + 6}" width="${badgeW}" height="24" rx="6" fill="${isChalkboard ? 'rgba(15, 23, 42, 0.85)' : colors.bg}" fill-opacity="0.94" stroke="${isChalkboard ? 'rgba(255, 255, 255, 0.2)' : '#d6e3f2'}" stroke-width="1"/>
      <text x="${pad + 14}" y="${pad + 22}" fill="${colors.curve}" font-size="13" font-family="'Cambria Math', 'Times New Roman', serif" font-style="italic" font-weight="bold">y = ${formattedSvg}</text>
    </g>
    `;
  }

  if (analysis.asymptotes) {
    analysis.asymptotes.forEach((asym) => {
      if (asym.isVertical) {
        const sx = toScreenX(asym.val);
        svg += `
        <g class="drag-handle asym-v" data-handle-type="asymptote_v" data-val="${asym.val}" style="cursor: col-resize;">
          <line x1="${sx}" y1="${pad}" x2="${sx}" y2="${height - pad}" stroke="transparent" stroke-width="14"/>
          <line x1="${sx}" y1="${pad}" x2="${sx}" y2="${height - pad}" stroke="${colors.asymptote}" stroke-width="1.6" stroke-dasharray="5,4"/>
          <text x="${sx + 4}" y="${pad + 14}" fill="${colors.asymptote}" font-size="10" font-weight="bold">${asym.eq}</text>
        </g>
        `;
      } else if (asym.isHorizontal) {
        const sy = toScreenY(asym.val);
        svg += `
        <g class="drag-handle asym-h" data-handle-type="asymptote_h" data-val="${asym.val}" style="cursor: row-resize;">
          <line x1="${pad}" y1="${sy}" x2="${width - pad}" y2="${sy}" stroke="transparent" stroke-width="14"/>
          <line x1="${pad}" y1="${sy}" x2="${width - pad}" y2="${sy}" stroke="${colors.asymptote}" stroke-width="1.6" stroke-dasharray="5,4"/>
          <text x="${width - pad - 4}" y="${sy - 4}" fill="${colors.asymptote}" font-size="10" font-weight="bold" text-anchor="end">${asym.eq}</text>
        </g>
        `;
      } else if (asym.isOblique) {
        const sx1 = toScreenX(xMin);
        const sy1 = toScreenY(asym.alpha * xMin + asym.beta);
        const sx2 = toScreenX(xMax);
        const sy2 = toScreenY(asym.alpha * xMax + asym.beta);
        svg += `<line x1="${sx1}" y1="${sy1}" x2="${sx2}" y2="${sy2}" stroke="${colors.asymptote}" stroke-width="1.5" stroke-dasharray="5,4"/>\n`;
        svg += `<text x="${toScreenX(1)}" y="${toScreenY(asym.alpha * 1 + asym.beta) - 6}" fill="${colors.asymptote}" font-size="10" font-weight="bold">${asym.eq}</text>\n`;
      }
    });
  }

  if (analysis.extrema) {
    analysis.extrema.forEach((ext, idx) => {
      if (ext.x < xMin - 2 || ext.x > xMax + 2 || ext.y < yMin - 2 || ext.y > yMax + 2) {
        return;
      }
      const sx = toScreenX(ext.x);
      const sy = toScreenY(ext.y);
      const isCT = ext.type === 'CT';
      const labelY = isCT ? sy + 18 : sy - 11;

      svg += `
      <line x1="${sx.toFixed(1)}" y1="${sy.toFixed(1)}" x2="${sx.toFixed(1)}" y2="${originY.toFixed(1)}" stroke="${colors.projection}" stroke-width="1.1" stroke-dasharray="3,3"/>
      <line x1="${sx.toFixed(1)}" y1="${sy.toFixed(1)}" x2="${originX.toFixed(1)}" y2="${sy.toFixed(1)}" stroke="${colors.projection}" stroke-width="1.1" stroke-dasharray="3,3"/>

      <g class="drag-handle extremum-handle" data-handle-type="extremum" data-idx="${idx}" data-math-x="${ext.x}" data-math-y="${ext.y}" style="cursor: grab;">
        <circle cx="${sx.toFixed(1)}" cy="${sy.toFixed(1)}" r="14" fill="transparent"/>
        <circle cx="${sx.toFixed(1)}" cy="${sy.toFixed(1)}" r="4.5" fill="${colors.extremumDot}" stroke="#ffffff" stroke-width="2" filter="url(#dotShadow)"/>
        <text x="${sx.toFixed(1)}" y="${labelY.toFixed(1)}" fill="${colors.extremumLabel || colors.extremumDot}" font-size="11.5" font-weight="700" text-anchor="middle" font-family="-apple-system, sans-serif">${ext.type} (${ext.displayX}; ${ext.displayY})</text>
      </g>
      `;
    });
  }

  if (markedPoints && markedPoints.length > 0) {
    markedPoints.forEach((pt, pIdx) => {
      if (pt.x < xMin - 1 || pt.x > xMax + 1 || pt.y < yMin - 1 || pt.y > yMax + 1) return;

      const isCoincidentWithExt = analysis.extrema?.some(e => Math.hypot(e.x - pt.x, e.y - pt.y) < 0.25);
      if (isCoincidentWithExt) return;

      const sx = toScreenX(pt.x);
      const sy = toScreenY(pt.y);
      const ptColor = pt.color || colors.extremumDot;
      const ptLabel = pt.label || `(${pt.x.toFixed(1)}, ${pt.y.toFixed(1)})`;

      const isRootOnOx = Math.abs(pt.y) < 0.05;
      const labelY = isRootOnOx ? originY - 8 : sy - 6;

      svg += `
      <line x1="${sx.toFixed(1)}" y1="${sy.toFixed(1)}" x2="${sx.toFixed(1)}" y2="${originY.toFixed(1)}" stroke="${colors.projection}" stroke-width="1.1" stroke-dasharray="3,3"/>
      <line x1="${sx.toFixed(1)}" y1="${sy.toFixed(1)}" x2="${originX.toFixed(1)}" y2="${sy.toFixed(1)}" stroke="${colors.projection}" stroke-width="1.1" stroke-dasharray="3,3"/>
      <circle cx="${sx.toFixed(1)}" cy="${sy.toFixed(1)}" r="4" fill="${ptColor}" stroke="#ffffff" stroke-width="1.8" filter="url(#dotShadow)"/>
      <text x="${(sx + 5).toFixed(1)}" y="${labelY.toFixed(1)}" fill="${colors.axisLabel}" font-size="10.5" font-weight="600">${ptLabel}</text>
      `;
    });
  }

  if (cursorPos && typeof cursorPos.x === 'number') {
    const cx = cursorPos.x;
    const cy = f(cx);
    if (!isNaN(cy) && isFinite(cy)) {
      const scx = toScreenX(cx);
      const scy = toScreenY(cy);
      svg += `
        <line x1="${scx}" y1="${pad}" x2="${scx}" y2="${height - pad}" stroke="${colors.crosshair}" stroke-width="1" stroke-dasharray="2,2"/>
        <line x1="${pad}" y1="${scy}" x2="${width - pad}" y2="${scy}" stroke="${colors.crosshair}" stroke-width="1" stroke-dasharray="2,2"/>
        <circle cx="${scx}" cy="${scy}" r="4" fill="${colors.accentCyan || '#74c7ec'}" stroke="#ffffff" stroke-width="2"/>
      `;
    }
  }

  svg += '</g>\n';
  svg += '</svg>';
  return svg.trim();
}
