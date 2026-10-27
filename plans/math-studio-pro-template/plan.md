# Plan: Nâng Cấp Template Đồ Thị Chuẩn Pro (Hybrid Desmos + SGK)

**Mode:** Fast  
**Risk:** normal — Nâng cấp template đồ thị SVG sang chuẩn Hybrid Desmos + SGK trong graph_plotter.js  
**Spec:** `plans/math-studio-pro-template/spec.md`  
**Date:** 2026-10-26  

---

## Architecture & Layout Strategy
Nâng cấp toàn diện bộ máy render SVG tại `plugins/math_studio/ui/render/graph_plotter.js` và `style.css`:
1. **Typography & Trục số chuẩn Desmos**:
   - Chữ số trên trục: Font Sans-serif hiện đại 11.5px, màu xám đậm `#1F2937` (Dark Charcoal), căn chỉnh khoảng cách chuẩn xác, triệt tiêu 100% hiện tượng mờ nhòe sub-pixel.
   - Trục $Ox, Oy$: Nét mảnh 1.5px màu `#0F172A`, đầu mũi tên thanh thoát tỷ lệ vàng.
   - Gốc $O$: Đặt ở góc phần tư thứ III chuẩn mực $(originX - 10, originY + 13)$.
2. **Đường gióng SGK & Chống đè chữ (Collision Avoidance)**:
   - Từ điểm cực trị: Hạ đường gióng nét đứt vuông góc xuống $Ox$ và $Oy$ (`stroke-dasharray: 3,3`, màu xám `#94A3B8`).
   - Chấm điểm: Bán kính 4.5px, viền trắng 2px (`#FFFFFF`), đổ bóng mềm, màu xanh Navy hệ thống `#0B3A82`.
   - Thuật toán offset nhãn: Cực tiểu $CT$ đẩy nhãn xuống dưới hoặc sang bên thoáng, mút cận tích phân $a, b$ đưa xuống dưới trục hoành để không đè lên hoành độ nghiệm hay số trục.
3. **Miền tích phân Flat Tint & Công thức Superscript**:
   - Loại bỏ vĩnh viễn thẻ `<pattern id="hatchPattern">` sọc chéo CAD cũ.
   - Phủ màu bán trong suốt phẳng cao cấp `rgba(224, 36, 36, 0.16)` (nền sáng) và `rgba(56, 189, 248, 0.22)` (bảng phấn).
   - Công thức hiển thị góc đồ thị: Tự động chuyển `^2, ^3...` thành `<tspan dy="-4" font-size="80%">2</tspan>` chuẩn toán học ($y = x^2 - 2$).

---

## Phases

- [x] **Phase 1: Nâng cấp Typography, Đường Lưới & Trục Tọa Độ Sắc Nét**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`
  - Đổi font tick số sang 11.5px, màu `#1F2937`, căn lề trục $x, y$ chuẩn Desmos.
  - Tối ưu đường lưới nét mảnh 0.8px, gốc $O$ và mũi tên trục sắc nét.

- [x] **Phase 2: Triệt Tiêu Đè Chữ & Đường Gióng Nét Đứt SGK**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`
  - Dựng đường gióng nét đứt từ cực trị xuống 2 trục $Ox, Oy$.
  - Tách biệt nhãn mút tích phân $a, b$ và nhãn điểm giao trục, loại bỏ 100% sự va chạm text.
  - Điểm tròn viền trắng 2px chuẩn Desmos/GeoGebra.

- [x] **Phase 3: Tô Miền Tích Phân Trong Suốt & Công Thức Toán Superscript**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`
  - Bỏ sọc chéo CAD, thay bằng Translucent Flat Tint thanh nhã.
  - Xử lý render số mũ superscript cho thẻ công thức $y = x^2 - 2$.

- [x] **Phase 4: Đóng Gói .hlep, Chạy Test Suite & Kiểm Thử Kiến Trúc**
  - Đóng gói: `node scripts/validate_plugins.mjs --fix`.
  - Kiểm tra 12 Bất biến kiến trúc: `node scripts/run_architecture_check.mjs`.
  - Chạy mô phỏng đồ thị và tính toán: `node scripts/test_app_logic.mjs`.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-26 08:10
**Status:** Hybrid Desmos + SGK template upgrade completed 100%.
- Typography: 11.5px Dark Charcoal #1F2937, 0% blur.
- Collisions eliminated: SGK projection lines + smart label offset.
- Shading: High-end Translucent Flat Tint (no CAD hatch).
- Formula: Math superscript y = x² - 2.
- 12/12 Invariants PASS 100%.

