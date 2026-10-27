/**
 * JSXGraph View3D Board Controller
 * Provides interactive 3D Geometry models (SGK THPT) with native trackball rotation.
 * Replaces legacy custom 3D projection engine with zero-drift JSXGraph View3D.
 */

let active3DBoard = null;

export function destroy3DBoard(containerId = 'geometry3dContainer') {
  if (active3DBoard) {
    try {
      if (typeof window !== 'undefined' && window.JXG) {
        window.JXG.JSXGraph.freeBoard(active3DBoard);
      }
    } catch (_) {}
    active3DBoard = null;
  }
  const el = typeof containerId === 'string' ? document.getElementById(containerId) : containerId;
  if (el) el.innerHTML = '';
}

export function renderJSXGraph3D(containerId, preset = 'pyramid_quad', options = {}) {
  if (typeof window === 'undefined' || !window.JXG) return null;

  const container = typeof containerId === 'string' ? document.getElementById(containerId) : containerId;
  if (!container) return null;

  destroy3DBoard(containerId);

  const { theme = 'light' } = options;
  const isDark = theme === 'dark' || theme === 'chalkboard';
  const colors = {
    line: isDark ? '#ffffff' : '#0b2348',
    axis: isDark ? '#94a3b8' : '#64748b',
    fill: isDark ? '#38bdf8' : '#1e88ff',
    dashed: isDark ? '#cbd5e1' : '#94a3b8'
  };

  const board = window.JXG.JSXGraph.initBoard(container.id || containerId, {
    boundingbox: [-7, 7, 7, -7],
    keepaspectratio: false,
    axis: false,
    showNavigation: false,
    showCopyright: false
  });

  const view = board.create('view3d', [
    [-4.5, -3.5], [9, 7],
    [[-2.2, 2.2], [-2.2, 2.2], [-2.2, 2.2]]
  ], {
    xPlaneRear: { visible: false },
    yPlaneRear: { visible: false },
    zPlaneRear: { visible: false },
    xAxis: { strokeColor: colors.axis, strokeWidth: 1 },
    yAxis: { strokeColor: colors.axis, strokeWidth: 1 },
    zAxis: { strokeColor: colors.axis, strokeWidth: 1 }
  });

  switch (preset) {
    case 'pyramid_tri': {
      // S.ABC
      const A = view.create('point3d', [-1.4, -1.2, -1.2], { name: 'A', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const B = view.create('point3d', [1.4, -1.0, -1.2], { name: 'B', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const C = view.create('point3d', [0.2, 1.3, -1.2], { name: 'C', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const S = view.create('point3d', [0, 0, 1.8], { name: 'S', size: 4, strokeColor: colors.line, fillColor: colors.fill });

      view.create('line3d', [A, B], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [B, C], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [C, A], { strokeColor: colors.dashed, strokeWidth: 1.5, dash: 2 }); // khuất
      view.create('line3d', [S, A], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [S, B], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [S, C], { strokeColor: colors.line, strokeWidth: 2 });
      break;
    }

    case 'pyramid_quad': {
      // S.ABCD
      const A = view.create('point3d', [-1.4, -1.2, -1.2], { name: 'A', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const B = view.create('point3d', [1.4, -1.2, -1.2], { name: 'B', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const C = view.create('point3d', [1.2, 1.2, -1.2], { name: 'C', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const D = view.create('point3d', [-1.2, 1.2, -1.2], { name: 'D', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const S = view.create('point3d', [0, 0, 1.8], { name: 'S', size: 4, strokeColor: colors.line, fillColor: colors.fill });

      view.create('line3d', [A, B], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [B, C], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [C, D], { strokeColor: colors.dashed, strokeWidth: 1.5, dash: 2 });
      view.create('line3d', [D, A], { strokeColor: colors.dashed, strokeWidth: 1.5, dash: 2 });
      view.create('line3d', [S, A], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [S, B], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [S, C], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [S, D], { strokeColor: colors.line, strokeWidth: 1.8, dash: 2 });
      break;
    }

    case 'prism_tri': {
      // ABC.A'B'C'
      const A = view.create('point3d', [-1.2, -1.0, -1.4], { name: 'A', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const B = view.create('point3d', [1.4, -0.8, -1.4], { name: 'B', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const C = view.create('point3d', [0.1, 1.2, -1.4], { name: 'C', size: 3, strokeColor: colors.line, fillColor: colors.fill });

      const A1 = view.create('point3d', [-1.2, -1.0, 1.4], { name: "A'", size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const B1 = view.create('point3d', [1.4, -0.8, 1.4], { name: "B'", size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const C1 = view.create('point3d', [0.1, 1.2, 1.4], { name: "C'", size: 3, strokeColor: colors.line, fillColor: colors.fill });

      view.create('line3d', [A, B], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [B, C], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [C, A], { strokeColor: colors.dashed, strokeWidth: 1.5, dash: 2 });

      view.create('line3d', [A1, B1], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [B1, C1], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [C1, A1], { strokeColor: colors.line, strokeWidth: 2 });

      view.create('line3d', [A, A1], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [B, B1], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [C, C1], { strokeColor: colors.dashed, strokeWidth: 1.5, dash: 2 });
      break;
    }

    case 'cone': {
      // Nón
      const S = view.create('point3d', [0, 0, 1.8], { name: 'S', size: 4, strokeColor: colors.line, fillColor: colors.fill });
      const O = view.create('point3d', [0, 0, -1.2], { name: 'O', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      view.create('line3d', [S, O], { strokeColor: colors.dashed, strokeWidth: 1.5, dash: 2 });

      // Circular base approximation
      const steps = 24;
      const r = 1.4;
      const pts = [];
      for (let i = 0; i < steps; i++) {
        const rad = (i / steps) * 2 * Math.PI;
        pts.push(view.create('point3d', [r * Math.cos(rad), r * Math.sin(rad), -1.2], { visible: false }));
      }
      for (let i = 0; i < steps; i++) {
        const next = pts[(i + 1) % steps];
        const isBack = pts[i].Y() > 0;
        view.create('line3d', [pts[i], next], {
          strokeColor: isBack ? colors.dashed : colors.line,
          strokeWidth: isBack ? 1.2 : 2,
          dash: isBack ? 2 : 0
        });
      }
      // 2 Generators
      view.create('line3d', [S, pts[0]], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [S, pts[Math.floor(steps / 2)]], { strokeColor: colors.line, strokeWidth: 2 });
      break;
    }

    case 'cylinder': {
      // Trụ
      const O1 = view.create('point3d', [0, 0, -1.3], { name: 'O', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const O2 = view.create('point3d', [0, 0, 1.3], { name: "O'", size: 3, strokeColor: colors.line, fillColor: colors.fill });
      view.create('line3d', [O1, O2], { strokeColor: colors.dashed, strokeWidth: 1.5, dash: 2 });

      const steps = 20;
      const r = 1.3;
      const btm = [];
      const top = [];
      for (let i = 0; i < steps; i++) {
        const rad = (i / steps) * 2 * Math.PI;
        btm.push(view.create('point3d', [r * Math.cos(rad), r * Math.sin(rad), -1.3], { visible: false }));
        top.push(view.create('point3d', [r * Math.cos(rad), r * Math.sin(rad), 1.3], { visible: false }));
      }
      for (let i = 0; i < steps; i++) {
        const nextB = btm[(i + 1) % steps];
        const nextT = top[(i + 1) % steps];
        const isBack = btm[i].Y() > 0;
        view.create('line3d', [btm[i], nextB], { strokeColor: isBack ? colors.dashed : colors.line, strokeWidth: 1.5, dash: isBack ? 2 : 0 });
        view.create('line3d', [top[i], nextT], { strokeColor: colors.line, strokeWidth: 2 });
      }
      view.create('line3d', [btm[0], top[0]], { strokeColor: colors.line, strokeWidth: 2 });
      view.create('line3d', [btm[Math.floor(steps / 2)], top[Math.floor(steps / 2)]], { strokeColor: colors.line, strokeWidth: 2 });
      break;
    }

    case 'sphere': {
      // Cầu
      const O = view.create('point3d', [0, 0, 0], { name: 'O', size: 3, strokeColor: colors.line, fillColor: colors.fill });
      const steps = 32;
      const r = 1.5;
      const xyPts = [];
      for (let i = 0; i < steps; i++) {
        const rad = (i / steps) * 2 * Math.PI;
        xyPts.push(view.create('point3d', [r * Math.cos(rad), r * Math.sin(rad), 0], { visible: false }));
      }
      for (let i = 0; i < steps; i++) {
        const next = xyPts[(i + 1) % steps];
        const isBack = xyPts[i].Y() > 0;
        view.create('line3d', [xyPts[i], next], { strokeColor: isBack ? colors.dashed : colors.line, strokeWidth: 1.5, dash: isBack ? 2 : 0 });
      }
      break;
    }
  }

  active3DBoard = board;
  return board;
}

