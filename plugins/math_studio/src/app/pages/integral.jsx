import React from 'react';

/**
 * Academic Pedagogical Analysis Pane for Definite Integrals and Solids of Revolution.
 */
export function IntegralPage({
  a,
  setA,
  b,
  setB,
  n,
  setN,
  mode,
  setMode,
  show3D,
  setShow3D,
  exactIntegral,
  riemannResult,
  revolutionResult,
}) {
  return (
    <div className="tab-pane-content">
      {/* 1. Thiết lập cận tích phân [a, b] */}
      <div className="math-card">
        <div className="card-header">
          <span className="card-badge">1</span>
          <span className="card-title">CẬN TÍCH PHÂN [a, b]</span>
        </div>
        <div className="inputs-pair-row">
          <div className="input-group">
            <span className="label font-math">Cận dưới a:</span>
            <input
              type="number"
              step="0.5"
              value={a}
              onChange={(e) => setA(parseFloat(e.target.value) || 0)}
              className="academic-number-input font-math"
            />
          </div>
          <div className="input-group">
            <span className="label font-math">Cận trên b:</span>
            <input
              type="number"
              step="0.5"
              value={b}
              onChange={(e) => setB(parseFloat(e.target.value) || 0)}
              className="academic-number-input font-math"
            />
          </div>
        </div>
        <div className="card-row">
          <span className="label">Tích phân I = ∫ₐᵇ f(x) dx:</span>
          <span className="value text-academic-blue font-bold font-math">
            {exactIntegral !== null ? exactIntegral.toFixed(4) : '—'}
          </span>
        </div>
      </div>

      {/* 2. Tổng Riemann bậc thang */}
      <div className="math-card">
        <div className="card-header">
          <span className="card-badge">2</span>
          <span className="card-title">TỔNG RIEMANN BẬC THANG</span>
        </div>
        <div className="slider-row">
          <span className="label font-math">n:</span>
          <input
            type="range"
            min="4"
            max="40"
            step="1"
            value={n}
            onChange={(e) => setN(parseInt(e.target.value, 10))}
            className="academic-slider"
          />
          <span className="slider-val font-math">{n}</span>
        </div>
        <div className="mode-selector-row">
          <span className="label">Điểm mẫu:</span>
          <div className="btn-group">
            <button
              className={`pill-btn ${mode === 'midpoint' ? 'active' : ''}`}
              onClick={() => setMode('midpoint')}
            >
              Trung điểm
            </button>
            <button
              className={`pill-btn ${mode === 'left' ? 'active' : ''}`}
              onClick={() => setMode('left')}
            >
              Cận trái
            </button>
            <button
              className={`pill-btn ${mode === 'right' ? 'active' : ''}`}
              onClick={() => setMode('right')}
            >
              Cận phải
            </button>
          </div>
        </div>
        <div className="card-row">
          <span className="label">Tổng diện tích Sₙ:</span>
          <span className="value font-math font-bold">
            {riemannResult ? riemannResult.sum.toFixed(4) : '—'}
          </span>
        </div>
      </div>

      {/* 3. Khối tròn xoay 3D */}
      <div className="math-card highlight-card">
        <div className="card-header">
          <span className="card-badge">3</span>
          <span className="card-title">KHỐI TRÒN XOAY 3D (QUAY QUANH Ox)</span>
        </div>
        <div className="card-row">
          <span className="label">Chế độ hiển thị 3D:</span>
          <label className="toggle-switch">
            <input
              type="checkbox"
              checked={show3D}
              onChange={(e) => setShow3D(e.target.checked)}
            />
            <span className="slider round"></span>
          </label>
        </div>
        <div className="card-row">
          <span className="label">Thể tích V = π∫ₐᵇ [f(x)]² dx:</span>
          <span className="value text-academic-amber font-bold font-math">
            {revolutionResult ? `${revolutionResult.volume.toFixed(3)} ≈ ${(revolutionResult.volume / Math.PI).toFixed(2)}π` : '—'}
          </span>
        </div>
        {show3D && (
          <div className="hint-box">
            <span className="hint-text">
              Dùng chuột kéo rê trên đồ thị để xoay tự do không gian 360°.
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
