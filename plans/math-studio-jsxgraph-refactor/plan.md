# Plan: Refactor Engine Đồ Thị Sang Chuẩn JSXGraph (Hướng B)

Risk: normal — Tích hợp engine JSXGraph vào math_studio plugin thay thế SVG thủ công
Spec: `plans/math-studio-jsxgraph-refactor/spec.md`
Date: 2026-10-26

---

## Architecture Strategy
1. **Vendor Asset Isolation**: Đặt `jsxgraphcore.js` và `jsxgraph.css` vào `plugins/math_studio/ui/vendor/jsxgraph/`. Nạp vào `index.html` độc lập, hoàn toàn offline.
2. **Dual-Mode Graph Plotter Engine (`graph_plotter.js`)**:
   - `renderJSXGraphBoard(containerId, analysis, integralResult, options)`: Khởi tạo/cập nhật bảng vẽ JSXGraph tương tác trực tiếp trên DOM của WebView2. Tự động tính toán đường cong, đường gióng SGK, điểm cực trị với auto-offset nhãn, miền phẳng tích phân và tiệm cận.
   - `generateGraphSvg(analysis, integralResult, options)`: Hàm sinh SVG độc lập phục vụ Node.js tests (`test_app_logic.mjs`) và xuất SVG vector tĩnh khi ghim lên Studio Board.
3. **App UI Orchestration (`app.js` & `style.css`)**:
   - Khởi tạo board JSXGraph trong thẻ `#graphContainer` và `#integralGraphContainer`.
   - Kết nối 2 chiều giữa thanh điều khiển bên trái (`mathInput`, `boundA`, `boundB`, các nút `Giao Ox`, `Giao Oy`, `Cực trị`) với JSXGraph Board.
   - Đồng bộ màu sắc thương hiệu Học Lực (Light theme và Chalkboard theme).
4. **Verification & Packaging**:
   - Đảm bảo 100% tests logic (`test_app_logic.mjs`, `test_curve_manipulator.mjs`, `test_geometry_3d.mjs`, `test_math_studio.mjs`, `test_revolution_solid.mjs`) đều vượt qua.
   - Đóng gói `.hlep` bằng `node scripts/validate_plugins.mjs --fix`.
   - Kiểm tra 12 Bất biến kiến trúc: `node scripts/run_architecture_check.mjs`.

---

## Phases

- [x] **Phase 1: Vendor Assets & HTML/CSS Setup**
  - Đảm bảo `jsxgraphcore.js` và `jsxgraph.css` có mặt đầy đủ.
  - Cập nhật `index.html` liên kết CSS và Script vendor.
  - Thêm CSS tùy biến cho container `#graphContainer` và nhãn toán học SGK.

- [x] **Phase 2: Xây Dựng Bộ Render JSXGraph Trong `graph_plotter.js`**
  - Cấu hình board JSXGraph: trục tọa độ chuẩn SGK ($Ox, Oy$, mũi tên, gốc $O$, bước vạch).
  - Vẽ hàm số bằng `functiongraph` với thuật toán adaptive sampling mượt mà.
  - Tạo các điểm cực trị, đường gióng nét đứt vuông góc với trục tọa độ.
  - Tự động định vị nhãn (auto-positioning) chống đè chữ triệt để.

- [x] **Phase 3: Tích Hợp Miền Tích Phân & Điểm Tương Tác**
  - Vẽ miền phẳng tích phân với màu trong suốt trang nhã giữa 2 mút $a, b$.
  - Hỗ trợ tiệm cận đứng, ngang (cho hàm phân thức) bằng đường nét đứt chuẩn SGK.
  - Hỗ trợ hiển thị giao điểm với $Ox$, $Oy$ và điểm do người dùng đánh dấu.

- [x] **Phase 4: Kết Nối `app.js` & Luồng Ghim Lên Bảng (Studio Board)**
  - Tích hợp `renderJSXGraphBoard` vào hàm `reactiveRender` và `renderGraphOnly` trong `app.js`.
  - Giữ vững xuất SVG cho nút "Xong" (`insertToBoard`).
  - Hỗ trợ đổi theme linh hoạt (Sáng / Bảng phấn).

- [x] **Phase 5: Kiểm Thử, Đóng Gói .hlep & Bất Biến Kiến Trúc**
  - Chạy `node scripts/test_app_logic.mjs`.
  - Chạy `node scripts/validate_plugins.mjs --fix`.
  - Chạy `node scripts/run_architecture_check.mjs` (12/12 PASS).

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-26 08:28
**Phase in progress:** completed
**Status:** Hoàn tất 100% tái cấu trúc đồ thị sang engine JSXGraph chuẩn quốc tế (Hướng B).

### Decisions made this session
- Tích hợp JSXGraph v1.9.2 offline hoàn toàn trong `plugins/math_studio/ui/vendor/jsxgraph/`.
- Dual-mode architecture: JSXGraph interactive board trên WebView2 + Ultra-crisp SVG generation khi ghim lên Studio Board / chạy headless tests.
- Tất cả 5 test suites và 12 bất biến kiến trúc đều đạt 100%.

### Next immediate action
Báo cáo kết quả và hướng dẫn trải nghiệm cho người dùng.

