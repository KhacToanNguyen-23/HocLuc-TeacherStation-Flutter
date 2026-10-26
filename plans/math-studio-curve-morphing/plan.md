# Plan: Đồ Thị Biến Dạng & Uốn Lượn Động Theo Điểm Cực Trị

Mode: Fast
Risk: normal — Tương tác uốn lượn đường cong động theo điểm cực trị trong graph_plotter.js và app.js
Spec: `plans/math-studio-curve-morphing/spec.md`
Date: 2026-10-26

---

## Architecture Strategy
1. **Dynamic Curve Evaluation (`graph_plotter.js`)**:
   - Chuyển `functiongraph` sang sử dụng hàm getter: `(x) => options.getEval ? options.getEval()(x) : analysis.eval(x)`.
   - Khi `board.update()` được kích hoạt, JSXGraph tự động lấy hàm tính toán mới nhất từ `currentAnalysis.eval` để vẽ lại đường cong tại vị trí chuột ngay tức thì.
2. **Real-time Drag Event & Inverse Fitting (`app.js`)**:
   - Khi kéo `extPt`, sự kiện `drag` gọi `computeFormulaFromDrag(currentAnalysis, { type: 'extremum', idx }, newX, newY)`:
     - Tính ra công thức hàm số mới.
     - Cập nhật `mathInput.value = newFormula`.
     - Phân tích cú pháp `currentAnalysis = parseAndAnalyze(newFormula)`.
     - Kích hoạt `board.update()` để đường cong uốn lượn dính chặt vào tâm điểm cực trị.
     - Cập nhật đồng bộ bảng toạ độ cực trị và diện tích tích phân nếu có.
3. **Dynamic Reactive Labels & Formula Badge (`graph_plotter.js`)**:
   - Nhãn của điểm cực trị đổi thành hàm getter: `() => `${ext.type} (${Number(extPt.X().toFixed(1))}; ${Number(extPt.Y().toFixed(1))})``.
   - Thẻ công thức góc trái đổi thành thẻ text reactive tự động cập nhật HTML theo `currentAnalysis.formulaLatex` / `mathInput.value`.
4. **Kiểm thử & Đóng gói**:
   - Chạy 5 test suites logic.
   - Đóng gói `.hlep` qua `validate_plugins.mjs`.
   - Đảm bảo 12 Bất biến kiến trúc đạt 100%.

---

## Phases

- [x] **Phase 1: Dynamic Reactive Function Graph (Đường cong uốn lượn 60 FPS)**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`, `app.js`
  - Đổi `functiongraph` sang hàm getter động `options.getEval`.
  - Kết nối sự kiện `drag` của cực trị với `computeFormulaFromDrag` và `board.update()`.
  - Đảm bảo đỉnh đường cong luôn dính chặt 100% vào điểm cực trị.

- [x] **Phase 2: Nhãn Tọa Độ & Huy Hiệu Công Thức Cập Nhật Thời Gian Thực**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`, `app.js`
  - Nhãn cực trị tự động nhảy số theo tọa độ chuột `extPt.X()`, `extPt.Y()`.
  - Huy hiệu góc trái tự động cập nhật công thức mới tương ứng.
  - Đồng bộ `mathInput` và bảng `extremaEditorContainer`.

- [x] **Phase 3: Kiểm Thử, Đóng Gói .hlep & Bất Biến Kiến Trúc**
  - Chạy `test_app_logic.mjs`, `test_curve_manipulator.mjs`, `test_geometry_3d.mjs`, `test_math_studio.mjs`, `test_revolution_solid.mjs`.
  - Đóng gói: `node scripts/validate_plugins.mjs --fix`.
  - Bất biến kiến trúc: `node scripts/run_architecture_check.mjs`.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-26 08:52
**Phase in progress:** completed
**Status:** Hoàn tất 100% tính năng đồ thị uốn lượn động dính chặt theo điểm cực trị.

### Decisions made this session
- Cung cấp dynamic getter cho curve evaluation trong JSXGraph.
- Kết nối `handleExtremumDrag` với `board.update()`: Khi kéo chuột, đường cong biến dạng liên tục và đỉnh parabol luôn dính chặt vào chấm tròn cực trị.
- Nhãn điểm và huy hiệu công thức góc trái tự động cập nhật số liệu theo thời gian thực.

### Next immediate action
Báo cáo kết quả và hướng dẫn trải nghiệm cho người dùng.
