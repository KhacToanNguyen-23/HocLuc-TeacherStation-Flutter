# Plan: Tái Cấu Trúc Toàn Diện Math Studio (CAS Engine, WYSIWYG DOM Export & Canva Chalkboard)

**Date:** 2026-10-26  
**Mode:** --hard  
Risk: normal — touches Math Studio core architecture, DOM export pipeline, and board Canva interactions.  
**Spec:** [`plans/math-studio-architectural-refactor/spec.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-architectural-refactor/spec.md)  

---

## Architecture & Boundary Invariants
1. **Zero Hardcoded Names:** Không hardcode plugin IDs hay tên riêng trong `frontend/lib/`.
2. **Clean Modular Structure:** Không file nào trong plugin vượt quá giới hạn dòng (mục tiêu $\le 450$ dòng/file).
3. **Single Source of Truth (WYSIWYG):** Chỉ có DUY NHẤT một pipeline render đồ thị: JSXGraph DOM là nơi hiển thị, và xuất SVG là việc serialize trực tiếp từ DOM của board đó.
4. **Schema v2.1 Compliance:** Giữ `manifest.json` chuẩn v2.1 và đóng gói `plugins/math_studio.hlep` đồng bộ sau mỗi phase.
5. **Architecture Defense Gate:** 12/12 Invariants kiến trúc luôn phải đạt 100% trong mọi commit.

---

## Phase Breakdown

- [x] **Phase 1: Symbolic Math CAS Engine (`math_cas.js`)**
  - Xây dựng module `plugins/math_studio/ui/core/math_cas.js`.
  - Tích hợp Symbolic Differentiation: Tự động tính biểu thức $f'(x)$ cho mọi hàm số (đa thức, hữu tỉ, lượng giác, siêu việt).
  - Tìm nghiệm chính xác của $f'(x) = 0$ và $f(x) = 0$ kết hợp giải tích và phương pháp Newton-Raphson độ chính xác cao.
  - Tính tích phân xác định và diện tích hình phẳng chính xác.
  - Viết bộ kiểm thử độc lập: `scripts/test_math_cas.mjs` (5/5 PASS).

- [x] **Phase 2: Single JSXGraph Board & WYSIWYG Live DOM SVG Serializer (`board_exporter.js`)**
  - Viết module `plugins/math_studio/ui/export/board_exporter.js`:
    - Clone trực tiếp node `<svg>` từ DOM JSXGraph container `#graphContainer`.
    - Tự động inject các style Chalkboard (nét trắng, nền trong suốt, vạch số đậm, miền tích phân trong suốt) vào bản clone.
    - Đảm bảo XML strictly compliant 100% cho `flutter_svg`.
  - Kiểm tra xuất đồ thị WYSIWYG: Bảng chi tiết có gì thì sticker trên bảng chalkboard có đúng 100% cái đó.
  - Đổi nút `#btnDoneDialog` thành `[📌 Ghim vào bảng]` và hỗ trợ hotkey `Ctrl + Enter`.

- [x] **Phase 3: Exact Inverse Mathematical Manipulation (`curve_manipulator.js`)**
  - Tái cấu trúc `core/curve_manipulator.js`:
  - Kéo cực đại / cực tiểu trên bất kỳ hàm số nào đều kích hoạt bộ giải CAS ngược, tìm lại bộ hệ số hoặc tham số dịch chuyển chính xác.
  - Hỗ trợ hàm lượng giác $\sin(x)^2 + 1$, đa thức bậc cao $x^5 - 5x$, phân thức, đa thức bậc 3/4.
  - Viết bộ kiểm thử độc lập: `scripts/test_curve_manipulator.mjs` (5/5 PASS).

- [x] **Phase 4: Modular Plugin Architecture Refactor**
  - Tách `app.js` và `graph_plotter.js` thành các module chuyên biệt:
    - `board/graph_board.js`: Vòng đời và quản lý layer đồ thị JSXGraph (430 dòng).
    - `export/board_exporter.js`: Serializer DOM SVG (160 dòng).
    - `render/graph_plotter.js`: Rút gọn từ 860 dòng xuống 369 dòng.
  - Đảm bảo các file mô-đun tuân thủ giới hạn $\le 450$ dòng.

- [x] **Phase 5: Canva Chalkboard Sticker Polish & Comprehensive Verification Gate**
  - Tinh chỉnh `BoardStickerCard` và `BoardStickerFloatingBar` trên Flutter Chalkboard:
    - 8 handles tương tác mượt mà (4 góc tỷ lệ, 4 cạnh 1 chiều).
    - Rotate handle với góc snap nam châm ($0^\circ, 45^\circ, 90^\circ, 180^\circ$).
    - 2-Way Edit: Double click hoặc bấm "Sửa" mở lại Math Studio với đúng trạng thái của sticker.
  - Re-package `.hlep` và kiểm thử CI toàn diện (12/12 Invariants PASS, plugins synchronized).

---

## File Ownership
- `plugins/math_studio/ui/core/math_cas.js`
- `plugins/math_studio/ui/core/curve_manipulator.js`
- `plugins/math_studio/ui/board/graph_board.js`
- `plugins/math_studio/ui/board/bbt_board.js`
- `plugins/math_studio/ui/export/board_exporter.js`
- `plugins/math_studio/ui/ui/dialog_controller.js`
- `plugins/math_studio/ui/app.js`
- `plugins/math_studio/ui/render/graph_plotter.js`
- `frontend/lib/features/studio_board/presentation/board_sticker_card.dart`
- `frontend/lib/features/studio_board/presentation/interactive_chalkboard.dart`
- `plugins/math_studio.hlep`
- `scripts/test_math_cas.mjs`
- `scripts/test_math_studio.mjs`
