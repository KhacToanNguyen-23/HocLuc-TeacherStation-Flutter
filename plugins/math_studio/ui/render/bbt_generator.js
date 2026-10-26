/**
 * SVG Generator for Variation Table (Bảng Biến Thiên)
 * Compliant with Vietnamese High School Textbook Standard (SGK THPT).
 */

export function generateBbtSvg(analysis, options = {}) {
  const {
    width = 460,
    height = 200,
    theme = 'light'
  } = options;

  const isChalkboard = theme === 'chalkboard';
  const isDark = theme === 'dark';
  const colors = {
    bg: isChalkboard ? 'transparent' : isDark ? '#151722' : '#ffffff',
    line: isChalkboard ? '#ffffff' : isDark ? '#585b70' : '#0b2348',
    textMain: isChalkboard ? '#ffffff' : isDark ? '#cdd6f4' : '#0b2348',
    textSign: isChalkboard ? '#38bdf8' : isDark ? '#fab387' : '#0b3a82',
    arrow: isChalkboard ? '#4ade80' : isDark ? '#a6e3a1' : '#047857',
    singular: isChalkboard ? '#f87171' : isDark ? '#f38ba8' : '#b91c1c',
    extremumBadge: isChalkboard ? '#38bdf8' : isDark ? '#89b4fa' : '#0b3a82'
  };

  const col1Width = 55;
  const rowH_x = 38;
  const rowH_der = 38;
  const rowH_y = height - rowH_x - rowH_der - 10;

  const y_line1 = 5 + rowH_x;
  const y_line2 = y_line1 + rowH_der;
  const y_bottom = 5 + height - 10;

  const { points = [], intervals = [] } = analysis.tableData || {};

  // All markers along x axis: -∞, point_0, point_1, ..., +∞
  const totalSlots = points.length + 2;
  const colWidth = (width - col1Width - 20) / (totalSlots - 1);

  const getSlotX = (index) => col1Width + 10 + index * colWidth;

  let svg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="100%" height="100%" style="font-family: -apple-system, 'Segoe UI', Arial, sans-serif;">
  <defs>
    <!-- Arrow Marker -->
    <marker id="arrowUp" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="${colors.arrow}"/>
    </marker>
    <marker id="arrowDown" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="${colors.arrow}"/>
    </marker>
  </defs>

  <!-- Background -->
  <rect x="0" y="0" width="${width}" height="${height}" fill="${colors.bg}" rx="8"/>

  <!-- Table Grid Lines -->
  <!-- Header Col Separator -->
  <line x1="${col1Width}" y1="5" x2="${col1Width}" y2="${y_bottom}" stroke="${colors.line}" stroke-width="1.2"/>
  <!-- Row 1 Separator -->
  <line x1="5" y1="${y_line1}" x2="${width - 5}" y2="${y_line1}" stroke="${colors.line}" stroke-width="1.2"/>
  <!-- Row 2 Separator -->
  <line x1="5" y1="${y_line2}" x2="${width - 5}" y2="${y_line2}" stroke="${colors.line}" stroke-width="1.2"/>
  <!-- Outer Box -->
  <rect x="5" y="5" width="${width - 10}" height="${y_bottom - 5}" fill="none" stroke="${colors.line}" stroke-width="1.2" rx="4"/>

  <!-- Header Labels -->
  <text x="${col1Width / 2}" y="${5 + rowH_x / 2 + 5}" fill="${colors.textMain}" font-size="14" font-style="italic" font-weight="bold" text-anchor="middle">x</text>
  <text x="${col1Width / 2}" y="${y_line1 + rowH_der / 2 + 5}" fill="${colors.textMain}" font-size="14" font-style="italic" font-weight="bold" text-anchor="middle">y'</text>
  <text x="${col1Width / 2}" y="${y_line2 + rowH_y / 2 + 5}" fill="${colors.textMain}" font-size="14" font-style="italic" font-weight="bold" text-anchor="middle">y</text>

  <!-- Row 1: x markers -->
  <text x="${getSlotX(0)}" y="${5 + rowH_x / 2 + 5}" fill="${colors.textMain}" font-size="13" font-weight="500" text-anchor="middle">-∞</text>
`;

  points.forEach((pt, i) => {
    const xPos = getSlotX(i + 1);
    svg += `<text x="${xPos}" y="${5 + rowH_x / 2 + 5}" fill="${colors.textMain}" font-size="13" font-weight="bold" text-anchor="middle">${pt.displayX}</text>\n`;
  });

  const lastSlotIndex = points.length + 1;
  svg += `<text x="${getSlotX(lastSlotIndex)}" y="${5 + rowH_x / 2 + 5}" fill="${colors.textMain}" font-size="13" font-weight="500" text-anchor="middle">+∞</text>\n`;

  // Row 2: y' signs & zeros/singulars
  points.forEach((pt, i) => {
    const xPos = getSlotX(i + 1);
    if (pt.isSingular) {
      // Double vertical bar for singularity
      svg += `
      <line x1="${xPos - 2}" y1="${y_line1}" x2="${xPos - 2}" y2="${y_bottom}" stroke="${colors.singular}" stroke-width="1.2"/>
      <line x1="${xPos + 2}" y1="${y_line1}" x2="${xPos + 2}" y2="${y_bottom}" stroke="${colors.singular}" stroke-width="1.2"/>
      `;
    } else {
      svg += `<text x="${xPos}" y="${y_line1 + rowH_der / 2 + 5}" fill="${colors.textMain}" font-size="13" font-weight="bold" text-anchor="middle">0</text>\n`;
    }
  });

  // Signs between points
  for (let i = 0; i < totalSlots - 1; i++) {
    const midX = (getSlotX(i) + getSlotX(i + 1)) / 2;
    const sign = intervals[i]?.sign || '+';
    svg += `<text x="${midX}" y="${y_line1 + rowH_der / 2 + 5}" fill="${colors.textSign}" font-size="15" font-weight="bold" text-anchor="middle">${sign}</text>\n`;
  }

  // Row 3: y arrows & limit values
  const yTop = y_line2 + 20;
  const yBottomPos = y_bottom - 18;
  const yMid = (yTop + yBottomPos) / 2;

  // Render arrows segment by segment
  for (let i = 0; i < totalSlots - 1; i++) {
    const startX = getSlotX(i) + 12;
    const endX = getSlotX(i + 1) - 12;
    const sign = intervals[i]?.sign || '+';

    const ptStart = i === 0 ? null : points[i - 1];
    const ptEnd = i === points.length ? null : points[i];

    let startY, endY;

    if (sign === '+') {
      // Sloping up
      startY = yBottomPos;
      endY = yTop;
      svg += `<line x1="${startX}" y1="${startY}" x2="${endX}" y2="${endY}" stroke="${colors.arrow}" stroke-width="2.2" marker-end="url(#arrowUp)"/>\n`;
    } else {
      // Sloping down
      startY = yTop;
      endY = yBottomPos;
      svg += `<line x1="${startX}" y1="${startY}" x2="${endX}" y2="${endY}" stroke="${colors.arrow}" stroke-width="2.2" marker-end="url(#arrowDown)"/>\n`;
    }

    // Extremum values / limit labels
    if (i === 0) {
      const leftLimit = analysis.limits?.left || (sign === '+' ? '-∞' : '+∞');
      svg += `<text x="${getSlotX(0)}" y="${sign === '+' ? yBottomPos : yTop}" fill="${colors.textMain}" font-size="11.5" text-anchor="middle">${leftLimit}</text>\n`;
    }

    if (ptEnd && !ptEnd.isSingular) {
      const valY = sign === '+' ? yTop - 4 : yBottomPos + 12;
      svg += `<text x="${getSlotX(i + 1)}" y="${valY}" fill="${colors.extremumBadge}" font-size="12" font-weight="bold" text-anchor="middle">${ptEnd.yVal}</text>\n`;
    } else if (ptEnd && ptEnd.isSingular) {
      // One-sided limits near singular line
      svg += `<text x="${getSlotX(i + 1) - 10}" y="${sign === '+' ? yTop : yBottomPos}" fill="${colors.textMain}" font-size="11" text-anchor="end">${ptEnd.leftLimit || ''}</text>\n`;
      svg += `<text x="${getSlotX(i + 1) + 10}" y="${intervals[i + 1]?.sign === '+' ? yBottomPos : yTop}" fill="${colors.textMain}" font-size="11" text-anchor="start">${ptEnd.rightLimit || ''}</text>\n`;
    }

    if (i === totalSlots - 2) {
      const rightLimit = analysis.limits?.right || (sign === '+' ? '+∞' : '-∞');
      svg += `<text x="${getSlotX(lastSlotIndex)}" y="${sign === '+' ? yTop : yBottomPos}" fill="${colors.textMain}" font-size="11.5" text-anchor="middle">${rightLimit}</text>\n`;
    }
  }

  svg += '</svg>';
  return svg.trim();
}

