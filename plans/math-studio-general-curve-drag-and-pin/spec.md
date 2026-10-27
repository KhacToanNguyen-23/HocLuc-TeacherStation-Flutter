# Spec: Kéo Thả Cực Trị Mọi Hàm Số & Xuất Ghim Lên Bảng Phấn

**Date:** 2026-10-26  
**Status:** Ready  

---

## Problem Statement
Khi giáo viên nhập các hàm số phức tạp (lượng giác $y = \sin(x)^2 + 1$, đa thức bậc cao $x^5$, hàm siêu việt), hệ thống xếp vào dạng `'general'` khiến các điểm cực đại/cực tiểu bị khóa cứng không di chuyển được. Đồng thời, giao diện thiếu nút mang tên "Ghim vào bảng" và hàm sinh SVG chứa lỗi thẻ `<tspan>` chưa đóng thẻ XML dẫn đến việc không xuất đồ thị ra bảng phấn được.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a teacher, I want to drag local extrema (CĐ, CT) on any mathematical function (including trigonometric, exponential, high-degree polynomials) so that the curve and formula dynamically adapt in real-time.  
  Accepted when: Dragging an extremum on $y = \sin(x)^2 + 1$ or $y = x^5 - 5x$ updates the formula with valid mathematical translation ($f(x - \Delta x) + \Delta y$ / $+ C$) and immediately re-plots the curve without freezing.

- **[P1]** As a teacher, I want a prominent "📌 Ghim vào bảng" button so that I can easily recognize and click to export the graph to the chalkboard.  
  Accepted when: The dialog footer displays an explicit `[📌 Ghim vào bảng]` button that dispatches `board:insert_annotation` and places the sticker onto the board.

- **[P1]** As a developer, I want all exported SVG code to be 100% compliant with standard XML so that `flutter_svg` renders stickers with formulas containing exponents (e.g. `^2`) without XML parsing exceptions.  
  Accepted when: Generated SVG for formulas like $y = \sin(x)^2 + 1$ has balanced `<tspan>` tags (`opens === closes`) and renders cleanly inside `SvgPicture.string`.

- **[P2]** As a teacher, I want pressing `Ctrl + Enter` inside Math Studio to instantly pin the active graph/table to the board.  
  Accepted when: Pressing `Ctrl + Enter` in the formula input triggers the pin action.

---

## Functional Requirements

1. **FR-01 (General Curve Extremum Manipulation):**
   - Trong `curve_manipulator.js`, bổ sung nhánh xử lý cho `analysis.type === 'general'`.
   - Tính toán vector dịch chuyển $(\Delta x, \Delta y) = (newX - ext.x, newY - ext.y)$ với magnetic snapping.
   - Khi dịch chuyển theo phương đứng: Tự động điều chỉnh hoặc cộng dồn hằng số tự do vào đuôi công thức (ví dụ: $y = \sin(x)^2 + 1 \to y = \sin(x)^2 + 2$).
   - Khi dịch chuyển theo phương ngang: Tự động dịch pha $x \to (x - \Delta x)$ nếu người dùng kéo chủ động sang hai bên.
   - Tối ưu hóa chuỗi công thức sinh ra, tránh các mẫu `+ -` hoặc `+ 0`.

2. **FR-02 (UI Pin Action Renaming & UX Enhancement):**
   - Đổi ID/nhãn nút chính từ `Xong` thành `📌 Ghim vào bảng` trong `index.html` và `app.js`.
   - Áp dụng styling button nổi bật chuẩn Fluent / NoteRenderer.
   - Thêm hotkey listener `Ctrl + Enter` trên toàn bộ modal để ghim nhanh.

3. **FR-03 (Strict XML Vector SVG Generation):**
   - Trong `graph_plotter.js` (hàm `generateGraphSvg`), sửa đoạn format số mũ `^`:
     Thay thế `<tspan dy="-4.5" font-size="9.5">$1</tspan><tspan dy="4.5">` bằng cú pháp thẻ đóng hợp lệ hoặc `baseline-shift="super"` / `<tspan font-size="75%" dy="-4.5">$1</tspan><tspan dy="4.5"/>`.
   - Đảm bảo tổng số thẻ `<tspan>` mở bằng chính xác tổng số thẻ `</tspan>` đóng.

4. **FR-04 (Plugin Repackaging & Architecture Gate):**
   - Đồng bộ `plugins/math_studio.hlep` qua `node scripts/validate_plugins.mjs --fix`.
   - Vượt qua 12/12 Invariants kiến trúc và test suite tự động.

---

## Non-Functional Requirements

- **Performance:** Thao tác kéo thả cực trị cập nhật biểu thức và vẽ lại đồ thị trong thời gian $\le 16ms$ (60 FPS mượt mà).
- **Correctness:** 100% tài liệu SVG xuất ra hợp lệ chuẩn XML theo parser của gói `xml 7.0.1` của Flutter.
- **Maintainability:** Giữ nguyên 5 bộ giải giải tích SGK cho 5 hàm chuẩn, module hóa phần biến đổi tổng quát cho hàm `'general'`.

---

## Success Criteria

- [ ] Kéo thả cực đại/cực tiểu trên $y = \sin(x)^2 + 1$ di chuyển trơn tru và cập nhật công thức tương ứng.
- [ ] Nút `[📌 Ghim vào bảng]` hiển thị rõ ràng, bấm vào là đồ thị xuất hiện ngay trên bảng chalkboard.
- [ ] Bộ kiểm thử `node scripts/test_math_studio.mjs` và `node scripts/test_app_logic.mjs` đạt 100% PASS.
- [ ] `node scripts/validate_plugins.mjs` đạt 100% PASS với 0 lỗi.
- [ ] `flutter analyze --no-fatal-infos` đạt 0 lỗi, 0 cảnh báo.

---

## Out of Scope

- Không can thiệp vào các plugin khác như `casio_calculator` hay `english_assistant`.
- Không thay đổi thuật toán giải tích cho 5 hàm SGK cơ bản (giữ nguyên độ chính xác giải tích).

---

## Assumptions

- Giáo viên mong muốn khi kéo cực trị của hàm lượng giác/bậc cao thì đồ thị co giãn/tịnh tiến tương ứng với vị trí tay kéo.

