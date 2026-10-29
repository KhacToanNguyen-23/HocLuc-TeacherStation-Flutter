/**
 * Builds Oxy coordinate axes, ticks, grid lines, and labels.
 * Designed with Academic White Theme and natural Hand-drawn sketch aesthetics.
 */
export function buildAxesElements(viewport) {
  const elements = [];
  const { width, height, toScreen, getVisibleRange, getNiceStep } = viewport;
  const range = getVisibleRange();
  const step = getNiceStep();

  const originScreen = toScreen(0, 0);
  const ox = originScreen.sx;
  const oy = originScreen.sy;

  // 1. Grid lines (crisp, subtle graph paper styling)
  const startX = Math.floor(range.minX / step) * step;
  for (let x = startX; x <= range.maxX; x += step) {
    if (Math.abs(x) < 1e-5) continue;
    const sx = toScreen(x, 0).sx;
    elements.push({
      id: `grid-v-${Math.round(x * 100)}`,
      type: 'line',
      x: sx,
      y: 0,
      width: 0,
      height: height,
      points: [[0, 0], [0, height]],
      strokeColor: '#e2e8f0', // Crisp slate graph paper grid
      strokeWidth: 1,
      roughness: 0,
      locked: true,
    });
  }

  const startY = Math.floor(range.minY / step) * step;
  for (let y = startY; y <= range.maxY; y += step) {
    if (Math.abs(y) < 1e-5) continue;
    const sy = toScreen(0, y).sy;
    elements.push({
      id: `grid-h-${Math.round(y * 100)}`,
      type: 'line',
      x: 0,
      y: sy,
      width: width,
      height: 0,
      points: [[0, 0], [width, 0]],
      strokeColor: '#e2e8f0',
      strokeWidth: 1,
      roughness: 0,
      locked: true,
    });
  }

  // 2. Main Axis X (Hand-drawn ruler sketch)
  const clampedOy = Math.max(20, Math.min(height - 25, oy));
  elements.push({
    id: 'main-axis-x',
    type: 'line',
    x: 10,
    y: clampedOy,
    width: width - 20,
    height: 0,
    points: [[0, 0], [width - 20, 0]],
    strokeColor: '#334155',
    strokeWidth: 2,
    roughness: 0.8,
    bowing: 0.8,
    endArrowhead: 'arrow',
    locked: true,
  });

  // 3. Main Axis Y (Hand-drawn ruler sketch)
  const clampedOx = Math.max(25, Math.min(width - 25, ox));
  elements.push({
    id: 'main-axis-y',
    type: 'line',
    x: clampedOx,
    y: height - 10,
    width: 0,
    height: -(height - 20),
    points: [[0, 0], [0, -(height - 20)]],
    strokeColor: '#334155',
    strokeWidth: 2,
    roughness: 0.8,
    bowing: 0.8,
    endArrowhead: 'arrow',
    locked: true,
  });

  // 4. Axis Labels ("x" and "y")
  elements.push({
    id: 'label-axis-x',
    type: 'text',
    x: width - 22,
    y: clampedOy + 6,
    width: 14,
    height: 16,
    text: 'x',
    fontSize: 16,
    fontFamily: 'math',
    strokeColor: '#0f172a',
    locked: true,
  });

  elements.push({
    id: 'label-axis-y',
    type: 'text',
    x: clampedOx + 8,
    y: 8,
    width: 14,
    height: 16,
    text: 'y',
    fontSize: 16,
    fontFamily: 'math',
    strokeColor: '#0f172a',
    locked: true,
  });

  // 5. Origin label 'O'
  elements.push({
    id: 'label-origin-o',
    type: 'text',
    x: clampedOx - 18,
    y: clampedOy + 4,
    width: 14,
    height: 16,
    text: 'O',
    fontSize: 15,
    fontFamily: 'math',
    strokeColor: '#0f172a',
    locked: true,
  });

  // 6. X-axis tick marks and numbers
  for (let x = startX; x <= range.maxX; x += step) {
    if (Math.abs(x) < 1e-4) continue;
    const sx = toScreen(x, 0).sx;
    if (sx < 40 || sx > width - 40) continue;

    // Tick line
    elements.push({
      id: `tick-x-${Math.round(x * 100)}`,
      type: 'line',
      x: sx,
      y: clampedOy - 4,
      width: 0,
      height: 8,
      points: [[0, 0], [0, 8]],
      strokeColor: '#475569',
      strokeWidth: 1.2,
      roughness: 0.5,
      locked: true,
    });

    // Label
    const textStr = Number(x.toFixed(1)).toString();
    elements.push({
      id: `label-num-x-${Math.round(x * 100)}`,
      type: 'text',
      x: sx - (textStr.length * 4),
      y: clampedOy + 8,
      width: textStr.length * 8,
      height: 14,
      text: textStr,
      fontSize: 12,
      fontFamily: 1,
      strokeColor: '#475569',
      locked: true,
    });
  }

  // 7. Y-axis tick marks and numbers
  for (let y = startY; y <= range.maxY; y += step) {
    if (Math.abs(y) < 1e-4) continue;
    const sy = toScreen(0, y).sy;
    if (sy < 40 || sy > height - 40) continue;

    // Tick line
    elements.push({
      id: `tick-y-${Math.round(y * 100)}`,
      type: 'line',
      x: clampedOx - 4,
      y: sy,
      width: 8,
      height: 0,
      points: [[0, 0], [8, 0]],
      strokeColor: '#475569',
      strokeWidth: 1.2,
      roughness: 0.5,
      locked: true,
    });

    const textStr = Number(y.toFixed(1)).toString();
    elements.push({
      id: `label-num-y-${Math.round(y * 100)}`,
      type: 'text',
      x: clampedOx - 10 - (textStr.length * 8),
      y: sy - 7,
      width: textStr.length * 8,
      height: 14,
      text: textStr,
      fontSize: 12,
      fontFamily: 1,
      strokeColor: '#475569',
      locked: true,
    });
  }

  return elements;
}
