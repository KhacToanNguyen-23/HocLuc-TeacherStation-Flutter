/**
 * 3D Solid of Revolution rendered directly on the graph stage with hidden-line separation.
 * Follows THPT standard: back occluded surfaces (z < 0) are dashed; front visible surfaces (z >= 0) are solid.
 */
export function buildSolid3DElements(parsed, a, b, rotX = 0.5, rotY = 0.6, viewport, options = {}) {
  const elements = [];
  const { toScreen } = viewport;
  const numRings = options.numRings ?? 12;
  const ringSegments = 24;

  // 3D rotation transform
  const cosY = Math.cos(rotY);
  const sinY = Math.sin(rotY);
  const cosX = Math.cos(rotX);
  const sinX = Math.sin(rotX);

  const project3D = (x3d, y3d, z3d) => {
    // 1. Rotate around Y axis (rotY)
    const x1 = x3d * cosY + z3d * sinY;
    const z1 = -x3d * sinY + z3d * cosY;

    // 2. Rotate around X axis (rotX)
    const y2 = y3d * cosX - z1 * sinX;
    const z2 = y3d * sinX + z1 * cosX;

    const screen = toScreen(x1, y2);
    return {
      sx: screen.sx,
      sy: screen.sy,
      zDepth: z2,
      mathX: x1,
      mathY: y2,
    };
  };

  const dx = (b - a) / (numRings - 1);
  const ringPoints = []; // [ringIdx][thetaIdx]

  // 1. Generate rings along [a, b]
  for (let r = 0; r < numRings; r++) {
    const x3d = a + r * dx;
    const radius = Math.abs(parsed.evaluate(x3d) ?? 0);
    const ringPts = [];

    for (let s = 0; s <= ringSegments; s++) {
      const theta = (s / ringSegments) * 2 * Math.PI;
      const y3d = radius * Math.cos(theta);
      const z3d = radius * Math.sin(theta);
      const projected = project3D(x3d, y3d, z3d);
      ringPts.push(projected);
    }
    ringPoints.push({ x3d, radius, pts: ringPts });

    // Split ring into contiguous solid (z >= 0) and dashed (z < 0) arc runs
    if (radius > 1e-4) {
      let currentRun = [];
      let currentIsVisible = ringPts[0].zDepth >= 0;

      for (let s = 0; s < ringPts.length; s++) {
        const pt = ringPts[s];
        const isVis = pt.zDepth >= 0;

        if (isVis !== currentIsVisible && currentRun.length > 1) {
          // Commit previous run
          elements.push(createArcElement(currentRun, currentIsVisible, `ring-${r}-${elements.length}`));
          currentRun = [currentRun[currentRun.length - 1]]; // overlap endpoint
          currentIsVisible = isVis;
        }
        currentRun.push(pt);
      }
      if (currentRun.length > 1) {
        elements.push(createArcElement(currentRun, currentIsVisible, `ring-${r}-${elements.length}`));
      }
    }
  }

  // 2. Longitudinal generators (meridian lines: top, bottom, front, back)
  const meridianCount = 4;
  for (let m = 0; m < meridianCount; m++) {
    const theta = (m / meridianCount) * 2 * Math.PI;
    const meridianPts = [];

    for (let r = 0; r < numRings; r++) {
      const x3d = a + r * dx;
      const radius = Math.abs(parsed.evaluate(x3d) ?? 0);
      const y3d = radius * Math.cos(theta);
      const z3d = radius * Math.sin(theta);
      meridianPts.push(project3D(x3d, y3d, z3d));
    }

    if (meridianPts.length > 1) {
      const isVisible = meridianPts[Math.floor(meridianPts.length / 2)].zDepth >= 0;
      elements.push(createArcElement(meridianPts, isVisible, `meridian-${m}`));
    }
  }

  // 3. Central rotation axis (Ox segment from a to b)
  const axisStart = project3D(a - 0.5, 0, 0);
  const axisEnd = project3D(b + 0.5, 0, 0);
  elements.push({
    id: 'solid3d-rot-axis',
    type: 'line',
    x: axisStart.sx,
    y: axisStart.sy,
    width: axisEnd.sx - axisStart.sx,
    height: axisEnd.sy - axisStart.sy,
    points: [[0, 0], [axisEnd.sx - axisStart.sx, axisEnd.sy - axisStart.sy]],
    strokeColor: '#94a3b8',
    strokeStyle: 'dashed',
    strokeWidth: 1.5,
    locked: true,
    customType: 'solid3d-axis',
  });

  return elements;
}

function createArcElement(pts, isVisible, idSuffix) {
  const base = pts[0];
  const relativePoints = pts.map((p) => [p.sx - base.sx, p.sy - base.sy]);

  let minX = 0, maxX = 0, minY = 0, maxY = 0;
  for (const [px, py] of relativePoints) {
    if (px < minX) minX = px;
    if (px > maxX) maxX = px;
    if (py < minY) minY = py;
    if (py > maxY) maxY = py;
  }

  return {
    id: `solid3d-arc-${idSuffix}`,
    type: 'line',
    x: base.sx,
    y: base.sy,
    width: Math.max(1, maxX - minX),
    height: Math.max(1, maxY - minY),
    points: relativePoints,
    strokeColor: isVisible ? '#1d4ed8' : '#94a3b8', // Academic royal blue front, muted slate dashed back
    strokeStyle: isVisible ? 'solid' : 'dashed',
    strokeLineDash: isVisible ? undefined : [5, 4],
    strokeWidth: isVisible ? 1.5 : 1.0,
    roughness: 0,
    roundness: { type: 2 },
    locked: true,
    customType: 'solid3d-arc',
  };
}

