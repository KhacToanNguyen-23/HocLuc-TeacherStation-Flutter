# Spec: Tái Cấu Trúc Toàn Diện Math Studio (CAS Engine, WYSIWYG DOM Export & Canva Chalkboard)

**Date:** 2026-10-26  
**Status:** Ready  

---

## Problem Statement
Math Studio hiện tại đang gặp 3 vấn đề kiến trúc nghiêm trọng:
1. **Dual-Pipeline (Vẽ hai lần):** Modal dùng JSXGraph DOM nhưng khi ghim ra bảng lại dùng bộ sinh SVG thủ công nối chuỗi string (`generateGraphSvg`), khiến đồ thị trên bảng phấn không phải là chính nó (WYSIWYG thất bại, lệch vạch số, đứt đường cong).
2. **Hardcode công thức thủ công:** Chỉ giải phương trình cho 5 mẫu hàm SGK cơ bản. Khi gặp hàm lượng giác, đa thức bậc cao ($x^5$) hoặc hàm siêu việt thì cực trị bị khóa cứng, không có Symbolic Math Engine (CAS) thực thụ để tính đạo hàm $f'(x)$, cực trị $f'(x) = 0$ và tích phân chính xác.
3. **Cấu trúc phình to & Thiếu chuẩn Canva:** File `app.js` và `graph_plotter.js` phình to gần 1.000 dòng, cơ chế tương tác sticker trên bảng phấn chưa đạt độ mượt mà chuẩn Canva (8 handles, xoay snap góc, double-click sửa 2 chiều).

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a math teacher, I want to input ANY mathematical function (polynomials of any degree, rational, trigonometric, exponential, logarithmic) and have the system compute exact analytical derivatives $f'(x)$, roots, extrema, intercepts, and variation intervals without hardcoded formula templates.  
  Accepted when: Functions like $y = \sin(x)^2 + 1$, $y = x^5 - 5x$, $y = \frac{x^2 - x + 1}{x - 1}$, $y = x \cdot e^{-x}$ have their extrema, asymptotes, and variation tables computed accurately via a Symbolic/CAS engine.

- **[P1]** As a teacher, I want the exact graph I see in the Math Studio dialog to be exported to the teaching chalkboard (WYSIWYG 100%), not a separately hand-drawn string-concatenated replica.  
  Accepted when: Pinned chalkboard sticker SVGs are serialized directly from the live JSXGraph DOM board with crisp vector paths, tick labels, extrema dots, and integral shading matching 100% pixel-for-pixel.

- **[P1]** As a teacher, I want dragging any extremum or handle on the graph to manipulate the function with mathematical rigor, updating the formula and curve reactively at 60 FPS.  
  Accepted when: Dragging an extremum on any function updates the function parameters/translation mathematically and re-evaluates the curve without freezing or invalid math strings.

- **[P1]** As a teacher, I want the pinned chalkboard sticker to behave like a true Canva object with 8 handles (corner scale, edge resize), a rotation handle with magnetic snap ($0^\circ, 45^\circ, 90^\circ, 180^\circ$), and a floating action bar.  
  Accepted when: The sticker card has responsive 8-point handles, a smooth rotation handle, and clicking "Sửa" re-opens Math Studio preserving the exact state.

- **[P2]** As a developer, I want the Math Studio codebase to be decoupled into clean, modular, single-responsibility files ($\le 400$ lines each).  
  Accepted when: `app.js` and `graph_plotter.js` are decomposed into `math_cas.js`, `graph_board.js`, `bbt_board.js`, `board_exporter.js`, and `dialog_controller.js`.

---

## Functional Requirements

1. **FR-01 (Symbolic Math Engine & Solver):**
   - Tích hợp Symbolic Math CAS gọn nhẹ (`mathjs` / `nerdamer` hoặc module CAS toán học độc lập offline) vào `plugins/math_studio/ui/core/math_cas.js`.
   - Tính đạo hàm hình thức $f'(x)$, giải nghiệm thực $f'(x) = 0$ để tìm cực đại, cực tiểu, điểm uốn.
   - Tìm giao điểm với các trục tọa độ $Ox, Oy$.
   - Tính tích phân xác định $\int_a^b f(x)dx$ và diện tích hình phẳng $S = \int_a^b |f(x)|dx$.

2. **FR-02 (Live DOM Vector SVG Serializer - WYSIWYG 100%):**
   - Xóa bỏ logic ghép chuỗi string thủ công trong `generateGraphSvg`.
   - Viết module `export/board_exporter.js`: Clone trực tiếp phần tử `<svg>` từ DOM của container JSXGraph (`#graphContainer svg`).
   - Bổ sung style vector độ tương phản phấn trắng (Chalkboard theme) trực tiếp vào các phần tử cloned: trục toạ độ trắng $1.5px$, vạch số đậm, đường cong sắc nét, miền tô tích phân bán trong suốt.
   - Đảm bảo XML chuẩn 100%, không sinh lỗi parse `flutter_svg`.

3. **FR-03 (Exact Inverse Mathematical Manipulation):**
   - Trong `core/curve_manipulator.js`, thay thế toàn bộ các nhánh nối chuỗi thô bằng giải tích ngược:
     - Với hàm đa thức / hữu tỉ: Giải hệ phương trình điều kiện biên để tìm bộ hệ số mới.
     - Với hàm lượng giác / siêu việt: Tịnh tiến giải tích hoặc biến đổi tham số biên độ/pha theo đúng định luật hàm số.

4. **FR-04 (Canva Object Interaction on Chalkboard):**
   - Hoàn thiện 8 handle điều khiển: 4 góc kéo tỉ lệ đồng dạng, 4 cạnh kéo dãn 1 chiều.
   - Nút xoay với cơ chế nam châm hút góc (snap to $0^\circ, 45^\circ, 90^\circ, 180^\circ$).
   - Thanh công cụ nổi (Pill Bar) canvas overlay: Ghim, Đổi màu nét phấn, Sửa (2-way sync), Nhân bản, Xóa.

5. **FR-05 (Modular Clean Architecture):**
   - Tách cấu trúc `plugins/math_studio/ui/`:
     - `core/math_cas.js`
     - `core/curve_manipulator.js`
     - `board/graph_board.js`
     - `board/bbt_board.js`
     - `export/board_exporter.js`
     - `ui/dialog_controller.js`
   - Đảm bảo không file nào vượt quá 450 dòng.

---

## Non-Functional Requirements

- **Accuracy:** Kết quả cực trị, giao điểm và tích phân sai số $\le 10^{-6}$.
- **Performance:** Thao tác kéo thả và render lại board đạt 60 FPS ($\le 16ms$ per frame).
- **Bundle Size:** Không làm tăng kích thước plugin quá 1.5MB; hoạt động hoàn toàn offline không cần internet.
- **Invariants Gate:** Tuân thủ tuyệt đối 12/12 Bất biến kiến trúc trong `AGENTS.md`.

---

## Success Criteria

- [ ] 100% hàm số (kể cả lượng giác $y = \sin(x)^2 + 1$, bậc cao $x^5$) đều tìm được cực trị và kéo thả mượt mà.
- [ ] SVG ghim lên bảng chalkboard lấy trực tiếp từ live DOM, giống 100% so với những gì giáo viên thấy trong modal.
- [ ] Sticker trên bảng phấn hỗ trợ trọn vẹn 8 handles, xoay góc snap, và thanh công cụ nổi.
- [ ] `node scripts/validate_plugins.mjs` đạt PASS 100% với 0 lỗi.
- [ ] `flutter test test/architecture_test.dart` đạt 12/12 Invariants PASS.
- [ ] `flutter analyze --no-fatal-infos` đạt 0 errors, 0 warnings.
