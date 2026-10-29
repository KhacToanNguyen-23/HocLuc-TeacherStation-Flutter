import React from 'react';

/**
 * Academic Pedagogical Analysis Pane for Function Graphing.
 * Clean, serious typography without cartoonish emojis or neon gaming palettes.
 */
export function GraphPage({ analysis, antiderivative, tangent, x0, setX0, lineM, setLineM, mRoots }) {
  const extrema = analysis?.extrema || [];
  const asymptotes = analysis?.asymptotes || { vertical: [], horizontal: [], slant: [] };
  const maxList = extrema.filter((e) => e.type === 'max');
  const minList = extrema.filter((e) => e.type === 'min');

  // Format monotonicity intervals
  const increasing = (analysis?.intervals || []).filter((i) => i.increasing);
  const decreasing = (analysis?.intervals || []).filter((i) => !i.increasing);

  const formatIntervals = (list) => {
    if (list.length === 0) return 'Không có';
    return list
      .map((i) => `(${i.from === -10 ? '-∞' : Number(i.from.toFixed(1))}; ${i.to === 10 ? '+∞' : Number(i.to.toFixed(1))})`)
      .join(', ');
  };

  return (
    <div className="tab-pane-content">
      {/* 1. Đơn điệu & Cực trị */}
      <div className="math-card">
        <div className="card-header">
          <span className="card-badge">1</span>
          <span className="card-title">ĐƠN ĐIỆU & CỰC TRỊ</span>
        </div>
        <div className="card-row">
          <span className="label">Tập xác định D:</span>
          <span className="value font-math">{analysis?.domainDesc || 'D = ℝ'}</span>
        </div>
        <div className="card-row">
          <span className="label">Đồng biến:</span>
          <span className="value text-academic-blue font-math">{formatIntervals(increasing)}</span>
        </div>
        <div className="card-row">
          <span className="label">Nghịch biến:</span>
          <span className="value text-academic-amber font-math">{formatIntervals(decreasing)}</span>
        </div>
        <div className="card-row">
          <span className="label">Điểm cực đại:</span>
          <span className="value text-academic-blue font-math">
            {maxList.length > 0
              ? maxList.map((e) => `(${Number(e.x.toFixed(1))}; ${Number(e.y.toFixed(1))})`).join(', ')
              : 'Không có'}
          </span>
        </div>
        <div className="card-row">
          <span className="label">Điểm cực tiểu:</span>
          <span className="value text-academic-rose font-math">
            {minList.length > 0
              ? minList.map((e) => `(${Number(e.x.toFixed(1))}; ${Number(e.y.toFixed(1))})`).join(', ')
              : 'Không có'}
          </span>
        </div>
      </div>

      {/* 2. Đường tiệm cận */}
      <div className="math-card">
        <div className="card-header">
          <span className="card-badge">2</span>
          <span className="card-title">ĐƯỜNG TIỆM CẬN</span>
        </div>
        <div className="card-row">
          <span className="label">Tiệm cận đứng (TCĐ):</span>
          <span className="value font-math">
            {asymptotes.vertical.length > 0
              ? asymptotes.vertical.map((x) => `x = ${Number(x.toFixed(2))}`).join(', ')
              : 'Không có'}
          </span>
        </div>
        <div className="card-row">
          <span className="label">Tiệm cận ngang (TCN):</span>
          <span className="value font-math">
            {asymptotes.horizontal.length > 0
              ? asymptotes.horizontal.map((y) => `y = ${Number(y.toFixed(2))}`).join(', ')
              : 'Không có'}
          </span>
        </div>
        {asymptotes.slant && asymptotes.slant.length > 0 && (
          <div className="card-row">
            <span className="label">Tiệm cận xiên (TCX):</span>
            <span className="value font-math">{asymptotes.slant.map((s) => s.eq).join(', ')}</span>
          </div>
        )}
      </div>

      {/* 3. Tiếp tuyến tại M(x0) */}
      <div className="math-card highlight-card">
        <div className="card-header">
          <span className="card-badge">3</span>
          <span className="card-title">TIẾP TUYẾN TẠI M(x₀)</span>
        </div>
        <div className="slider-row">
          <span className="label font-math">x₀:</span>
          <input
            type="range"
            min="-6"
            max="6"
            step="0.1"
            value={x0}
            onChange={(e) => setX0(parseFloat(e.target.value))}
            className="academic-slider"
          />
          <span className="slider-val font-math">{x0.toFixed(1)}</span>
        </div>
        <div className="card-row">
          <span className="label">Tiếp điểm M:</span>
          <span className="value font-math">
            M({x0.toFixed(1)}; {tangent?.y0 != null ? Number(tangent.y0.toFixed(2)) : 'ND'})
          </span>
        </div>
        <div className="card-row">
          <span className="label">Hệ số góc k = f'(x₀):</span>
          <span className="value font-math">
            {(tangent?.slope ?? tangent?.k) != null ? Number((tangent?.slope ?? tangent?.k).toFixed(2)) : 'ND'}
          </span>
        </div>
        <div className="card-row">
          <span className="label">Phương trình tiếp tuyến:</span>
          <span className="value text-academic-rose font-math font-bold">
            {tangent?.equation || '—'}
          </span>
        </div>
      </div>

      {/* 4. Tương giao y = m */}
      <div className="math-card">
        <div className="card-header">
          <span className="card-badge">4</span>
          <span className="card-title">BIỆN LUẬN SỐ NGHIỆM y = m</span>
        </div>
        <div className="slider-row">
          <span className="label font-math">m:</span>
          <input
            type="range"
            min="-8"
            max="8"
            step="0.1"
            value={lineM}
            onChange={(e) => setLineM(parseFloat(e.target.value))}
            className="academic-slider"
          />
          <span className="slider-val font-math text-academic-amber">{lineM.toFixed(1)}</span>
        </div>
        <div className="card-row">
          <span className="label">Số giao điểm (nghiệm):</span>
          <span className="value text-academic-amber font-bold font-math">
            {mRoots.length} nghiệm
          </span>
        </div>
        {mRoots.length > 0 && (
          <div className="card-row">
            <span className="label">Hoành độ x ≈</span>
            <span className="value font-math text-muted">
              {mRoots.map((r) => Number(r.toFixed(2))).join('; ')}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
