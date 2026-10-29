/**
 * Builds rectangle elements for Riemann sum visualization.
 * Styled for Academic White Theme with hand-drawn sketch hatching.
 */
export function buildRiemannElements(riemannResult, viewport) {
  if (!riemannResult || !riemannResult.rectangles) return [];
  const elements = [];
  const { toScreen } = viewport;

  for (const rect of riemannResult.rectangles) {
    const ptLeft = toScreen(rect.x, Math.max(0, rect.sampleY));
    const ptRight = toScreen(rect.x + rect.width, Math.min(0, rect.sampleY));

    const sx = ptLeft.sx;
    const sy = ptLeft.sy;
    const sWidth = Math.abs(ptRight.sx - ptLeft.sx);
    const sHeight = Math.abs(ptRight.sy - ptLeft.sy);

    elements.push({
      id: `riemann-col-${rect.index}`,
      type: 'rectangle',
      x: sx,
      y: sy,
      width: Math.max(1, sWidth),
      height: Math.max(1, sHeight),
      strokeColor: '#2563eb',
      backgroundColor: 'rgba(37, 99, 235, 0.16)',
      fillStyle: 'hachure',
      strokeWidth: 1,
      roughness: 0.5,
      locked: true,
      customType: 'riemann-col',
    });
  }

  // Summary badge
  elements.push({
    id: 'riemann-sum-badge',
    type: 'text',
    x: 20,
    y: 20,
    width: 220,
    height: 24,
    text: `Tổng Riemann S_${riemannResult.n} ≈ ${riemannResult.sum.toFixed(4)}`,
    fontSize: 13,
    fontFamily: 'math',
    strokeColor: '#1d4ed8',
    locked: true,
  });

  return elements;
}
