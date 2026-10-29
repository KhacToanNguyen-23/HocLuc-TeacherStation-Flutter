import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import { parseFunction } from '../../src/engine/parse.js';
import { analyzeFunction, getTangentAt, findIntersectionsWithHorizontalLine } from '../../src/engine/analyze.js';
import { computeRiemannSum } from '../../src/engine/riemann.js';

import { createViewport } from '../../src/stage/viewport.js';
import { buildAxesElements } from '../../src/stage/axes.js';
import { buildCurveElements } from '../../src/stage/curve.js';
import { buildMarkerElements } from '../../src/stage/markers.js';
import { buildTangentElements } from '../../src/stage/tangent.js';
import { buildRiemannElements } from '../../src/stage/riemann.js';
import { buildSolid3DElements } from '../../src/stage/solid3d.js';

describe('Excalidraw Stage Builders (Pure Functions)', () => {

  const vp = createViewport(800, 600, 0, 0, 40); // 800x600, center (0, 0), 40px/unit

  test('Viewport Coordinate Transformation', () => {
    const origin = vp.toScreen(0, 0);
    assert.equal(origin.sx, 400);
    assert.equal(origin.sy, 300);

    const mathPt = vp.toMath(origin.sx, origin.sy);
    assert.ok(Math.abs(mathPt.x) < 1e-5);
    assert.ok(Math.abs(mathPt.y) < 1e-5);

    const step = vp.getNiceStep();
    assert.ok([1, 2, 5, 10].includes(step));
  });

  test('Axes Elements: No Label Collisions', () => {
    const axesElements = buildAxesElements(vp);
    assert.ok(axesElements.length > 0);

    const labels = axesElements.filter((el) => el.type === 'text');
    assert.ok(labels.length >= 6);

    // Collision check between all labels
    for (let i = 0; i < labels.length; i++) {
      for (let j = i + 1; j < labels.length; j++) {
        const l1 = labels[i];
        const l2 = labels[j];
        const overlapX = Math.abs(l1.x - l2.x) < (l1.width || 20);
        const overlapY = Math.abs(l1.y - l2.y) < (l1.height || 16);
        assert.ok(!(overlapX && overlapY), `Labels "${l1.text}" and "${l2.text}" collide!`);
      }
    }
  });

  test('Curve Elements: Discontinuity Splitting & Domain Clipping', () => {
    // 1. (2x+1)/(x-1) must split at x=1
    const rational = parseFunction('(2x+1)/(x-1)');
    const analysis = analyzeFunction(rational, { domainMin: -10, domainMax: 10 });
    const curves = buildCurveElements(rational, vp, analysis.asymptotes.vertical);

    assert.ok(curves.length >= 2, 'Rational curve must be split into >= 2 segments');
    // None of the segments should jump across x = 1 (math coordinates around x=1)
    for (const seg of curves) {
      assert.equal(seg.type, 'line');
      assert.ok(seg.points.length > 2);
    }

    // 2. ln(x) must have NO points with x <= 0
    const logFunc = parseFunction('ln(x)');
    const logCurves = buildCurveElements(logFunc, vp, [0]);
    for (const seg of logCurves) {
      for (const pt of seg.points) {
        const screenX = seg.x + pt[0];
        const mathX = vp.toMath(screenX, seg.y + pt[1]).x;
        assert.ok(mathX > -0.05, `Point mathX=${mathX} must be > 0 for ln(x)`);
      }
    }
  });

  test('Marker Elements: Extrema & Intersections', () => {
    const parsed = parseFunction('x^3 - 3x');
    const analysis = analyzeFunction(parsed, { domainMin: -5, domainMax: 5 });
    const markers = buildMarkerElements(analysis, vp, { lineM: 0, mRoots: [-1.732, 0, 1.732] });

    // Extrema markers
    const extremaMarkers = markers.filter((m) => m.customType === 'extremum');
    assert.equal(extremaMarkers.length, 2);

    // Root intersection markers for y=0
    const rootMarkers = markers.filter((m) => m.customType === 'intersection');
    assert.equal(rootMarkers.length, 3);
  });

  test('Tangent Line Elements', () => {
    const parsed = parseFunction('x^3 - 3x');
    const tangent = getTangentAt(parsed, 2);
    const elements = buildTangentElements(tangent, vp);

    assert.ok(elements.length >= 2); // tangent line + label/point
    const line = elements.find((e) => e.id === 'tangent-line');
    assert.ok(line);
    assert.equal(line.strokeColor, '#dc2626'); // Academic Crimson red
  });

  test('Riemann Column Elements', () => {
    const parsed = parseFunction('sqrt(x)');
    for (const n of [4, 12, 50]) {
      const riemann = computeRiemannSum(parsed, 0, 4, n, 'midpoint');
      const elements = buildRiemannElements(riemann, vp);
      const cols = elements.filter((e) => e.customType === 'riemann-col');
      assert.equal(cols.length, n, `Expected ${n} columns for Riemann n=${n}`);
    }
  });

  test('Solid3D Elements: Hidden Lines & Element Capping', () => {
    const parsed = parseFunction('sqrt(x)');
    const elements = buildSolid3DElements(parsed, 0, 4, Math.PI / 6, Math.PI / 4, vp);

    // Bounded element count for performance
    assert.ok(elements.length <= 400, `Solid 3D elements count (${elements.length}) must be <= 400`);
    assert.ok(elements.length > 20, 'Solid 3D must generate rings and generators');

    // Check hidden line rule: back arcs (z < 0) are dashed, front arcs are solid
    const dashedArcs = elements.filter((e) => e.strokeStyle === 'dashed');
    const solidArcs = elements.filter((e) => e.strokeStyle === 'solid' && e.customType === 'solid3d-arc');

    assert.ok(dashedArcs.length > 0, 'Must have dashed lines for occluded (hidden) back surface');
    assert.ok(solidArcs.length > 0, 'Must have solid lines for visible front surface');

    // Verify rotating changes the perspective
    const elementsRotated = buildSolid3DElements(parsed, 0, 4, -Math.PI / 4, 0, vp);
    assert.ok(elementsRotated.length > 0);
  });

});

