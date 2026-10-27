# Specification: Math Studio Full Architectural & CAS Refactor

**Status:** Approved  
**Date:** 2026-10-26  
**Module:** `plugins/math_studio`  
**Tracking Issue/Phase:** Architecture Invariants & Professional Math CAS Engine  

---

## 1. Objective & Scope

### 1.1 Objective
Tái cấu trúc toàn diện plugin `math_studio` từ gốc rễ:
1. **Triệt tiêu toàn bộ hardcode:** Thay thế các bộ giải mẫu cứng bằng **Động cơ Toán học Ký hiệu CAS chuyên nghiệp (`Nerdamer` ~200KB thuần JS offline)**, giải tích và đạo hàm chính xác cho **MỌI** hàm số thực $\mathbb{R}$ (đa thức mọi bậc, hữu tỉ, lượng giác, siêu việt, căn thức).
2. **Hiển thị đạo hàm ký hiệu $y'$:** Hiển thị trực quan công thức đạo hàm $y' = f'(x)$ tự động tính toán dưới ô nhập hàm số và tại hàng đầu của Bảng biến thiên.
3. **Triệt tiêu God Object `app.js` (979 dòng):** Xây dựng kiến trúc **State-Driven Store (Single Source of Truth)**. Phân rã logic thành các controller độc lập $\le 300$ dòng mỗi file, xóa bỏ 15 biến toàn cục và mớ event listeners chằng chịt.
4. **Loại bỏ code thừa & dual render pipeline:** Xóa bỏ hoàn toàn hàm sinh SVG bằng tay cũ `generateGraphSvg` trong `graph_plotter.js` và `fraction.js`, thống nhất 100% việc hiển thị đồ thị và xuất bảng Chalkboard qua **JSXGraph DOM Vector Serializer (`board_exporter.js`)**.
5. **Hình học không gian chuẩn JSXGraph View3D (Hướng A):** Tận dụng module `View3D` có sẵn trong JSXGraph để hiển thị các mô hình không gian SGK với khả năng xoay chuột 3D trực quan, mượt mà, loại bỏ engine 3D tự chế chắp vá.

### 1.2 In-Scope vs. Out-of-Scope
- **In-Scope:**
  - Nhúng gói thư viện `nerdamer.core.js` + `nerdamer.calculus.js` vào `plugins/math_studio/ui/vendor/nerdamer/` (offline hoàn toàn).
  - Tích hợp module `core/math_cas.js` kết nối Nerdamer: tính đạo hàm ký hiệu $y'$, tìm nghiệm $f'(x) = 0$, tìm tiệm cận, tính tích phân Adaptive Simpson.
  - Xây dựng `core/store.js` quản lý state tập trung cho toàn plugin.
  - Phân tách giao diện: Tab Đồ thị, Tab Bảng biến thiên, Tab Tích phân, Tab Hình 3D (sử dụng JSXGraph View3D).
  - Kiểm thử tự động Node.js và CI Invariants đạt 100%.
- **Out-of-Scope:**
  - Nhập phương trình mặt phẳng không gian $Ax + By + Cz + D = 0$ tự do (dành cho Phase sau).
  - Không thay đổi các Invariant của Teacher Station trong `AGENTS.md`.

---

## 2. Architecture & Design Decisions

### 2.1 Architectural Pillars
1. **Universal Symbolic Math CAS:**
   - Dùng `nerdamer.diff(formula, 'x')` để sinh công thức đạo hàm ký hiệu $y'$ hiển thị cho giáo viên.
   - Dùng `nerdamer.solve(derFormula, 'x')` kết hợp với thuật toán số học lai Bisection + Newton-Raphson để tìm chính xác tọa độ các điểm cực trị (CĐ, CT), điểm uốn, và giao điểm với Ox/Oy.
   - Không còn bất kỳ mẫu hàm số hardcode nào trong codebase.
2. **State-Driven Store (`Store` Pattern):**
   ```
   [User Input / Drag Event]
              │
              ▼
   Store.dispatch({ type: 'SET_FORMULA', formula: '...' })
              │
              ▼
   Store cập nhật State & Thông báo Subscribers:
       ├── GraphBoard: Vẽ lại đường cong, cực trị, tiệm cận (JSXGraph)
       ├── BbtBoard: Cập nhật bảng biến thiên SGK (SVG)
       ├── IntegralPanel: Cập nhật công thức & diện tích tích phân
       └── FormulaDisplay: Hiển thị y' = f'(x)
   ```
3. **Single Render Pipeline (100% WYSIWYG):**
   - Chỉ có 1 board JSXGraph duy nhất chạy trên `#graphContainer`.
   - Bấm **`[📌 Ghim vào bảng]`** sẽ dùng `board_exporter.js` serialize trực tiếp node `<svg>` từ DOM JSXGraph dán lên bảng Chalkboard.
4. **File Ownership & Line Limit Invariant ($\le 350$ lines/file):**
   - `core/store.js` (~120 lines): State management tập trung.
   - `core/math_cas.js` (~250 lines): Cầu nối Nerdamer CAS + Numerical fallback.
   - `board/graph_board.js` (~300 lines): JSXGraph 2D lifecycle.
   - `board/view_3d_board.js` (~220 lines): JSXGraph View3D models.
   - `export/board_exporter.js` (~150 lines): Live DOM SVG serializer.
   - `app.js` (~200 lines): Main entrypoint & UI controller wiring.

---

## 3. Data Flow / System Flow

1. **Khởi tạo:**
   - `app.js` nạp Nerdamer và JSXGraph.
   - `Store` khởi tạo trạng thái mặc định (hàm số ban đầu $y = x^3 - 3x$).
   - `math_cas.js` phân tích hàm số: sinh ra $y'$, danh sách cực trị, tiệm cận, khoảng biến thiên.
   - Các view đăng ký lắng nghe `Store.subscribe()` và render đồng bộ.
2. **Người dùng nhập hàm số mới hoặc đổi tham số:**
   - `Store.dispatch('SET_FORMULA', newExpr)`.
   - `math_cas.js` tính toán lại toàn bộ dữ liệu giải tích.
   - Đồ thị JSXGraph vẽ lại mượt mà, dòng $y'$ cập nhật công thức ký hiệu tức thì.
3. **Người dùng kéo thả cực trị hoặc mút tích phân trên đồ thị:**
   - JSXGraph glider/point phát sự kiện drag $\to$ `Store.dispatch('UPDATE_DRAG_POINT', ...)`.
   - Hàm số và các bảng tự động điều chỉnh theo tọa độ mới mà không bị xung đột sự kiện.
4. **Ghim lên bảng Chalkboard:**
   - Giáo viên nhấn **`[📌 Ghim vào bảng]`** (hoặc `Ctrl + Enter`).
   - `board_exporter.js` clone SVG từ DOM JSXGraph, áp dụng chalkboard theme, đóng gói và gửi qua Host Bridge `insertToBoard`.

---

## 4. Acceptance Criteria

- [ ] **AC 1 (CAS Tổng Quát):** Nhập bất kỳ hàm số nào ($x^5 - 5x$, $\sin(x)^2 + 1$, $\frac{x^2-x+1}{x-1}$, $\sqrt{x^2+4}$, $e^{-x^2}$) hệ thống đều tính toán đúng $100\%$ cực trị, tiệm cận, không bị treo hay báo lỗi định dạng.
- [ ] **AC 2 (Đạo hàm $y'$ Ký hiệu):** Dòng công thức $y' = \dots$ hiển thị chính xác biểu thức ký hiệu dạng toán học dưới ô nhập hàm số và trên Bảng biến thiên.
- [ ] **AC 3 (Kiến trúc Store & File Size):** File `app.js` được rút gọn dưới 300 dòng; không có file nào trong `plugins/math_studio/` vượt quá 400 dòng; 15 biến toàn cục bị xóa sổ hoàn toàn.
- [ ] **AC 4 (Dọn dẹp code thừa):** Xóa bỏ hoàn toàn code sinh SVG thủ công nối chuỗi cũ (`generateGraphSvg`) và `fraction.js`; `board_exporter.js` là pipeline xuất SVG duy nhất.
- [ ] **AC 5 (Hình học 3D View3D):** Tab Hình 3D sử dụng JSXGraph View3D xoay chuột 3D trực quan, hỗ trợ đầy đủ các khối SGK cơ bản.
- [ ] **AC 6 (Verification Gate):** Toàn bộ bộ test `test_math_cas.mjs`, `test_math_studio.mjs`, `test_app_logic.mjs` và 12/12 Invariants trong `AGENTS.md` đạt $100\%$ PASS.

