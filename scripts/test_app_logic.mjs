import { parseAndAnalyze } from '../plugins/math_studio/ui/core/expression_parser.js';
import { solveIntegral } from '../plugins/math_studio/ui/core/integral_solver.js';
import { generateGraphSvg } from '../plugins/math_studio/ui/render/graph_plotter.js';
import { generateBbtSvg } from '../plugins/math_studio/ui/render/bbt_generator.js';
import { computeFormulaFromDrag } from '../plugins/math_studio/ui/core/curve_manipulator.js';

console.log('🧪 Running App Logic Simulation...');

const expr = '1.5x^3 - 4.5x + 1';
const analysis = parseAndAnalyze(expr);
console.log('1. Parsed successfully:', analysis.type);

const integral = solveIntegral(analysis, -1, 2);
console.log('2. Integral solved successfully:', integral.displayArea, integral.antiderivative);

const graphSvg = generateGraphSvg(analysis, integral, { width: 440, height: 380, theme: 'light' });
console.log('3. Graph SVG generated successfully, length:', graphSvg.length);
if (graphSvg.includes('y = y =')) {
  throw new Error('Graph SVG still contains duplicate "y = y = "!');
}

const bbtSvg = generateBbtSvg(analysis, { width: 440, height: 220, theme: 'light' });
console.log('4. BBT SVG generated successfully, length:', bbtSvg.length);

const dragged = computeFormulaFromDrag(analysis, { type: 'extremum', idx: 0 }, -1, 4.5);
console.log('5. Drag calculation successful:', dragged);

// 6. Test Store Dispatcher
const { MathStudioStore } = await import('../plugins/math_studio/ui/core/store.js');
const testStore = new MathStudioStore({ formula: 'x^2 - 2' });
let notified = false;
testStore.subscribe((state) => { notified = true; });
testStore.dispatch({ type: 'SET_FORMULA', formula: 'sin(x)^2 + 1' });
if (!notified || testStore.getState().formula !== 'sin(x)^2 + 1') {
  throw new Error('Store subscription failed to notify update');
}
console.log('6. Store dispatch and subscription verified successfully! Der:', testStore.getState().derFormulaDisplay);

console.log('🎉 ALL APP LOGIC SIMULATIONS PASSED 100%!');

