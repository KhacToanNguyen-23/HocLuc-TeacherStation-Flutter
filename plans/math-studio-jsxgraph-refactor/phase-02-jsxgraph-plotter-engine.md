# Phase 2: Xây Dựng Bộ Render JSXGraph Trong graph_plotter.js

## Goal
Xây dựng hàm `renderJSXGraphBoard` trong `graph_plotter.js` quản lý vòng đời JSXGraph Board và vẽ hàm số với trục tọa độ SGK.

## Requirements
1. Kiểm tra môi trường: nếu `window.JXG` tồn tại, khởi tạo hoặc làm mới board trên `#graphContainer`.
2. Thiết lập boundingbox tự thích ứng theo bounds: `[xMin, yMax, xMax, yMin]`.
3. Tùy biến trục $Ox, Oy$ và lưới tọa độ:
   - Trục nét đậm 1.5px, màu tối thanh lịch `#0F172A`.
   - Mũi tên trục thanh thoát.
   - Chữ số trên trục 11.5px chuẩn mực, không bao giờ nhòe.
   - Gốc tọa độ $O$ đặt ở góc III.
4. Vẽ hàm số bằng `board.create('functiongraph', [f, xMin, xMax])` với nét vẽ 2.2px sắc sảo.
5. Vẽ điểm cực trị và đường gióng nét đứt chuẩn SGK vuông góc với $Ox, Oy$.

## Success Criteria
- Board JSXGraph khởi tạo thành công khi mở plugin.
- Hàm bậc 2, bậc 3, bậc 4 và phân thức vẽ mượt mà.
- Điểm cực trị hiển thị chấm tròn viền trắng và có đường gióng nét đứt.

