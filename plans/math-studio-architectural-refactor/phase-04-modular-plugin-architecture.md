# Phase 04: Modular Plugin Architecture Refactor

**Status:** Not Started  
**Target Files:**
- `plugins/math_studio/ui/board/graph_board.js`
- `plugins/math_studio/ui/board/bbt_board.js`
- `plugins/math_studio/ui/ui/dialog_controller.js`
- `plugins/math_studio/ui/app.js`
- `plugins/math_studio/ui/render/graph_plotter.js`

---

## Technical Details

1. **Decompose `app.js` (~1.000 lines) and `graph_plotter.js` (~860 lines):**
   - **`board/graph_board.js`:** Quản lý vòng đời JSXGraph board, khởi tạo trục toạ độ, layer đường cong hàm số, layer cực trị, layer tiệm cận, layer tích phân. Không chứa code DOM dialog hay chuỗi SVG string.
   - **`board/bbt_board.js`:** Chuyên trách vẽ Bảng biến thiên (BBT) vector chuẩn SGK từ dữ liệu khảo sát của CAS.
   - **`ui/dialog_controller.js`:** Quản lý chuyển tab (Đồ thị / Bảng biến thiên / Tích phân / 3D), các input nhập cận $a, b$, bàn phím toán học và phím tắt `Ctrl + Enter`.
   - **`app.js`:** Trở thành file entry point tinh gọn ($\le 150$ dòng), chỉ làm nhiệm vụ kết nối và điều phối các module.

2. **Refactor Invariant Enforced:**
   - Mỗi file sau khi chia tách phải $\le 450$ dòng, tách biệt hoàn toàn giữa tính toán toán học (Math CAS), hiển thị đồ hoạ (JSXGraph), và xuất file (Board Exporter).

---

## Verification
- Kiểm tra toàn bộ luồng giao diện hoạt động bình thường, không có lỗi console hay import gãy vỡ.
- Đạt 100% các bài test unit trong `scripts/test_app_logic.mjs`.

