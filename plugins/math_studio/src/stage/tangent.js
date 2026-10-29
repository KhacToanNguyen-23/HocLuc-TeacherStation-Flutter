/**
 * Builds elements for the tangent line at M(x0).
 * Academic White Theme with natural Hand-drawn sketch aesthetics.
 */
export function buildTangentElements(tangent, viewport) {
  if (!tangent || tangent.slope === null || tangent.y0 === null) {
    return [];
  }

  const { toScreen } = viewport;
  const { x0, y0, slope, equation } = tangent;

  // Compute endpoints spanning the viewport
  const mathRange = viewport.getVisibleRange();
  const xSpan = mathRange.maxX - mathRange.minX;
  const xLeft = x0 - xSpan;
  const yLeft = y0 + slope * (xLeft - x0);
  const xRight = x0 + xSpan;
  const yRight = y0 + slope * (xRight - x0);

  const ptLeft = toScreen(xLeft, yLeft);
  const ptRight = toScreen(xRight, yRight);

  const elements = [
    {
      id: 'tangent-line',
      type: 'line',
      x: ptLeft.sx,
      y: ptLeft.sy,
      width: ptRight.sx - ptLeft.sx,
      height: ptRight.sy - ptLeft.sy,
      points: [[0, 0], [ptRight.sx - ptLeft.sx, ptRight.sy - ptLeft.sy]],
      strokeColor: '#dc2626', // Academic Crimson Red
      strokeWidth: 1.8,
      roughness: 0.8,
      bowing: 0.6,
      locked: true,
      customType: 'tangent-line',
    },
  ];

  // Floating equation badge near M
  const mPt = toScreen(x0, y0);
  elements.push({
    id: 'tangent-equation-badge',
    type: 'text',
    x: mPt.sx + 12,
    y: mPt.sy + 8,
    width: 120,
    height: 16,
    text: equation,
    fontSize: 12,
    fontFamily: 'math',
    strokeColor: '#b91c1c',
    locked: true,
  });

  return elements;
}
