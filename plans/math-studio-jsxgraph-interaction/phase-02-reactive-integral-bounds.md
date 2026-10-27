# Phase 2: Tương Tác Mút Cận Tích Phân Reactive & Tính Diện Tích Tuyệt Đối

## Goal
Xây dựng cơ chế kéo thả mút tích phân $a, b$ mượt mà 60 FPS, không làm đứt kết nối pointer capture và đồng bộ 2 chiều với ô input và diện tích $S$.

## Requirements
1. Trong `graph_plotter.js`:
   - Gắn sự kiện `drag` trên glider $a$ và glider $b$:
     - Hít nam châm (magnetic snap) vào bước 0.5 khi kéo gần điểm chia.
     - Gọi callback `onBoundChange(bound, value, isDragging)` truyền giá trị tọa độ mới.
     - Cập nhật vị trí đường gióng thẳng đứng và miền tô màu theo thời gian thực mà không gọi `freeBoard`.
2. Trong `app.js`:
   - Trong lúc kéo (`isDragging = true`):
     - Chỉ cập nhật hiển thị số trong ô `boundAInput`, `boundBInput` và tính lại diện tích $S = \int_a^b |f(x)|dx$.
     - Cập nhật các badge `intFormulaDisplay` và `intAreaResult`.
     - Tuyệt đối không gọi `renderJSXGraphBoard` hay `freeBoard` làm hủy bảng vẽ.
   - Khi nhả chuột (`dragend` / `isDragging = false`):
     - Chốt giá trị cuối cùng và lưu vào state.

## Success Criteria
- Kéo mút $a, b$ mượt mà, không bị giật hay đứng hình.
- Giá trị tọa độ trên trục hoành khớp chính xác 100% với ô `Cận a` và `b` phía trên.
- Số diện tích $S$ cập nhật liên tục và luôn mang giá trị dương chuẩn SGK.

