# Phase 3: Mở Khóa Kéo Cực Trị Nắn Hàm Số 2 Chiều

## Goal
Cho phép giáo viên kéo điểm cực đại, cực tiểu để nắn lại đồ thị hàm số theo thời gian thực.

## Requirements
1. Trong `graph_plotter.js`:
   - Điểm cực trị thiết lập `fixed: false` nếu `interactiveExtrema: true`.
   - Lắng nghe sự kiện `drag` trên điểm cực trị:
     - Gọi callback `onExtremumDrag(ext, newX, newY)`.
2. Trong `app.js`:
   - Kết nối `onExtremumDrag` với hàm `computeFormulaFromDrag(currentAnalysis, handle, newX, newY)` đã có sẵn trong `curve_manipulator.js`.
   - Cập nhật công thức mới vào ô `mathInput.value`.
   - Cập nhật đường cong hàm số mượt mà.

## Success Criteria
- Kéo điểm cực đại hoặc cực tiểu làm thay đổi bề lõm / tọa độ đỉnh của parabol hoặc hàm bậc 3.
- Ô nhập liệu hàm số tự động cập nhật công thức tương ứng.

