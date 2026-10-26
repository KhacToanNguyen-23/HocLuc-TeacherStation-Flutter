# Phase 2: Phục Hồi & Tích Hợp Kéo Nắn Điểm Cực Trị 2 Chiều

## Goal
Khôi phục và tích hợp hoàn chỉnh tính năng kéo nắn trực tiếp các điểm cực trị (CĐ, CT) trên đồ thị: Khi giáo viên kéo điểm uốn/cực trị, đường cong uốn lượn tại 60 FPS và công thức hàm số tự động tính toán cập nhật ngược lại vào ô input.

## Target Files
- `plugins/math_studio/ui/app.js`
- `plugins/math_studio/ui/core/curve_manipulator.js`
- `plugins/math_studio/ui/render/graph_plotter.js`
- `scripts/test_curve_manipulator.mjs`

## Detailed Implementation Steps
1. **Kiểm tra và chuẩn hóa cấu trúc handle trên SVG trong graph_plotter.js:**
   - Đảm bảo mỗi điểm cực trị sinh thẻ `<g class="drag-handle extremum-handle" data-idx="..." data-math-x="..." data-math-y="...">` với vùng chạm trong suốt `r=14` để ngón tay chạm dễ dàng.
2. **Gắn sự kiện Pointer Events trong app.js:**
   - Bắt sự kiện `pointerdown` trên `.drag-handle`.
   - `pointermove`: Chuyển đổi tọa độ pixel màn hình sang tọa độ toán học $(x_{\text{math}}, y_{\text{math}})$.
   - Gọi `computeFormulaFromDrag(currentAnalysis, handle, newMathX, newMathY)` để tính toán đa thức mới.
   - Cập nhật ô input `mathInput.value = newFormula` và vẽ lại đồ thị tức thời ở 60 FPS.
   - `pointerup / pointercancel`: Kết thúc kéo, lưu lại trạng thái phân tích mới.
3. **Kiểm thử hiệu năng:**
   - Đảm bảo mỗi lần kéo tính toán trong $< 2\text{ms}$, không gây tụt khung hình.

## Acceptance Criteria
- [ ] Kéo điểm cực đại/cực tiểu bằng chuột hoặc chạm làm đồ thị biến dạng uốn lượn mượt mà 60 FPS.
- [ ] Công thức hàm số trong ô input tự động nhảy số theo vị trí mới của điểm cực trị.
- [ ] Kiểm thử `scripts/test_curve_manipulator.mjs` đạt 100% PASS.

