import React, { useState, useEffect, useRef, useMemo } from 'react';
import { createRoot } from 'react-dom/client';

import { parseFunction } from '../engine/parse.js';
import { computeDerivative } from '../engine/derivative.js';
import { analyzeFunction, findIntersectionsWithHorizontalLine, getTangentAt } from '../engine/analyze.js';
import { computeAntiderivative, computeDefiniteIntegral } from '../engine/integrate.js';
import { computeRiemannSum } from '../engine/riemann.js';
import { computeRevolutionVolume } from '../engine/revolution.js';
import { buildBBT } from '../engine/bbt.js';

import { createViewport } from '../stage/viewport.js';
import { buildAxesElements } from '../stage/axes.js';
import { buildCurveElements } from '../stage/curve.js';
import { buildMarkerElements } from '../stage/markers.js';
import { buildTangentElements } from '../stage/tangent.js';
import { buildRiemannElements } from '../stage/riemann.js';
import { buildSolid3DElements } from '../stage/solid3d.js';
import { renderElementsToCanvas, exportElementsToSvg } from '../stage/roughRenderer.js';

import { GraphPage } from './pages/graph.jsx';
import { BBTPage } from './pages/bbt.jsx';
import { IntegralPage } from './pages/integral.jsx';
import { Bridge } from './bridge.js';

export function MathStudioApp() {
  const [activeTab, setActiveTab] = useState('graph'); // 'graph' | 'bbt' | 'integral'
  const [formulaInput, setFormulaInput] = useState('x^3 - 3x');
  const [debouncedFormula, setDebouncedFormula] = useState('x^3 - 3x');
  const [stampStatus, setStampStatus] = useState('');

  // Graph tab state
  const [x0, setX0] = useState(2.0);
  const [lineM, setLineM] = useState(0.0);

  // Integral tab state
  const [intA, setIntA] = useState(0.0);
  const [intB, setIntB] = useState(4.0);
  const [riemannN, setRiemannN] = useState(12);
  const [riemannMode, setRiemannMode] = useState('midpoint');
  const [show3D, setShow3D] = useState(false);
  const [rotX, setRotX] = useState(0.4);
  const [rotY, setRotY] = useState(0.5);

  // Canvas & Viewport state
  const [viewportScale, setViewportScale] = useState(40);
  const [viewportPan, setViewportPan] = useState({ x: 0, y: 0 });
  const [canvasDim, setCanvasDim] = useState({ width: 700, height: 550 });

  // Direct canvas refs
  const canvasRef = useRef(null);
  const elementsRef = useRef([]);
  const canvasContainerRef = useRef(null);
  const rafRef = useRef(null);

  // Dragging interaction state
  const [dragTarget, setDragTarget] = useState(null); // 'M' | 'lineM' | '3D' | 'pan' | null
  const [dragStartPos, setDragStartPos] = useState({ x: 0, y: 0 });
  const [dragStartPan, setDragStartPan] = useState({ x: 0, y: 0 });
  const [dragStartRots, setDragStartRots] = useState({ rotX: 0.4, rotY: 0.5 });

  // Debounce formula input
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedFormula(formulaInput);
    }, 120);
    return () => clearTimeout(handler);
  }, [formulaInput]);

  // Update canvas dimensions on container resize
  useEffect(() => {
    const updateSize = () => {
      if (canvasContainerRef.current) {
        const rect = canvasContainerRef.current.getBoundingClientRect();
        if (rect.width > 50 && rect.height > 50) {
          setCanvasDim({ width: Math.round(rect.width), height: Math.round(rect.height) });
        }
      }
    };
    updateSize();
    window.addEventListener('resize', updateSize);
    return () => window.removeEventListener('resize', updateSize);
  }, [activeTab]);

  // 1. Math CAS computations (Lazy by active tab to eliminate UI freeze)
  const parsed = useMemo(() => parseFunction(debouncedFormula), [debouncedFormula]);
  const derivative = useMemo(() => (parsed.success ? computeDerivative(parsed.node) : null), [parsed]);
  const analysis = useMemo(() => (parsed.success ? analyzeFunction(parsed, { domainMin: -10, domainMax: 10 }) : null), [parsed]);

  // Graph tab only (avoids computing tangent / roots on other tabs)
  const tangent = useMemo(() => {
    if (activeTab !== 'graph' || !parsed.success) return null;
    return getTangentAt(parsed, x0);
  }, [activeTab, parsed, x0]);

  const mRoots = useMemo(() => {
    if (activeTab !== 'graph' || !parsed.success) return [];
    return findIntersectionsWithHorizontalLine(parsed, lineM, -10, 10);
  }, [activeTab, parsed, lineM]);

  // BBT tab only (avoids computing table on graph/integral tabs)
  const bbtData = useMemo(() => {
    if (activeTab !== 'bbt' || !parsed.success) return null;
    return buildBBT(parsed, -8, 8);
  }, [activeTab, parsed]);

  // Integral computations (avoids heavy symbolic nerdamer on graph/bbt tabs)
  const antiderivative = useMemo(() => {
    if (activeTab !== 'integral' || !parsed.success) return null;
    return computeAntiderivative(parsed.normalized);
  }, [activeTab, parsed]);

  const exactIntegral = useMemo(() => {
    if (activeTab !== 'integral' || !parsed.success) return null;
    const res = computeDefiniteIntegral(parsed, intA, intB);
    return res.value;
  }, [activeTab, parsed, intA, intB]);

  const riemannResult = useMemo(() => {
    if (activeTab !== 'integral' || !parsed.success) return null;
    return computeRiemannSum(parsed, intA, intB, riemannN, riemannMode);
  }, [activeTab, parsed, intA, intB, riemannN, riemannMode]);

  const revolutionResult = useMemo(() => {
    if (activeTab !== 'integral' || !parsed.success) return null;
    return computeRevolutionVolume(parsed, intA, intB);
  }, [activeTab, parsed, intA, intB]);

  // Viewport instance
  const viewport = useMemo(() => {
    return createViewport(canvasDim.width, canvasDim.height, viewportPan.x, viewportPan.y, viewportScale);
  }, [canvasDim.width, canvasDim.height, viewportPan.x, viewportPan.y, viewportScale]);

  // 2. High-Performance Stage Elements (Separating Static vs Dynamic for 60 FPS drag)
  // Static elements: Axes, Curve spline (180 points), Extrema/Asymptotes (do NOT recalculate on M/lineM drag)
  const staticGraphElements = useMemo(() => {
    if (activeTab !== 'graph' || !parsed.success) return [];
    const axes = buildAxesElements(viewport);
    const curves = buildCurveElements(parsed, viewport, analysis?.asymptotes?.vertical || []);
    const baseMarkers = buildMarkerElements(analysis, viewport, {});
    return [...axes, ...curves, ...baseMarkers];
  }, [activeTab, parsed, viewport, analysis]);

  // Dynamic elements: Point M, Tangent line, Line y=m with roots (instant re-render during drag)
  const dynamicGraphElements = useMemo(() => {
    if (activeTab !== 'graph' || !parsed.success) return [];
    const dynamicMarkers = buildMarkerElements(null, viewport, {
      lineM,
      mRoots,
      pointM: tangent?.y0 !== null ? { x: x0, y: tangent?.y0 } : null,
    });
    const tang = buildTangentElements(tangent, viewport);
    return [...dynamicMarkers, ...tang];
  }, [activeTab, parsed, viewport, lineM, mRoots, tangent, x0]);

  // Render to Canvas
  useEffect(() => {
    if (!parsed.success) return;

    let elements = [];

    if (activeTab === 'graph') {
      elements = [...staticGraphElements, ...dynamicGraphElements];
    } else if (activeTab === 'integral') {
      const axes = buildAxesElements(viewport);
      const curves = buildCurveElements(parsed, viewport, analysis?.asymptotes?.vertical || []);

      if (show3D) {
        const solid3d = buildSolid3DElements(parsed, intA, intB, rotX, rotY, viewport);
        elements = [...axes, ...curves, ...solid3d];
      } else {
        const riemann = buildRiemannElements(riemannResult, viewport);
        elements = [...axes, ...curves, ...riemann];
      }
    }

    elementsRef.current = elements;
    if (canvasRef.current) {
      renderElementsToCanvas(canvasRef.current, elements);
    }
  }, [
    activeTab,
    parsed,
    analysis,
    staticGraphElements,
    dynamicGraphElements,
    show3D,
    intA,
    intB,
    riemannResult,
    rotX,
    rotY,
    viewport,
  ]);

  // Repaint canvas on tab change or dimension update
  useEffect(() => {
    if (canvasRef.current && elementsRef.current.length > 0) {
      renderElementsToCanvas(canvasRef.current, elementsRef.current);
    }
  }, [canvasDim, activeTab]);

  // 3. Pointer event handlers on Canvas
  const handlePointerDown = (e) => {
    if (!canvasRef.current) return;
    const rect = canvasRef.current.getBoundingClientRect();
    const sx = e.clientX - rect.left;
    const sy = e.clientY - rect.top;

    if (activeTab === 'graph' && parsed.success) {
      // 1. Check point M proximity
      const y0 = parsed.evaluate(x0);
      if (y0 !== null) {
        const mScreen = viewport.toScreen(x0, y0);
        const distM = Math.hypot(sx - mScreen.sx, sy - mScreen.sy);
        if (distM < 26) {
          setDragTarget('M');
          if (e.target.setPointerCapture && e.pointerId) e.target.setPointerCapture(e.pointerId);
          return;
        }
      }

      // 2. Check line y = m proximity
      const lineSy = viewport.toScreen(0, lineM).sy;
      if (Math.abs(sy - lineSy) < 18) {
        setDragTarget('lineM');
        if (e.target.setPointerCapture && e.pointerId) e.target.setPointerCapture(e.pointerId);
        return;
      }

      // 3. Otherwise: Pan stage
      setDragTarget('pan');
      setDragStartPos({ x: e.clientX, y: e.clientY });
      setDragStartPan({ x: viewportPan.x, y: viewportPan.y });
      if (e.target.setPointerCapture && e.pointerId) e.target.setPointerCapture(e.pointerId);
    } else if (activeTab === 'integral' && show3D) {
      setDragTarget('3D');
      setDragStartPos({ x: e.clientX, y: e.clientY });
      setDragStartRots({ rotX, rotY });
      if (e.target.setPointerCapture && e.pointerId) e.target.setPointerCapture(e.pointerId);
    } else if (activeTab === 'integral') {
      setDragTarget('pan');
      setDragStartPos({ x: e.clientX, y: e.clientY });
      setDragStartPan({ x: viewportPan.x, y: viewportPan.y });
      if (e.target.setPointerCapture && e.pointerId) e.target.setPointerCapture(e.pointerId);
    }
  };

  const handlePointerMove = (e) => {
    if (!dragTarget || !canvasRef.current) return;
    const clientX = e.clientX;
    const clientY = e.clientY;

    if (rafRef.current) return; // Drop redundant events within same frame

    rafRef.current = requestAnimationFrame(() => {
      rafRef.current = null;
      if (!canvasRef.current) return;
      const rect = canvasRef.current.getBoundingClientRect();
      const sx = clientX - rect.left;
      const sy = clientY - rect.top;
      const mathPos = viewport.toMath(sx, sy);

      if (dragTarget === 'M') {
        const clampedX = Math.max(-8, Math.min(8, mathPos.x));
        setX0(clampedX);
      } else if (dragTarget === 'lineM') {
        const clampedM = Math.max(-10, Math.min(10, mathPos.y));
        setLineM(clampedM);
      } else if (dragTarget === '3D') {
        const dx = clientX - dragStartPos.x;
        const dy = clientY - dragStartPos.y;
        setRotY(dragStartRots.rotY + dx * 0.012);
        setRotX(dragStartRots.rotX + dy * 0.012);
      } else if (dragTarget === 'pan') {
        const dx = clientX - dragStartPos.x;
        const dy = clientY - dragStartPos.y;
        setViewportPan({
          x: dragStartPan.x - dx / viewportScale,
          y: dragStartPan.y + dy / viewportScale,
        });
      }
    });
  };

  const handlePointerUp = (e) => {
    if (rafRef.current) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    }
    if (e.target.releasePointerCapture && e.pointerId) {
      try { e.target.releasePointerCapture(e.pointerId); } catch (_) {}
    }
    setDragTarget(null);
  };

  const handleWheel = (e) => {
    e.preventDefault();
    const factor = e.deltaY < 0 ? 1.15 : 0.87;
    setViewportScale((s) => Math.max(15, Math.min(120, s * factor)));
  };

  // 4. Stamping to chalkboard
  const handleStampToChalkboard = async () => {
    setStampStatus('Đang ghim...');
    console.log('[MathStudio] handleStampToChalkboard started, activeTab:', activeTab);
    try {
      let imageBase64 = null;
      let svgContent = null;
      let aspectRatio = 1.6;

      if (activeTab === 'bbt') {
        const svgEl = document.getElementById('bbt-svg');
        if (svgEl) {
          svgContent = new XMLSerializer().serializeToString(svgEl);
          aspectRatio = 2.7; // Wide SGK textbook aspect ratio
        }
      } else if (canvasRef.current) {
        const dataUrl = canvasRef.current.toDataURL('image/png');
        imageBase64 = dataUrl.split(',')[1];
        svgContent = exportElementsToSvg(elementsRef.current, canvasDim.width, canvasDim.height);
        if (canvasDim.height > 0) {
          aspectRatio = canvasDim.width / canvasDim.height;
        }
      }

      const success = await Bridge.insertAnnotation({
        title: `ƒ(x) = ${debouncedFormula}`,
        imageBase64,
        svgContent,
        aspectRatio,
        metadata: {
          formula: debouncedFormula,
          activeTab,
        },
      });

      console.log('[MathStudio] Bridge.insertAnnotation returned:', success);
      if (success) {
        setStampStatus('Đã ghim thành công!');
      } else {
        setStampStatus('Đã ghim (chế độ độc lập)!');
      }
      setTimeout(() => setStampStatus(''), 2500);
    } catch (err) {
      console.error('[MathStudio] Error stamping annotation:', err);
      setStampStatus('Lỗi khi ghim');
      setTimeout(() => setStampStatus(''), 2500);
    }
  };

  return (
    <div className="math-studio-container">
      {/* Top Header */}
      <header className="studio-header">
        <div className="brand-group">
          <span className="brand-badge-math">ƒ(x)</span>
          <span className="brand-text">HỌC LỰC MATH STUDIO</span>
        </div>

        {/* Tab Navigation */}
        <div className="tab-switcher">
          <button
            className={`tab-btn ${activeTab === 'graph' ? 'active' : ''}`}
            onClick={() => setActiveTab('graph')}
          >
            Đồ thị & Khảo sát
          </button>
          <button
            className={`tab-btn ${activeTab === 'bbt' ? 'active' : ''}`}
            onClick={() => setActiveTab('bbt')}
          >
            Bảng biến thiên
          </button>
          <button
            className={`tab-btn ${activeTab === 'integral' ? 'active' : ''}`}
            onClick={() => setActiveTab('integral')}
          >
            Tích phân & Tròn xoay
          </button>
        </div>

        {/* Action Buttons */}
        <div className="header-actions">
          {stampStatus && <span className="stamp-status-badge">{stampStatus}</span>}
          <button id="btn-stamp-board" className="btn-stamp" onClick={handleStampToChalkboard}>
            📌 Ghim vào bảng
          </button>
          <button id="btn-close-studio" className="btn-close" onClick={() => Bridge.close()}>
            ✕
          </button>
        </div>
      </header>

      {/* Main Studio Body */}
      <div className="studio-body">
        {/* Left Parameter Panel (Hidden on full BBT) */}
        {activeTab !== 'bbt' && (
          <aside className="left-panel">
            {/* Formula Input & Slim y' Row */}
            <div className="formula-box">
              <div className="formula-input-row">
                <span className="formula-prefix">f(x) =</span>
                <input
                  id="formula-input"
                  type="text"
                  value={formulaInput}
                  onChange={(e) => setFormulaInput(e.target.value)}
                  placeholder="Nhập hàm số: 2x^2 - 3x + 1, x^3 - 3x, sin(x)..."
                  className="formula-input"
                />
              </div>

              {/* Dynamic y' Derivative */}
              <div className="derivative-row">
                <span className="deriv-prefix">y' =</span>
                <span id="derivative-display" className="deriv-value">
                  {derivative?.display || (parsed.error ? '—' : 'Đang tính...')}
                </span>
              </div>

              {!parsed.success && (
                <div className="formula-error-msg">⚠️ {parsed.error}</div>
              )}
            </div>

            {/* Tab Specific Left Content */}
            {activeTab === 'graph' && (
              <GraphPage
                analysis={analysis}
                antiderivative={antiderivative}
                tangent={tangent}
                x0={x0}
                setX0={setX0}
                lineM={lineM}
                setLineM={setLineM}
                mRoots={mRoots}
              />
            )}

            {activeTab === 'integral' && (
              <IntegralPage
                a={intA}
                setA={setIntA}
                b={intB}
                setB={setIntB}
                n={riemannN}
                setN={setRiemannN}
                mode={riemannMode}
                setMode={setRiemannMode}
                show3D={show3D}
                setShow3D={setShow3D}
                exactIntegral={exactIntegral}
                riemannResult={riemannResult}
                revolutionResult={revolutionResult}
              />
            )}
          </aside>
        )}

        {/* Right Stage / Canvas Area */}
        <main className={`stage-area ${activeTab === 'bbt' ? 'full-stage' : ''}`}>
          {activeTab === 'bbt' ? (
            <BBTPage
              bbtData={bbtData}
              formula={debouncedFormula}
              derivDisplay={derivative?.display || '—'}
            />
          ) : (
            <div className="canvas-wrapper" ref={canvasContainerRef}>
              <canvas
                ref={canvasRef}
                id="math-stage-canvas"
                className="math-stage-canvas"
                width={canvasDim.width}
                height={canvasDim.height}
                onPointerDown={handlePointerDown}
                onPointerMove={handlePointerMove}
                onPointerUp={handlePointerUp}
                onWheel={handleWheel}
                style={{
                  width: '100%',
                  height: '100%',
                  display: 'block',
                  cursor: dragTarget === 'M' || dragTarget === 'lineM' || dragTarget === '3D' || dragTarget === 'pan'
                    ? 'grabbing'
                    : (show3D && activeTab === 'integral' ? 'grab' : 'crosshair'),
                  touchAction: 'none',
                }}
              />

              {/* Viewport Zoom / Reset Controls */}
              <div className="viewport-toolbar">
                <button
                  className="tool-btn"
                  onClick={() => setViewportScale((s) => Math.min(120, s * 1.25))}
                  title="Phóng to"
                >
                  🔍+
                </button>
                <button
                  className="tool-btn"
                  onClick={() => setViewportScale((s) => Math.max(15, s * 0.8))}
                  title="Thu nhỏ"
                >
                  🔍-
                </button>
                <button
                  className="tool-btn"
                  onClick={() => {
                    setViewportScale(40);
                    setViewportPan({ x: 0, y: 0 });
                  }}
                  title="Khôi phục góc nhìn"
                >
                  ↺ Reset
                </button>
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  componentDidCatch(error, info) {
    console.error('[MathStudio] Runtime Error:', error, info);
  }
  render() {
    if (this.state.hasError) {
      return (
        <div style={{ color: '#f87171', background: '#11171b', padding: '24px', fontFamily: 'monospace', height: '100%', boxSizing: 'border-box' }}>
          <h3>⚠️ Đã xảy ra lỗi giao diện Math Studio</h3>
          <p>{this.state.error?.toString()}</p>
          <button
            onClick={() => this.setState({ hasError: false, error: null })}
            style={{ padding: '6px 14px', background: '#2563eb', color: '#fff', border: 'none', borderRadius: 4, cursor: 'pointer', marginTop: 12 }}
          >
            Tải lại giao diện
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

const rootEl = document.getElementById('root');
if (rootEl) {
  createRoot(rootEl).render(
    <ErrorBoundary>
      <MathStudioApp />
    </ErrorBoundary>
  );
}
