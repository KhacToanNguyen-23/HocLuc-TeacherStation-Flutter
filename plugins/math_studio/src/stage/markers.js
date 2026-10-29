/**
 * Builds markers for Extrema, Inflection points, Asymptotes, Point M, and Intersections.
 * Designed with Academic White Theme and natural Hand-drawn sketch aesthetics.
 */
export function buildMarkerElements(analysis, viewport, options = {}) {
  const elements = [];
  const { toScreen, width, height } = viewport;
  const { lineM, mRoots, pointM } = options;

  // 1. Asymptotes
  if (analysis?.asymptotes) {
    // Vertical asymptotes
    for (const vx of (analysis.asymptotes.vertical || [])) {
      const sx = toScreen(vx, 0).sx;
      elements.push({
        id: `asymptote-vert-${Math.round(vx * 100)}`,
        type: 'line',
        x: sx,
        y: 0,
        width: 0,
        height: height,
        points: [[0, 0], [0, height]],
        strokeColor: '#ea580c', // Academic orange-amber
        strokeStyle: 'dashed',
        strokeWidth: 1.5,
        locked: true,
        customType: 'asymptote-vertical',
      });
      elements.push({
        id: `label-asymptote-vert-${Math.round(vx * 100)}`,
        type: 'text',
        x: sx + 6,
        y: 28,
        width: 60,
        height: 16,
        text: `x = ${Number(vx.toFixed(2))}`,
        fontSize: 12,
        fontFamily: 'math',
        strokeColor: '#c2410c',
        locked: true,
      });
    }

    // Horizontal asymptotes
    for (const hy of (analysis.asymptotes.horizontal || [])) {
      const sy = toScreen(0, hy).sy;
      elements.push({
        id: `asymptote-horiz-${Math.round(hy * 100)}`,
        type: 'line',
        x: 0,
        y: sy,
        width,
        height: 0,
        points: [[0, 0], [width, 0]],
        strokeColor: '#ea580c',
        strokeStyle: 'dashed',
        strokeWidth: 1.5,
        locked: true,
        customType: 'asymptote-horizontal',
      });
      elements.push({
        id: `label-asymptote-horiz-${Math.round(hy * 100)}`,
        type: 'text',
        x: 20,
        y: sy - 18,
        width: 60,
        height: 16,
        text: `y = ${Number(hy.toFixed(2))}`,
        fontSize: 12,
        fontFamily: 'math',
        strokeColor: '#c2410c',
        locked: true,
      });
    }

    // Slant asymptotes
    for (const slant of (analysis.asymptotes.slant || [])) {
      const leftX = viewport.toMath(0, 0).x;
      const rightX = viewport.toMath(width, 0).x;
      const leftY = slant.a * leftX + slant.b;
      const rightY = slant.a * rightX + slant.b;

      const pt1 = toScreen(leftX, leftY);
      const pt2 = toScreen(rightX, rightY);

      elements.push({
        id: `asymptote-slant-${Math.round(slant.a * 100)}`,
        type: 'line',
        x: pt1.sx,
        y: pt1.sy,
        width: pt2.sx - pt1.sx,
        height: pt2.sy - pt1.sy,
        points: [[0, 0], [pt2.sx - pt1.sx, pt2.sy - pt1.sy]],
        strokeColor: '#ea580c',
        strokeStyle: 'dashed',
        strokeWidth: 1.5,
        locked: true,
        customType: 'asymptote-slant',
      });
    }
  }

  // 2. Extrema markers (compact dots, academic notation)
  for (let i = 0; i < (analysis?.extrema || []).length; i++) {
    const ext = analysis.extrema[i];
    const pt = toScreen(ext.x, ext.y);
    const isMax = ext.type === 'max';
    const color = isMax ? '#059669' : '#dc2626'; // Emerald green for max, crimson red for min

    // Compact 8px circular marker
    elements.push({
      id: `extrema-marker-${i}`,
      type: 'ellipse',
      x: pt.sx - 4,
      y: pt.sy - 4,
      width: 8,
      height: 8,
      strokeColor: color,
      backgroundColor: color,
      fillStyle: 'solid',
      strokeWidth: 1,
      roughness: 0.4,
      locked: true,
      customType: 'extremum',
    });

    const labelText = `${isMax ? 'CĐ' : 'CT'}(${Number(ext.x.toFixed(1))}; ${Number(ext.y.toFixed(1))})`;
    elements.push({
      id: `extrema-label-${i}`,
      type: 'text',
      x: pt.sx - 24,
      y: isMax ? pt.sy - 18 : pt.sy + 8,
      width: 70,
      height: 14,
      text: labelText,
      fontSize: 12,
      fontFamily: 'math',
      strokeColor: color,
      locked: true,
    });
  }

  // 3. Line y = m and intersection roots
  if (typeof lineM === 'number') {
    const lineSy = toScreen(0, lineM).sy;
    elements.push({
      id: 'line-y-m',
      type: 'line',
      x: 0,
      y: lineSy,
      width,
      height: 0,
      points: [[0, 0], [width, 0]],
      strokeColor: '#d97706', // Warm Amber
      strokeStyle: 'dashed',
      strokeLineDash: [6, 4],
      strokeWidth: 1.8,
      roughness: 0.5,
      locked: true,
      customType: 'line-m',
    });

    elements.push({
      id: 'label-line-y-m',
      type: 'text',
      x: 16,
      y: lineSy - 16,
      width: 110,
      height: 14,
      text: `y = ${Number(lineM.toFixed(1))} (${(mRoots || []).length} nghiệm)`,
      fontSize: 12,
      fontFamily: 'math',
      strokeColor: '#b45309',
      locked: true,
    });

    // Subtle 6px intersection dots
    for (let j = 0; j < (mRoots || []).length; j++) {
      const rx = mRoots[j];
      const rScreen = toScreen(rx, lineM);
      elements.push({
        id: `m-root-marker-${j}`,
        type: 'ellipse',
        x: rScreen.sx - 3,
        y: rScreen.sy - 3,
        width: 6,
        height: 6,
        strokeColor: '#d97706',
        backgroundColor: '#f59e0b',
        fillStyle: 'solid',
        strokeWidth: 1,
        roughness: 0.3,
        locked: true,
        customType: 'intersection',
      });
    }
  }

  // 4. Point M(x0, y0) marker
  if (pointM && pointM.x !== undefined && pointM.y !== undefined && Number.isFinite(pointM.y)) {
    const mScreen = toScreen(pointM.x, pointM.y);

    // Subtle target dot
    elements.push({
      id: 'point-m-marker',
      type: 'ellipse',
      x: mScreen.sx - 5,
      y: mScreen.sy - 5,
      width: 10,
      height: 10,
      strokeColor: '#1d4ed8',
      backgroundColor: '#3b82f6',
      fillStyle: 'solid',
      strokeWidth: 1.5,
      roughness: 0.4,
      locked: true,
      customType: 'point-m',
    });

    elements.push({
      id: 'point-m-label',
      type: 'text',
      x: mScreen.sx + 8,
      y: mScreen.sy - 16,
      width: 80,
      height: 14,
      text: `M(${Number(pointM.x.toFixed(1))}; ${Number(pointM.y.toFixed(1))})`,
      fontSize: 12,
      fontFamily: 'math',
      strokeColor: '#1d4ed8',
      locked: true,
    });
  }

  return elements;
}
