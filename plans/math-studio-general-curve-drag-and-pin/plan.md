# Plan: Kéo Thả Cực Trị Mọi Hàm Số & Xuất Ghim Lên Bảng Phấn

**Date:** 2026-10-26  
**Mode:** --fast  
Risk: normal — touches Math Studio curve manipulator, graph plotter SVG generation, and dialog pin button.  
**Spec:** [`plans/math-studio-general-curve-drag-and-pin/spec.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-general-curve-drag-and-pin/spec.md)  

---

## Architecture & Boundary Invariants
1. **Zero Hardcoded Names:** Không hardcode plugin IDs hay tên riêng trong `frontend/lib/`.
2. **Schema v2.1 Compliance:** Giữ `plugins/math_studio/manifest.json` chuẩn v2.1, luôn đóng gói `plugins/math_studio.hlep` sau khi cập nhật mã nguồn plugin.
3. **Clean XML SVG:** Đảm bảo toàn bộ mã SVG sinh ra có các thẻ mở/đóng cân bằng 100% để `flutter_svg` render ổn định mà không ném parser exception.
4. **Architecture Gate:** Luôn đảm bảo 12/12 Invariants kiến trúc và `flutter analyze` đạt 0 lỗi, 0 cảnh báo.

---

## Phase Breakdown

- [x] **Phase 1: Dynamic Curve & Extremum Manipulation for General Functions**
  - File: `plugins/math_studio/ui/core/curve_manipulator.js` & `plugins/math_studio/ui/app.js`
  - Bổ sung nhánh xử lý cho `analysis.type === 'general'` trong hàm `computeFormulaFromDrag()`.
  - Hỗ trợ dịch chuyển cực trị theo phương dọc: Tự động tính $\Delta y$ với `magneticSnap`, điều chỉnh hằng số tự do $+ C$ ở đuôi công thức (ví dụ: $y = \sin(x)^2 + 1 \to y = \sin(x)^2 + 2$ khi kéo đỉnh từ $y=2$ lên $y=3$).
  - Hỗ trợ dịch chuyển ngang: Tự động tịnh tiến biến số $x \to (x - \Delta x)$.
  - Tinh chỉnh hàm `handleExtremumDrag` trong `app.js` để phản hồi tức thì và cập nhật đồ thị mượt mà.
  - Viết test case tự động kiểm chứng việc kéo thả hàm lượng giác và đa thức bậc cao (`test_curve_manipulator.mjs` PASS 100%).

- [x] **Phase 2: Strict XML SVG Generation & Prominent [📌 Ghim vào bảng] Action**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`, `plugins/math_studio/ui/index.html`, `plugins/math_studio/ui/app.js`
  - Trong `graph_plotter.js` (hàm `generateGraphSvg`), sửa lỗi thẻ `<tspan>` không đóng: thay thế bằng cặp thẻ hợp lệ `baseline-shift="super"` / XML balanced tag, đảm bảo thẻ mở bằng chính xác thẻ đóng 100%.
  - Trong `index.html`, cập nhật nút `#btnDoneDialog` thành `[📌 Ghim vào bảng]` với style nổi bật.
  - Trong `app.js`, bổ sung phím tắt `Ctrl + Enter` để ghim nhanh đồ thị lên bảng phấn.
  - Đóng gói lại plugin: `node scripts/validate_plugins.mjs --fix`.
  - Chạy toàn bộ test suites (`test_math_studio.mjs`, `test_app_logic.mjs`, `architecture_test.dart` PASS 100%).

## Session Notes
**Last active:** 2026-10-26 17:08  
**Phase in progress:** Completed  
**Status:** All 2 phases implemented, verified and passing 100%  

### Decisions made this session
- Dynamic Offset & Translation for general functions: Extrema of trig functions ($y = \sin(x)^2 + 1$) and high-degree polynomials ($x^5$) now adapt formulas dynamically on drag.
- Strict XML Vector SVG: Replaced unclosed `<tspan dy="4.5">` with XML-compliant `<tspan baseline-shift="super" font-size="70%">$1</tspan>`, fixing `flutter_svg` render rejections.
- Prominent Pin UI: Renamed `[Xong]` to `[📌 Ghim vào bảng]` with primary blue styling and added `Ctrl + Enter` hotkey.

---

## File Ownership
- `plugins/math_studio/ui/core/curve_manipulator.js`
- `plugins/math_studio/ui/render/graph_plotter.js`
- `plugins/math_studio/ui/index.html`
- `plugins/math_studio/ui/app.js`
- `plugins/math_studio.hlep`
- `scripts/test_math_studio.mjs`
- `scripts/test_app_logic.mjs`

