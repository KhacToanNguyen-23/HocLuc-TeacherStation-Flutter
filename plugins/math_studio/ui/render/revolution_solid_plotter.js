/**
 * Revolution Solid 2.5D Plotter (Chuẩn Sư phạm SGK Toán 12)
 * Thể tích khối tròn xoay tạo thành khi hình phẳng giới hạn bởi y = f(x), trục Ox, x = a, x = b quay quanh Ox.
 * 
 * Thiết kế tối giản, thanh lịch:
 * - 2 elip tiết diện tại 2 đáy x = a và x = b (nửa sau nét đứt mảnh, nửa trước nét liền chuẩn SGK).
 * - Đường sinh trên y = f(x) và đường sinh dưới đối xứng y = -f(x).
 * - Màu đổ gradient thể tích mờ nhẹ (translucent tint 12%) thanh nhã, không gây rối mắt.
 * - Mũi tên chỉ hướng quay quanh trục Ox.
 */

export function generateRevolutionSolidSvg(analysis, integralResult, context) {
  const {
    toScreenX,
    toScreenY,
    originY,
    colors,
    xMin,
    xMax
  } = context;

  const f = analysis.eval;
  if (!f) return '';

  // Determine interval [a, b] for rotation (default [-2, 2] or integral/domain bounds)
  let a = integralResult?.a ?? -2;
  let b = integralResult?.b ?? 2;
  if (a > b) { const tmp = a; a = b; b = tmp; }

  // Clamp within visible domain
  a = Math.max(xMin + 0.2, a);
  b = Math.min(xMax - 0.2, b);
  if (b - a < 0.3) return '';

  const tiltFactor = 0.26; // Axonometric projection tilt ratio
  const samples = 60;
  const step = (b - a) / samples;

  // 1. Build upper and lower profile points
  let upperPoints = [];
  let lowerPoints = [];

  for (let i = 0; i <= samples; i++) {
    const x = a + i * step;
    const yVal = f(x);
    if (isNaN(yVal) || !isFinite(yVal)) continue;

    const r = Math.abs(yVal);
    const sx = toScreenX(x);
    const syTop = toScreenY(r);
    const syBot = toScreenY(-r);

    upperPoints.push({ x: sx, y: syTop });
    lowerPoints.push({ x: sx, y: syBot });
  }

  if (upperPoints.length < 2) return '';

  // 2. Path for translucent volume body
  let bodyPathD = `M ${upperPoints[0].x.toFixed(1)} ${upperPoints[0].y.toFixed(1)}`;
  for (let i = 1; i < upperPoints.length; i++) {
    bodyPathD += ` L ${upperPoints[i].x.toFixed(1)} ${upperPoints[i].y.toFixed(1)}`;
  }
  for (let i = lowerPoints.length - 1; i >= 0; i--) {
    bodyPathD += ` L ${lowerPoints[i].x.toFixed(1)} ${lowerPoints[i].y.toFixed(1)}`;
  }
  bodyPathD += ' Z';

  let svg = `
  <!-- SGK 2.5D Solid of Revolution -->
  <g class="sgk-revolution-solid revolution-solid-group" style="pointer-events: none;">
    <defs>
      <linearGradient id="revolGradientSoft" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="${colors.curve}" stop-opacity="0.18"/>
        <stop offset="50%" stop-color="${colors.curve}" stop-opacity="0.05"/>
        <stop offset="100%" stop-color="${colors.curve}" stop-opacity="0.18"/>
      </linearGradient>
    </defs>

    <!-- Translucent Shaded Body -->
    <path d="${bodyPathD}" fill="url(#revolGradientSoft)" stroke="none"/>

    <!-- Lower Symmetric Profile Contour -->
    <path d="M ${lowerPoints.map(p => `${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' L ')}"
          fill="none" stroke="${colors.curve}" stroke-width="1.8" stroke-dasharray="6,3" stroke-opacity="0.75"/>
  `;

  // 3. Draw exactly 2 clean boundary ellipses at x = a and x = b
  const drawBaseEllipse = (xVal, isRightEnd = false) => {
    const yVal = f(xVal);
    if (isNaN(yVal) || !isFinite(yVal)) return '';
    const r = Math.abs(yVal);
    if (r < 0.08) return '';

    const cx = toScreenX(xVal);
    const cy = originY;
    const ry = Math.abs(toScreenY(r) - originY);
    const rx = Math.max(3, ry * tiltFactor);

    return `
    <g class="revol-base-ellipse cross-section-ellipse">
      <!-- Back Hidden Arc (Nét đứt mảnh) -->
      <path d="M ${cx.toFixed(1)} ${(cy - ry).toFixed(1)} A ${rx.toFixed(1)} ${ry.toFixed(1)} 0 0 0 ${cx.toFixed(1)} ${(cy + ry).toFixed(1)}"
            fill="none" stroke="${colors.curve}" stroke-width="1.2" stroke-dasharray="3,3" stroke-opacity="0.5"/>

      <!-- Front Visible Arc (Nét liền sắc nét) -->
      <path d="M ${cx.toFixed(1)} ${(cy - ry).toFixed(1)} A ${rx.toFixed(1)} ${ry.toFixed(1)} 0 0 1 ${cx.toFixed(1)} ${(cy + ry).toFixed(1)}"
            fill="${isRightEnd ? colors.curve : 'none'}" fill-opacity="${isRightEnd ? 0.08 : 0}"
            stroke="${colors.curve}" stroke-width="1.8" stroke-opacity="0.9"/>
    </g>
    `;
  };

  svg += drawBaseEllipse(a, false);
  svg += drawBaseEllipse(b, true);

  // 4. Subtle rotation indicator arrow around Ox
  const arrowX = toScreenX(b) + 14;
  const arrowY = originY;
  svg += `
    <!-- Rotation Around Ox Indicator -->
    <g transform="translate(${arrowX.toFixed(1)}, ${arrowY.toFixed(1)})" stroke="${colors.curve}" fill="none" stroke-width="1.2" opacity="0.8">
      <path d="M -3 -8 A 6 10 0 1 1 -3 8" stroke-linecap="round"/>
      <polygon points="-3,8 -6,5 -1,5" fill="${colors.curve}"/>
      <text x="7" y="3" font-size="9" font-style="italic" fill="${colors.curve}">Ox</text>
    </g>
  </g>
  `;

  return svg;
}
