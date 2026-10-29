/**
 * Generates line elements representing mathematical curves.
 * Styled with Academic White Theme and natural Hand-drawn sketch aesthetics.
 * Handles domain clipping and splits segments across vertical asymptotes/singularities.
 */
export function buildCurveElements(parsed, viewport, verticalAsymptotes = [], samples = 180) {
  const elements = [];
  const range = viewport.getVisibleRange();
  const minX = range.minX;
  const maxX = range.maxX;
  const step = (maxX - minX) / samples;

  const segments = [];
  let currentSegment = [];

  for (let i = 0; i <= samples; i++) {
    const x = minX + i * step;

    // Check if x is too close to a vertical asymptote
    const nearAsymptote = verticalAsymptotes.some((vert) => Math.abs(x - vert) < step * 1.2);
    if (nearAsymptote) {
      if (currentSegment.length > 1) {
        segments.push(currentSegment);
      }
      currentSegment = [];
      continue;
    }

    const y = parsed.evaluate(x);
    if (y === null || typeof y !== 'number' || !Number.isFinite(y)) {
      if (currentSegment.length > 1) {
        segments.push(currentSegment);
      }
      currentSegment = [];
      continue;
    }

    const screen = viewport.toScreen(x, y);

    // If y jumps wildly off screen, clip or break segment
    if (currentSegment.length > 0) {
      const prevScreen = currentSegment[currentSegment.length - 1];
      if (Math.abs(screen.sy - prevScreen.sy) > viewport.height * 1.5) {
        if (currentSegment.length > 1) {
          segments.push(currentSegment);
        }
        currentSegment = [];
      }
    }

    currentSegment.push({ x, y, sx: screen.sx, sy: screen.sy });
  }

  if (currentSegment.length > 1) {
    segments.push(currentSegment);
  }

  // Convert each point segment to a line element with organic sketch roughness
  segments.forEach((seg, idx) => {
    if (seg.length < 2) return;
    const base = seg[0];
    const points = seg.map((p) => [p.sx - base.sx, p.sy - base.sy]);

    let minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (const [px, py] of points) {
      if (px < minX) minX = px;
      if (px > maxX) maxX = px;
      if (py < minY) minY = py;
      if (py > maxY) maxY = py;
    }

    elements.push({
      id: `curve-segment-${idx}`,
      type: 'line',
      x: base.sx,
      y: base.sy,
      width: Math.max(1, maxX - minX),
      height: Math.max(1, maxY - minY),
      points,
      strokeColor: '#1d4ed8', // Academic Royal Blue (SGK / Textbook standard)
      strokeWidth: 2.2,
      roughness: 0.7,
      bowing: 0.5,
      roundness: { type: 2 },
      locked: true,
      customType: 'curve-segment',
    });
  });

  return elements;
}
