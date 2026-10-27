/**
 * Unit Test Suite for Math Studio Core Modules
 */

import { parseAndAnalyze } from '../plugins/math_studio/ui/core/expression_parser.js';
import { solveIntegral } from '../plugins/math_studio/ui/core/integral_solver.js';
import { generateBbtSvg } from '../plugins/math_studio/ui/render/bbt_generator.js';
import { generateGraphSvg } from '../plugins/math_studio/ui/render/graph_plotter.js';

console.log('🧪 Bắt đầu kiểm thử Math Studio Engine...');

// Test 1: Hàm bậc 3 có 2 cực trị y = x^3 - 3x^2 + 2
{
  const res = parseAndAnalyze('x^3 - 3*x^2 + 2');
  console.assert(res.extrema.length === 2, 'Hàm bậc 3 phải có 2 cực trị');
  const cd = res.extrema.find(e => e.type === 'CĐ');
  const ct = res.extrema.find(e => e.type === 'CT');
  console.assert(Math.abs(cd.x - 0) < 0.1 && Math.abs(cd.y - 2) < 0.1, 'CĐ phải là (0, 2)');
  console.assert(Math.abs(ct.x - 2) < 0.1 && Math.abs(ct.y - (-2)) < 0.1, 'CT phải là (2, -2)');
  console.log('✅ Test 1: Bậc 3 có 2 cực trị (y = x^3 - 3x^2 + 2) ĐẠT');
}

// Test 2: Bậc 3 đơn điệu y = x^3 + 3x
{
  const res = parseAndAnalyze('x^3 + 3*x');
  console.assert(res.extrema.length === 0, 'Hàm bậc 3 y = x^3 + 3x không có cực trị');
  console.assert(res.tableData.intervals[0].sign === '+', 'Hàm luôn đồng biến (+)');
  console.log('✅ Test 2: Bậc 3 đơn điệu (y = x^3 + 3x) ĐẠT');
}

// Test 3: Trùng phương y = x^4 - 2x^2 - 1
{
  const res = parseAndAnalyze('x^4 - 2*x^2 - 1');
  console.assert(res.extrema.length === 3, 'Hàm trùng phương phải có 3 cực trị');
  const max = res.extrema.find(e => e.type === 'CĐ');
  console.assert(Math.abs(max.x - 0) < 0.1 && Math.abs(max.y - (-1)) < 0.1, 'Cực đại phải là (0, -1)');
  console.log('✅ Test 3: Trùng phương 3 cực trị (y = x^4 - 2x^2 - 1) ĐẠT');
}

// Test 4: Phân thức bậc 1/1 y = (2x + 1)/(x - 1)
{
  const res = parseAndAnalyze('(2*x + 1)/(x - 1)');
  console.assert(res.asymptotes.length >= 1, 'Phải có tiệm cận');
  const tcđ = res.asymptotes.find(a => a.type === 'TCĐ');
  console.assert(Math.abs(tcđ.val - 1) < 1e-4, 'TCĐ phải là x = 1');
  console.log('✅ Test 4: Phân thức bậc 1/1 (y = (2x+1)/(x-1)) ĐẠT');
}

// Test 5: Phân thức bậc 2/1 có tiệm cận
{
  const res = parseAndAnalyze('(x^2 - x + 1)/(x - 1)');
  const tcđ = res.asymptotes.find(a => a.type === 'TCĐ');
  console.assert(Math.abs(tcđ.val - 1) < 1e-4, 'TCĐ phải là x = 1');
  console.log('✅ Test 5: Phân thức bậc 2/1 có tiệm cận ĐẠT');
}

// Test 6: Tích phân & diện tích hình phẳng
{
  const analysis = parseAndAnalyze('x^2 - 2');
  const res = solveIntegral(analysis, -1, 2);
  console.assert(Math.abs(res.signedIntegral - (-3)) < 0.1, 'Tích phân xác định phải bằng -3');
  console.assert(res.area > 0, 'Diện tích phải > 0');
  console.log('✅ Test 6: Tích phân & diện tích hình phẳng ĐẠT');
}

// Test 7: Sinh SVG Bảng biến thiên và Đồ thị
{
  const analysis = parseAndAnalyze('x^3 - 3*x');
  const bbtSvg = generateBbtSvg(analysis);
  console.assert(bbtSvg.includes('<svg') && bbtSvg.includes('</svg>'), 'BBT phải sinh ra mã SVG hợp lệ');

  const graphSvg = generateGraphSvg(analysis);
  console.assert(graphSvg.includes('<svg') && graphSvg.includes('</svg>'), 'Graph phải sinh ra mã SVG hợp lệ');
  console.log('✅ Test 7: Sinh SVG Bảng biến thiên và Đồ thị ĐẠT');
}

// Test 8: Sinh SVG chứa số mũ đạt chuẩn XML cân bằng thẻ
{
  const analysis = parseAndAnalyze('x^3 - 3*x');
  const graphSvg = generateGraphSvg(analysis);
  const openTspanCount = (graphSvg.match(/<tspan/g) || []).length;
  const closeTspanCount = (graphSvg.match(/<\/tspan>/g) || []).length;
  console.assert(openTspanCount === closeTspanCount, `Thẻ <tspan> phải cân bằng XML, mở: ${openTspanCount}, đóng: ${closeTspanCount}`);
  console.log('✅ Test 8: Sinh SVG chứa số mũ đạt chuẩn XML cân bằng thẻ ĐẠT');
}

// Test 9: Sinh SVG chế độ Chalkboard (Option A: không vẽ lưới phụ, nhãn cực trị vàng sáng #fde047)
{
  const analysis = parseAndAnalyze('x^3 - 3*x');
  const chalkSvg = generateGraphSvg(analysis, null, { theme: 'chalkboard' });
  console.assert(!chalkSvg.includes('stroke="rgba(255, 255, 255, 0.18)"'), 'Chalkboard SVG không được vẽ lưới phụ đè lên bảng');
  console.assert(chalkSvg.includes('#fde047'), 'Chalkboard SVG phải dùng màu phấn vàng sáng #fde047 cho nhãn cực trị');
  console.log('✅ Test 9: Sinh SVG chế độ Chalkboard (Option A) ĐẠT');
}

console.log('🎉 TẤT CẢ 9/9 TESTS CỐT LÕI ĐẠT 100%!');
