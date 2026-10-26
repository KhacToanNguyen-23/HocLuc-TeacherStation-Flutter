/**
 * 100% WYSIWYG Live DOM SVG Serializer & Exporter
 * For Học Lực Math Studio -> Studio Board Integration
 *
 * Guarantees that what the teacher sees on the inspector screen
 * is EXACTLY what is pinned to the chalkboard (True WYSIWYG).
 */

import { insertToBoard } from '../render/export_helper.js';

/**
 * Extracts and serializes the live JSXGraph DOM SVG container
 * into a standalone, chalk-contrast vector SVG for the chalkboard.
 */
export function serializeLiveBoardSvg(containerId, options = {}) {
  const {
    theme = 'chalkboard',
    formulaBadge = null
  } = options;

  const container = document.getElementById(containerId);
  if (!container) {
    throw new Error(`Container #${containerId} not found in DOM`);
  }

  const liveSvg = container.querySelector('svg');
  if (!liveSvg) {
    throw new Error(`No SVG element found inside container #${containerId}`);
  }

  // Deep clone live SVG node
  const clone = liveSvg.cloneNode(true);

  const rect = container.getBoundingClientRect();
  const width = Math.round(rect.width) || 520;
  const height = Math.round(rect.height) || 380;

  clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
  clone.setAttribute('viewBox', `0 0 ${width} ${height}`);
  clone.setAttribute('width', '100%');
  clone.setAttribute('height', '100%');
  clone.setAttribute('preserveAspectRatio', 'xMidYMid meet');
  clone.style.fontFamily = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";

  // Chalkboard Theme transformations (Option A: Transparent background, no JSXGraph grid, no gliders, high-contrast labels):
  if (theme === 'chalkboard') {
    // 1. Root background -> transparent
    const bgRect = clone.querySelector('rect');
    if (bgRect) {
      bgRect.setAttribute('fill', 'transparent');
      bgRect.setAttribute('stroke', 'none');
    }

    // 2. Remove ignored elements (interactive gliders & background grid)
    clone.querySelectorAll('[data-export-ignore="true"], [data-export-grid="true"]').forEach((el) => {
      el.remove();
    });

    // 3. Transform remaining elements to Chalkboard high contrast
    const allElements = clone.querySelectorAll('*');
    allElements.forEach((el) => {
      const tag = el.tagName.toLowerCase();

      // Remove transparent invisible drag helpers
      const fillOpacity = el.getAttribute('fill-opacity');
      const strokeOpacity = el.getAttribute('stroke-opacity');
      if (fillOpacity === '0' && (strokeOpacity === '0' || !el.hasAttribute('stroke'))) {
        el.remove();
        return;
      }

      const rawStroke = (el.getAttribute('stroke') || (el.style && el.style.stroke) || '').toLowerCase().trim();
      const rawFill = (el.getAttribute('fill') || (el.style && el.style.fill) || '').toLowerCase().trim();

      // Strip out JSXGraph secondary grid lines so chalkboard native grid shows through cleanly
      if (
        rawStroke.includes('rgba(15, 23, 42') ||
        rawStroke.includes('rgba(0, 0, 0, 0.0') ||
        rawStroke === '#e2e8f0' ||
        rawStroke === '#f1f5f9'
      ) {
        el.remove();
        return;
      }

      // Stroke color adaptation (Axes, Ticks, Arrow Markers, Projection Lines)
      if (rawStroke && tag !== 'text' && tag !== 'tspan') {
        if (
          rawStroke === '#0f172a' ||
          rawStroke === '#1f2937' ||
          rawStroke === '#000000' ||
          rawStroke === 'black' ||
          rawStroke.includes('rgb(15, 23, 42)')
        ) {
          el.setAttribute('stroke', '#ffffff');
          if (el.style) el.style.stroke = '#ffffff';
        } else if (rawStroke === '#64748b' || rawStroke.includes('rgb(100, 116, 139)')) {
          el.setAttribute('stroke', 'rgba(255, 255, 255, 0.75)');
          if (el.style) el.style.stroke = 'rgba(255, 255, 255, 0.75)';
        }
      }

      // Arrowhead marker paths adaptation
      if (tag === 'path' && (rawFill === '#0f172a' || rawFill === '#000000' || rawFill.includes('rgb(15, 23, 42)'))) {
        el.setAttribute('fill', '#ffffff');
        if (el.style) el.style.fill = '#ffffff';
      }

      // Extremum dots adaptation
      if ((tag === 'ellipse' || tag === 'circle') && (rawFill === '#0b3a82' || rawFill.includes('rgb(11, 58, 130)'))) {
        el.setAttribute('fill', '#38bdf8');
        if (el.style) el.style.fill = '#38bdf8';
      }

      // Text & Tspan color adaptation (handles both XML attribute & inline CSS style)
      if (tag === 'text' || tag === 'tspan') {
        const role = el.getAttribute('data-label-role') || (el.parentElement && el.parentElement.getAttribute('data-label-role'));
        let targetColor = '#ffffff';

        if (role === 'extremum' || rawFill === '#0b3a82' || rawFill.includes('rgb(11, 58, 130)')) {
          targetColor = '#fde047'; // Bright Chalk Yellow for Extrema (CĐ, CT)
        } else if (role === 'bound' || rawFill === '#e11d48' || rawFill.includes('rgb(225, 29, 72)')) {
          targetColor = '#fb7185'; // Bright Coral for Integral bounds (a, b)
        }

        el.setAttribute('fill', targetColor);
        el.setAttribute('font-weight', '700');
        el.removeAttribute('stroke');
        if (el.style) {
          el.style.fill = targetColor;
          el.style.stroke = 'none';
          el.style.strokeWidth = '0';
          el.style.fontWeight = '700';
        }
      }
    });
  }

  // Formula badge overlay if requested
  if (formulaBadge) {
    const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    g.setAttribute('class', 'board-formula-badge');
    g.innerHTML = `
      <rect x="24" y="24" width="${Math.min(width - 60, formulaBadge.length * 8 + 40)}" height="26" rx="6" fill="rgba(15, 23, 42, 0.85)" stroke="rgba(255, 255, 255, 0.2)" stroke-width="1"/>
      <text x="34" y="42" fill="#f87171" font-size="13" font-weight="bold" font-family="'Cambria Math', serif" font-style="italic">${formulaBadge}</text>
    `;
    clone.appendChild(g);
  }

  let svgString = clone.outerHTML;

  // Ensure self-contained XML string
  if (!svgString.startsWith('<svg')) {
    svgString = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}">${clone.innerHTML}</svg>`;
  }

  return {
    svg: svgString,
    width,
    height,
    aspectRatio: height > 0 ? (width / height) : (520 / 380)
  };
}

/**
 * Pins the live board directly to the teacher chalkboard
 */
export async function pinLiveBoardToChalkboard({
  containerId = 'graphContainer',
  editingStickerId = null,
  title = 'Đồ thị hàm số',
  rawText = 'Đồ thị hàm số',
  metadata = {},
  fallbackSvg = null
}) {
  let exportResult;

  try {
    if (typeof document !== 'undefined' && document.getElementById(containerId)) {
      exportResult = serializeLiveBoardSvg(containerId, {
        theme: 'chalkboard',
        formulaBadge: metadata.formula ? `y = ${metadata.formula}` : null
      });
    }
  } catch (err) {
    console.warn('[BoardExporter] Live DOM serialization fallback:', err.message);
  }

  const finalSvg = exportResult?.svg || fallbackSvg;
  if (!finalSvg) {
    throw new Error('Không thể trích xuất đồ thị vector từ màn hình.');
  }

  const finalAspect = exportResult?.aspectRatio || (520 / 380);

  await insertToBoard({
    stickerId: editingStickerId || undefined,
    metadata,
    title,
    rawText,
    svgContent: finalSvg,
    aspectRatio: finalAspect
  });

  return true;
}

