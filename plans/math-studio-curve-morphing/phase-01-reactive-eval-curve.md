# Phase 1: Dynamic Reactive Function Graph (Đường cong uốn lượn 60 FPS)

## Goal
Làm cho đường cong đồ thị màu đỏ uốn lượn và thay đổi liên tục theo con trỏ chuột khi kéo cực đại/cực tiểu, giữ đỉnh đường cong luôn dính chặt vào điểm cực trị.

## Requirements
1. Trong `graph_plotter.js`:
   - Hàm `functiongraph` nhận hàm getter:
     ```javascript
     const getFn = (x) => {
       if (typeof options.getEval === 'function') {
         const fn = options.getEval();
         if (fn) return fn(x);
       }
       return analysis.eval(x);
     };
     ```
   - Điểm cực trị `extPt` khi kéo (`drag`):
     - Gọi `options.onExtremumDrag(ext, idx, extPt.X(), extPt.Y(), board)`
2. Trong `app.js`:
   - Cung cấp `getEval: () => (currentAnalysis ? currentAnalysis.eval : null)`.
   - Trong `handleExtremumDrag(ext, idx, newX, newY, board)`:
     - Tính `newFormula = computeFormulaFromDrag(currentAnalysis, { type: 'extremum', idx }, newX, newY)`.
     - Cập nhật `mathInput.value = newFormula`.
     - Phân tích cú pháp `currentAnalysis = parseAndAnalyze(newFormula)`.
     - Gọi `board.update()` để đường cong vẽ lại ngay lập tức tại vị trí mới.

## Success Criteria
- Khi kéo điểm cực trị, đường cong uốn lượn liên tục 60 FPS theo chuột.
- Đỉnh của đường cong không bị rời khỏi chấm tròn màu xanh.

