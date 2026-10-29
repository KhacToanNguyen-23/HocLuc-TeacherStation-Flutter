import React from 'react';

/**
 * Academic Pedagogical Bảng Biến Thiên (BBT) SVG Component.
 * Styled in pure Academic White (SGK Textbook Standard):
 * - Clean white card background with crisp slate borders.
 * - Proper -∞ and +∞ mathematical infinity markers.
 * - Direct vector polygon arrowheads (100% compatible with Flutter flutter_svg & browsers).
 * - Classical Times New Roman math typography.
 */
export function BBTPage({ bbtData, formula, derivDisplay }) {
  if (!bbtData || !bbtData.columns || bbtData.columns.length < 2) {
    return (
      <div className="bbt-empty-state">
        <p>Đang tính toán Bảng Biến Thiên...</p>
      </div>
    );
  }

  const { columns, intervals } = bbtData;
  const colCount = columns.length;
  const width = Math.max(760, colCount * 140 + 120);
  const height = 280;
  const headerColWidth = 110;
  const dataWidth = width - headerColWidth;
  const colStep = dataWidth / (colCount - 1);

  // Compute min and max finite y to properly scale vertical positions in y-row
  const finiteYVals = columns
    .map((c) => (typeof c.yVal === 'number' ? c.yVal : null))
    .filter((v) => v !== null);
  const minY = finiteYVals.length > 0 ? Math.min(...finiteYVals) : -2;
  const maxY = finiteYVals.length > 0 ? Math.max(...finiteYVals) : 2;
  const spanY = Math.max(1e-4, maxY - minY);

  const getYPos = (yVal, idx) => {
    if (yVal === '+∞') return 145;
    if (yVal === '-∞') return 245;
    if (typeof yVal === 'number') {
      // Map [minY, maxY] to [225, 160] (higher y is higher up in SVG)
      const ratio = (yVal - minY) / spanY;
      return 225 - ratio * 65;
    }
    return idx % 2 === 1 ? 160 : 225;
  };

  return (
    <div className="bbt-page-container">
      <div className="bbt-title-bar">
        <h3>BẢNG BIẾN THIÊN — f(x) = {formula}</h3>
        <span className="bbt-sub">y' = {derivDisplay}</span>
      </div>

      <div className="bbt-svg-wrapper">
        <svg
          id="bbt-svg"
          xmlns="http://www.w3.org/2000/svg"
          viewBox={`0 0 ${width} ${height}`}
          width="100%"
          height="100%"
          style={{ borderRadius: '8px' }}
        >
          {/* Card background for lossless chalkboard pinning */}
          <rect x="0" y="0" width={width} height={height} rx="8" fill="#ffffff" stroke="#cbd5e1" strokeWidth="1.5" />

          {/* Inner Table Frame */}
          <rect x="12" y="12" width={width - 24} height={height - 24} rx="4" fill="#fafbfc" stroke="#64748b" strokeWidth="1.5" />

          {/* Vertical divider after header column */}
          <line x1={headerColWidth} y1="12" x2={headerColWidth} y2={height - 12} stroke="#64748b" strokeWidth="1.5" />

          {/* Horizontal Row Dividers */}
          <line x1="12" y1="65" x2={width - 12} y2="65" stroke="#64748b" strokeWidth="1.2" />
          <line x1="12" y1="115" x2={width - 12} y2="115" stroke="#64748b" strokeWidth="1.2" />

          {/* Header Column Labels in Classical Math Italic */}
          <text x="55" y="47" fill="#0f172a" fontSize="20" fontStyle="italic" fontWeight="700" textAnchor="middle" fontFamily="'Times New Roman', serif">x</text>
          <text x="55" y="97" fill="#0f172a" fontSize="20" fontStyle="italic" fontWeight="700" textAnchor="middle" fontFamily="'Times New Roman', serif">y'</text>
          <text x="55" y="195" fill="#0f172a" fontSize="20" fontStyle="italic" fontWeight="700" textAnchor="middle" fontFamily="'Times New Roman', serif">y</text>

          {/* Data Columns */}
          {columns.map((col, idx) => {
            const xPos = headerColWidth + idx * colStep;
            const yPos = getYPos(col.yVal, idx);

            return (
              <g key={`col-${idx}`}>
                {/* Vertical asymptote double bar || */}
                {col.derivSign === '||' && (
                  <>
                    <line x1={xPos - 3} y1="65" x2={xPos - 3} y2={height - 12} stroke="#dc2626" strokeWidth="1.5" />
                    <line x1={xPos + 3} y1="65" x2={xPos + 3} y2={height - 12} stroke="#dc2626" strokeWidth="1.5" />
                  </>
                )}

                {/* X row value */}
                <text
                  x={xPos}
                  y="47"
                  fill="#0f172a"
                  fontSize="17"
                  fontWeight="600"
                  textAnchor="middle"
                  fontFamily="'Times New Roman', serif"
                >
                  {col.labelX}
                </text>

                {/* Y' row value (0 at extremum) */}
                {col.derivSign === 0 && (
                  <text
                    x={xPos}
                    y="97"
                    fill="#475569"
                    fontSize="17"
                    fontWeight="600"
                    textAnchor="middle"
                    fontFamily="'Times New Roman', serif"
                  >
                    0
                  </text>
                )}

                {/* Y row value */}
                {col.yVal !== '||' && (
                  <text
                    x={xPos}
                    y={yPos}
                    fill={typeof col.yVal === 'number' ? '#1d4ed8' : '#475569'}
                    fontSize="17"
                    fontWeight="700"
                    textAnchor="middle"
                    fontFamily="'Times New Roman', serif"
                  >
                    {col.yVal}
                  </text>
                )}
              </g>
            );
          })}

          {/* Signs and Arrows in Intervals */}
          {intervals.map((inter, idx) => {
            const xMid = headerColWidth + (idx + 0.5) * colStep;
            const c1 = columns[idx];
            const c2 = columns[idx + 1];

            const x1 = headerColWidth + idx * colStep + 28;
            const x2 = headerColWidth + (idx + 1) * colStep - 28;

            const y1 = getYPos(c1.yVal, idx);
            const y2 = getYPos(c2.yVal, idx + 1);

            // Inset arrow y coordinates so they don't collide with numbers
            const isUp = y1 > y2;
            const arrowY1 = isUp ? y1 - 14 : y1 + 10;
            const arrowY2 = isUp ? y2 + 10 : y2 - 14;

            // Compute direct polygon arrowhead (100% flutter_svg compatible)
            const angle = Math.atan2(arrowY2 - arrowY1, x2 - x1);
            const arrowLen = 9;
            const arrowAngle = Math.PI / 6;
            const pTip = `${x2.toFixed(1)},${arrowY2.toFixed(1)}`;
            const pLeft = `${(x2 - arrowLen * Math.cos(angle - arrowAngle)).toFixed(1)},${(arrowY2 - arrowLen * Math.sin(angle - arrowAngle)).toFixed(1)}`;
            const pRight = `${(x2 - arrowLen * Math.cos(angle + arrowAngle)).toFixed(1)},${(arrowY2 - arrowLen * Math.sin(angle + arrowAngle)).toFixed(1)}`;

            return (
              <g key={`inter-${idx}`}>
                {/* Derivative Sign (+ or -) */}
                <text
                  x={xMid}
                  y="97"
                  fill={inter.sign === '+' ? '#059669' : '#dc2626'}
                  fontSize="22"
                  fontWeight="bold"
                  textAnchor="middle"
                  fontFamily="'Times New Roman', serif"
                >
                  {inter.sign}
                </text>

                {/* Variation Arrow */}
                {c1.yVal !== '||' && c2.yVal !== '||' && (
                  <g>
                    <line
                      x1={x1}
                      y1={arrowY1}
                      x2={x2}
                      y2={arrowY2}
                      stroke="#2563eb"
                      strokeWidth="2.2"
                      strokeLinecap="round"
                    />
                    <polygon
                      points={`${pTip} ${pLeft} ${pRight}`}
                      fill="#2563eb"
                    />
                  </g>
                )}
              </g>
            );
          })}
        </svg>
      </div>
    </div>
  );
}
