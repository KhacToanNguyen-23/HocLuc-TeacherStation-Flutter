# Plan: Tối Ưu Tương Tác Kéo Thả & Khử Mờ Trục Đồ Thị JSXGraph

Mode: Fast
Risk: normal — Tối ưu tương tác kéo thả và khử mờ trục số JSXGraph trong graph_plotter.js và app.js
Spec: `plans/math-studio-jsxgraph-interaction/spec.md`
Date: 2026-10-26

---

## Architecture & Interaction Strategy
1. **Khử mờ & Tinh chỉnh trục tọa độ SGK (`graph_plotter.js` & `style.css`)**:
   - Thiết lập `minorTicks: 0` và `insertTicks: false` trên cả hai trục $Ox, Oy$.
   - Major ticks cách nhau đúng khoảng cách chuẩn `sX, sY`, loại bỏ vạch xước li ti.
   - Nâng cấp cỡ chữ số trục lên 12px, font-weight 700, màu `#0F172A` (chế độ sáng) và `#FFFFFF` (chế độ bảng phấn).
   - Thêm CSS `text-rendering: optimizeLegibility; -webkit-font-smoothing: antialiased;` cho nhãn trục JSXGraph.
2. **Cơ chế Reactive cho Mút Tích Phân & Diện Tích SGK**:
   - Không hủy board (`freeBoard`) khi đang kéo chuột. Thay vào đó, dùng glider JSXGraph gắn trên trục hoành.
   - Lắng nghe sự kiện `drag` của glider $a, b$: cập nhật toạ độ tức thời vào ô input và tính toán lại diện tích hình phẳng tuyệt đối $S = \int_a^b |f(x)| dx$.
   - Ẩn vĩnh viễn nhãn $\int = \text{số}$ có dấu của JSXGraph (`withLabel: false`, `label: { visible: false }`).
   - Hỗ trợ hít nam châm (magnetic snap) vào bước 0.5.
3. **Mở khóa nắn điểm cực trị 2 chiều (Inverse Fitting)**:
   - Đặt `fixed: false` cho các điểm cực trị (CĐ, CT).
   - Khi kéo điểm cực trị, bắt sự kiện `drag` và gọi `computeFormulaFromDrag(currentAnalysis, handle, x, y)` để cập nhật công thức hàm số trên `mathInput` theo thời gian thực.
4. **Kiểm thử & Đóng gói**:
   - Chạy 5 test suites logic.
   - Đóng gói `.hlep` qua `validate_plugins.mjs`.
   - Đảm bảo 12 Bất biến kiến trúc đạt 100%.

---

## Phases

- [x] **Phase 1: Khử Mờ Trục Tọa Độ & Loại Bỏ Vạch Li Ti (Crisp SGK Axes)**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`, `style.css`
  - Đặt `minorTicks: 0`, `insertTicks: false` trên $Ox, Oy$.
  - Cập nhật font 12px, font-weight 700, màu `#0F172A`, bật CSS khử răng cưa.
  - Tắt nhãn $\int = ...$ có dấu của JSXGraph (`withLabel: false`).

- [x] **Phase 2: Tương Tác Mút Cận Tích Phân Reactive & Tính Diện Tích Tuyệt Đối**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`, `app.js`
  - Không destroy board khi kéo glider; đồng bộ giá trị với `boundAInput`, `boundBInput` theo thời gian thực.
  - Tích hợp magnetic snap 0.5.
  - Cập nhật huy hiệu $S = \int_a^b |f(x)| dx$ chuẩn SGK.

- [x] **Phase 3: Mở Khóa Kéo Cực Trị Nắn Hàm Số 2 Chiều**
  - File: `plugins/math_studio/ui/render/graph_plotter.js`, `app.js`
  - Bỏ `fixed: true` trên điểm cực trị, cho phép kéo theo trục tung/hoành.
  - Kết nối với `computeFormulaFromDrag` cập nhật `mathInput.value`.

- [x] **Phase 4: Kiểm Thử, Đóng Gói .hlep & Kiểm Tra Bất Biến Kiến Trúc**
  - Chạy `test_app_logic.mjs`, `test_curve_manipulator.mjs`, `test_geometry_3d.mjs`, `test_math_studio.mjs`, `test_revolution_solid.mjs`.
  - Đóng gói: `node scripts/validate_plugins.mjs --fix`.
  - Bất biến kiến trúc: `node scripts/run_architecture_check.mjs`.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-26 08:42
**Phase in progress:** completed
**Status:** Hoàn tất 100% việc tối ưu tương tác kéo thả mút tích phân, nắn cực trị và khử mờ số trục Ox.

### Decisions made this session
- Tắt hoàn toàn minorTicks trên JSXGraph, chỉ hiển thị số nguyên rõ nét với font 12px Bold Dark Charcoal.
- Thay thế nhãn tích phân có dấu của JSXGraph bằng việc tính toán và hiển thị Diện tích hình phẳng tuyệt đối $S = \int_a^b |f(x)|dx$.
- Kéo thả mút tích phân và cực trị hoạt động theo cơ chế reactive thời gian thực, không destroy board.

### Next immediate action
Báo cáo kết quả chi tiết cho người dùng.
