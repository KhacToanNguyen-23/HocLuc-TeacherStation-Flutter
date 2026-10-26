# Phase 3: JSXGraph View3D Integration Cho Hình Học 3D (`view_3d_board.js`)

## Context & Objectives
Thay thế engine 3D tự chế chắp vá (`geometry_3d_engine.js`) bằng module `View3D` sẵn có trong thư viện `jsxgraphcore.js`. Cho phép giáo viên tương tác xoay 3 chiều bằng chuột trực quan, mượt mà và tận dụng engine toán học chuẩn sư phạm.

## Scope of Work
1. Tạo module `plugins/math_studio/ui/board/view_3d_board.js`:
   - Khởi tạo JSXGraph 3D View: `board.create('view3d', [[-3, -3], [6, 6], [[-2, 2], [-2, 2], [-2, 2]]], { ... })`.
   - Cung cấp các mô hình hình học SGK chuẩn:
     - Hình chóp tam giác đều $S.ABC$.
     - Hình chóp tứ giác đều $S.ABCD$.
     - Hình lăng trụ tam giác $ABC.A'B'C'$.
     - Hình nón, hình trụ, hình cầu.
   - Hỗ trợ chuột xoay 3D (trackball rotation) theo cử chỉ kéo thả của giáo viên.
2. Xóa bỏ hoàn toàn file `geometry_3d_engine.js` (470 dòng thừa).
3. Đóng gói hàm xuất SVG cho hình 3D từ DOM JSXGraph.

## Verification Commands
- `node scripts/test_math_studio.mjs`
- Đảm bảo file `geometry_3d_engine.js` được dọn sạch hoàn toàn khỏi project.

