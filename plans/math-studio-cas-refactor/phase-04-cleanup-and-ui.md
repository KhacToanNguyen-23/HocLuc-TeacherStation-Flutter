# Phase 4: Dọn Dẹp Code Thừa, Hoàn Thiện UI & WYSIWYG Export

## Context & Objectives
Loại bỏ triệt để code trùng lặp và dead code trong các module, hoàn thiện giao diện người dùng hiển thị công thức đạo hàm $y'$, đồng bộ thanh công cụ và tinh chỉnh nút Ghim vào bảng Chalkboard.

## Scope of Work
1. Xóa các file code thừa & dead code:
   - `calculus_solver.js` (482 dòng - hardcoded templates cũ).
   - `fraction.js` (167 dòng - fraction arithmetic cũ).
   - Xóa `generateGraphSvg` khỏi `graph_plotter.js` (rút gọn hoặc gộp vào `graph_board.js`).
   - Xóa `revolution_solid_plotter.js` (131 dòng cũ).
2. Tinh chỉnh giao diện `index.html` và `style.css`:
   - Thêm dòng hiển thị đạo hàm $y' = \dots$ dạng MathJax/KaTeX (hoặc Unicode superscript rõ nét) dưới ô nhập hàm số.
   - Hiển thị công thức $y'$ ở hàng đầu tiên của Bảng biến thiên.
   - Thích ứng cột điều khiển bên trái: khi chuyển sang Tab 3D, tự động ẩn khối hàm số và hiện thanh công cụ 3D chuyên biệt.
3. Đồng bộ tương tác với Host Bridge:
   - Hoàn thiện nút **`[📌 Ghim vào bảng]`** với phím tắt `Ctrl + Enter`.
   - Kết nối 2-way re-edit khi double click vào sticker trên bảng Chalkboard.

## Verification Commands
- `node scripts/test_math_studio.mjs`
- `node scripts/test_app_logic.mjs`
- Đảm bảo toàn bộ các file trong `plugins/math_studio/ui/` đều $\le 350-400$ dòng.

