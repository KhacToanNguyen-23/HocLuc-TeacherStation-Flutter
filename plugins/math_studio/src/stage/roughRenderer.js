import rough from 'roughjs/bundled/rough.esm.js';

/**
 * Ultra-lightweight RoughJS Canvas Renderer for Học Lực Math Studio.
 * Designed with Academic White Theme and natural Hand-drawn sketch aesthetics:
 * - Crisp white paper canvas with subtle coordinate grid.
 * - Hand-drawn ruler Oxy axes with organic roughness and classic arrows.
 * - Hand-drawn Catmull-Rom spline curves for f(x) and tangent line.
 * - Classical Times New Roman math typography.
 */
export function renderElementsToCanvas(canvas, elements) {
  if (!canvas || !elements) return;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;

  const dpr = window.devicePixelRatio || 1;
  const displayWidth = canvas.clientWidth || canvas.width;
  const displayHeight = canvas.clientHeight || canvas.height;

  if (displayWidth <= 0 || displayHeight <= 0) return;

  const targetBufferWidth = Math.round(displayWidth * dpr);
  const targetBufferHeight = Math.round(displayHeight * dpr);

  if (canvas.width !== targetBufferWidth || canvas.height !== targetBufferHeight) {
    canvas.width = targetBufferWidth;
    canvas.height = targetBufferHeight;
  }

  ctx.save();
  ctx.scale(dpr, dpr);

  // 1. Fill Academic White background
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, displayWidth, displayHeight);

  const rc = rough.canvas(canvas);

  for (const el of elements) {
    if (!el) continue;

    if (el.type === 'line') {
      const pts = (el.points || []).map(([dx, dy]) => [el.x + dx, el.y + dy]);
      if (pts.length < 2) continue;

      const isDashed = el.strokeStyle === 'dashed' || (el.strokeLineDash && el.strokeLineDash.length > 0);
      const dash = el.strokeLineDash || (isDashed ? [6, 4] : undefined);

      if (isDashed) {
        ctx.save();
        ctx.strokeStyle = el.strokeColor || '#94a3b8';
        ctx.lineWidth = el.strokeWidth || 1.5;
        ctx.setLineDash(dash);
        ctx.beginPath();
        ctx.moveTo(pts[0][0], pts[0][1]);
        for (let i = 1; i < pts.length; i++) {
          ctx.lineTo(pts[i][0], pts[i][1]);
        }
        ctx.stroke();
        ctx.restore();
      } else if (pts.length === 2) {
        if (el.roughness === 0) {
          ctx.save();
          ctx.strokeStyle = el.strokeColor || '#94a3b8';
          ctx.lineWidth = el.strokeWidth || 1.5;
          ctx.beginPath();
          ctx.moveTo(pts[0][0], pts[0][1]);
          ctx.lineTo(pts[1][0], pts[1][1]);
          ctx.stroke();
          ctx.restore();
        } else {
          rc.line(pts[0][0], pts[0][1], pts[1][0], pts[1][1], {
            stroke: el.strokeColor || '#334155',
            strokeWidth: el.strokeWidth || 1.8,
            roughness: el.roughness ?? 0.8,
            bowing: el.bowing ?? 0.8,
          });
        }
      } else {
        // Curve or multi-segment path
        if (el.roughness === 0) {
          ctx.save();
          ctx.strokeStyle = el.strokeColor || '#1d4ed8';
          ctx.lineWidth = el.strokeWidth || 2.2;
          ctx.beginPath();
          ctx.moveTo(pts[0][0], pts[0][1]);
          for (let i = 1; i < pts.length; i++) {
            ctx.lineTo(pts[i][0], pts[i][1]);
          }
          ctx.stroke();
          ctx.restore();
        } else {
          // Hand-drawn sketch feel:
          // Downsample slightly to smooth spline control points for Catmull-Rom curve
          const step = Math.max(1, Math.floor(pts.length / 50));
          const samplePts = [];
          for (let i = 0; i < pts.length; i += step) {
            samplePts.push(pts[i]);
          }
          if (samplePts[samplePts.length - 1] !== pts[pts.length - 1]) {
            samplePts.push(pts[pts.length - 1]);
          }

          if (typeof rc.curve === 'function' && samplePts.length >= 3) {
            rc.curve(samplePts, {
              stroke: el.strokeColor || '#1d4ed8',
              strokeWidth: el.strokeWidth || 2.2,
              roughness: el.roughness ?? 0.7,
              bowing: el.bowing ?? 0.5,
            });
          } else {
            rc.linearPath(samplePts, {
              stroke: el.strokeColor || '#1d4ed8',
              strokeWidth: el.strokeWidth || 2.2,
              roughness: el.roughness ?? 0.6,
            });
          }
        }
      }

      // End arrowhead
      if (el.endArrowhead === 'arrow' && pts.length >= 2) {
        const pEnd = pts[pts.length - 1];
        const pPrev = pts[pts.length - 2];
        const angle = Math.atan2(pEnd[1] - pPrev[1], pEnd[0] - pPrev[0]);
        const arrowLen = 10;
        ctx.save();
        ctx.fillStyle = el.strokeColor || '#334155';
        ctx.beginPath();
        ctx.moveTo(pEnd[0], pEnd[1]);
        ctx.lineTo(
          pEnd[0] - arrowLen * Math.cos(angle - Math.PI / 6),
          pEnd[1] - arrowLen * Math.sin(angle - Math.PI / 6)
        );
        ctx.lineTo(
          pEnd[0] - arrowLen * Math.cos(angle + Math.PI / 6),
          pEnd[1] - arrowLen * Math.sin(angle + Math.PI / 6)
        );
        ctx.closePath();
        ctx.fill();
        ctx.restore();
      }
    } else if (el.type === 'ellipse') {
      const cx = el.x + el.width / 2;
      const cy = el.y + el.height / 2;
      const color = el.backgroundColor || el.strokeColor || '#1d4ed8';
      if (el.fillStyle === 'solid' && el.roughness === 0) {
        ctx.save();
        ctx.fillStyle = color;
        ctx.strokeStyle = el.strokeColor || color;
        ctx.lineWidth = el.strokeWidth || 1;
        ctx.beginPath();
        ctx.arc(cx, cy, Math.max(1, el.width / 2), 0, 2 * Math.PI);
        ctx.fill();
        ctx.stroke();
        ctx.restore();
      } else {
        rc.ellipse(cx, cy, el.width, el.height, {
          stroke: el.strokeColor || color,
          fill: color,
          fillStyle: el.fillStyle || 'solid',
          strokeWidth: el.strokeWidth || 1.2,
          roughness: el.roughness ?? 0.4,
        });
      }
    } else if (el.type === 'rectangle') {
      rc.rectangle(el.x, el.y, el.width, el.height, {
        stroke: el.strokeColor || '#1d4ed8',
        fill: el.backgroundColor || 'rgba(37, 99, 235, 0.15)',
        fillStyle: el.fillStyle || 'hachure',
        strokeWidth: el.strokeWidth || 1,
        roughness: el.roughness ?? 0.4,
      });
    } else if (el.type === 'text') {
      ctx.save();
      const isMath = el.fontFamily === 'math';
      const fontFace = isMath ? '"Times New Roman", "Cambria Math", serif' : '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
      const fontStyle = isMath ? 'italic 700' : '600';
      ctx.font = `${fontStyle} ${el.fontSize || 12}px ${fontFace}`;
      ctx.fillStyle = el.strokeColor || '#0f172a';
      ctx.textBaseline = 'top';
      ctx.fillText(el.text, el.x, el.y);
      ctx.restore();
    }
  }

  ctx.restore();
}

function escapeXml(unsafe) {
  if (unsafe === null || unsafe === undefined) return '';
  return String(unsafe)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/**
 * Exports elements to pure standalone SVG string for lossless vector chalkboard pinning.
 */
export function exportElementsToSvg(elements, width = 700, height = 550) {
  const parts = [
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}">`,
    `<rect width="100%" height="100%" fill="#ffffff" rx="8" stroke="#cbd5e1" stroke-width="1.5"/>`,
  ];

  for (const el of elements) {
    if (!el) continue;
    if (el.type === 'line') {
      const rawPts = (el.points || []).map(([dx, dy]) => [el.x + dx, el.y + dy]);
      if (rawPts.length < 2) continue;
      const pts = rawPts.map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`).join(' ');
      const isDashed = el.strokeStyle === 'dashed' || (el.strokeLineDash && el.strokeLineDash.length > 0);
      const dashAttr = isDashed ? 'stroke-dasharray="6,4"' : '';
      parts.push(`<polyline points="${pts}" stroke="${el.strokeColor || '#334155'}" stroke-width="${el.strokeWidth || 1.8}" fill="none" ${dashAttr} />`);

      // Arrowhead for axes
      if (el.endArrowhead === 'arrow' && rawPts.length >= 2) {
        const pEnd = rawPts[rawPts.length - 1];
        const pPrev = rawPts[rawPts.length - 2];
        const angle = Math.atan2(pEnd[1] - pPrev[1], pEnd[0] - pPrev[0]);
        const arrowLen = 10;
        const pTip = `${pEnd[0].toFixed(1)},${pEnd[1].toFixed(1)}`;
        const pLeft = `${(pEnd[0] - arrowLen * Math.cos(angle - Math.PI / 6)).toFixed(1)},${(pEnd[1] - arrowLen * Math.sin(angle - Math.PI / 6)).toFixed(1)}`;
        const pRight = `${(pEnd[0] - arrowLen * Math.cos(angle + Math.PI / 6)).toFixed(1)},${(pEnd[1] - arrowLen * Math.sin(angle + Math.PI / 6)).toFixed(1)}`;
        parts.push(`<polygon points="${pTip} ${pLeft} ${pRight}" fill="${el.strokeColor || '#334155'}" />`);
      }
    } else if (el.type === 'ellipse') {
      const cx = el.x + el.width / 2;
      const cy = el.y + el.height / 2;
      const rx = el.width / 2;
      const ry = el.height / 2;
      const fill = el.backgroundColor || el.strokeColor || '#1d4ed8';
      parts.push(`<ellipse cx="${cx.toFixed(1)}" cy="${cy.toFixed(1)}" rx="${rx.toFixed(1)}" ry="${ry.toFixed(1)}" fill="${fill}" stroke="${el.strokeColor || fill}" stroke-width="${el.strokeWidth || 1.2}" />`);
    } else if (el.type === 'rectangle') {
      parts.push(`<rect x="${el.x.toFixed(1)}" y="${el.y.toFixed(1)}" width="${el.width.toFixed(1)}" height="${el.height.toFixed(1)}" fill="${el.backgroundColor || 'rgba(37, 99, 235, 0.15)'}" stroke="${el.strokeColor || '#1d4ed8'}" stroke-width="${el.strokeWidth || 1}" />`);
    } else if (el.type === 'text') {
      const isMath = el.fontFamily === 'math';
      const fontFace = isMath ? "'Times New Roman', serif" : '-apple-system, sans-serif';
      const fontStyle = isMath ? 'font-style="italic"' : '';
      const text = escapeXml(el.text);
      parts.push(`<text x="${el.x.toFixed(1)}" y="${(el.y + (el.fontSize || 12)).toFixed(1)}" fill="${el.strokeColor || '#0f172a'}" font-size="${el.fontSize || 12}" font-family="${fontFace}" font-weight="700" ${fontStyle}>${text}</text>`);
    }
  }

  parts.push('</svg>');
  return parts.join('\n');
}
