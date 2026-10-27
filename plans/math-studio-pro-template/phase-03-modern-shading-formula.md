# Phase 3: Tô Miền Tích Phân Trong Suốt & Công Thức Toán Superscript

**File:** `plugins/math_studio/ui/render/graph_plotter.js`  
**Stories Covered:** P1 (Tô màu miền tích phân hiện đại), P2 (Công thức toán superscript)  

### Tasks:
1. Xóa bỏ hoàn toàn pattern sọc chéo CAD `<pattern id="hatchPattern">`.
2. Tô miền diện tích tích phân:
   - Dùng lớp phủ phẳng bán trong suốt `fill="rgba(224, 36, 36, 0.16)"` (nền sáng) và `rgba(56, 189, 248, 0.22)` (bảng phấn).
   - Hai vạch biên $x = a$ và $x = b$: nét đứt thanh mảnh $1.2px$, `stroke-dasharray="4,3"`.
3. Format công thức toán học góc đồ thị:
   - Thay thế `^2, ^3...` bằng thẻ SVG `<tspan dy="-3.5" font-size="80%">2</tspan><tspan dy="3.5">...</tspan>` chuẩn xác.
   - Thẻ hiển thị công thức với nền bo góc nhẹ, viền mảnh thanh lịch, màu đỏ đô hoặc đồng bộ màu swatch.

