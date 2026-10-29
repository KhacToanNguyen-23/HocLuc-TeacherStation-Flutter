# Implementation Plan: Math Studio (Academic White Theme & Hand-Drawn Sketch Graph)

Mode: --fast
Risk: normal — Chuyển đổi toàn diện Math Studio sang phong cách Academic Trắng (SGK / Desmos), đồ thị nét phác thảo vẽ tay (Hand-drawn RoughJS), và sửa triệt để lỗi thẻ ghim bảng bị đen / trống trơn.

---

## 1. Yêu cầu Người dùng & Nhận định Vấn đề

Theo phản hồi mới nhất của người dùng:
1. **Lỗi thẻ ghim bảng bị đen thui / trống trơn (User screenshot 4):**
   - Hàm `handleStampToChalkboard` trong `main.jsx` bọc dữ liệu trong `{ data: { ... } }`, trong khi `bridge.js` bóc tách ở cấp cao nhất. Dẫn đến `imageBase64` và `svgContent` đều là `undefined`. Flutter Host tạo thẻ nhưng không có dữ liệu hình ảnh/vector $\to$ render rỗng (`SizedBox.shrink()`).
   - Thư viện `flutter_svg` của Flutter không hỗ trợ thẻ `<marker>` (làm mất mũi tên chiều biến thiên BBT) và bỏ qua CSS `style="background:..."` trên `<svg>`.
   - **Giải pháp:** Sửa chữ ký hàm `Bridge.insertAnnotation`, xuất SVG có `<rect>` nền và các mũi tên vẽ trực tiếp bằng `<polygon>`, đồng thời xuất ảnh PNG độ nét cao (2x DPR) làm fallback bảo đảm hiển thị 100%.

2. **Chuyển toàn bộ UI sang Academic Trắng (Academic White / SGK Paper):**
   - Loại bỏ hoàn toàn Dark mode / Neon gaming.
   - Nền trắng tinh khiết / ngà giấy tập `#F8FAFC` & `#FFFFFF`, viền xám học thuật `#E2E8F0`, chữ đen than `#0F172A`, công thức dùng font Times New Roman / Cambria Math nghiêng.
   - Thẻ bài học trắng tinh với bóng mờ thanh lịch, các nút bấm và slider mang màu xanh học thuật `#2563EB`.

3. **Đồ thị nét phác thảo vẽ tay (Hand-drawn Sketch):**
   - "Đồ thị tôi muốn nó vẽ tay xí chứ không cứng như này": Kích hoạt năng lực RoughJS (`roughness: 0.8 - 1.0`, `bowing: 0.8`) cho trục tọa độ Oxy, đường cong hàm số $f(x)$, tiếp tuyến và đường $y = m$.
   - Trục Oxy và đường cong trông như nét giáo viên vẽ bằng phấn trên bảng hoặc vẽ bút trên giấy tập, tự nhiên và sống động thay vì đường CAD thẳng đơ.

---

## 2. Kế hoạch triển khai (4 Phases)

### Phase 1: Sửa triệt để cơ chế Ghim bảng (Host Bridge & SVG/PNG Stamping)
- **File:** `plugins/math_studio/src/app/bridge.js` & `main.jsx`
  - Đồng bộ chuẩn tham số `Bridge.insertAnnotation({ title, imageBase64, svgContent, aspectRatio, metadata })`.
  - Đảm bảo `imageBase64` và `svgContent` luôn được truyền chính xác sang Host Bridge.
- **File:** `plugins/math_studio/src/app/pages/bbt.jsx`
  - Thay `<marker>` bằng `<polygon>` vẽ trực tiếp ở đầu mũi tên để `flutter_svg` hiển thị đầy đủ trên mọi nền tảng.
  - Bổ sung `<rect width="100%" height="100%" fill="#ffffff" rx="8" ...>` vào SVG của BBT để khi ghim lên bảng có khung thẻ học thuật màu trắng nổi bật, độ tương phản cao.

### Phase 2: Chuyển đổi toàn diện sang Academic White Theme
- **File:** `plugins/math_studio/ui/style.css`
  - Chuyển toàn bộ biến CSS sang màu trắng học thuật:
    - `--bg-main: #f8fafc;` (nền tổng thể xám giấy ngà)
    - `--bg-panel: #ffffff;` (sidebar trắng tinh khiết)
    - `--bg-card: #ffffff;` (card công thức, tham số)
    - `--border-color: #e2e8f0;` (viền mỏng tinh tế)
    - `--text-main: #0f172a;` (chữ đen than dễ đọc)
    - `--text-muted: #475569;` (chữ phụ xám slate)
    - `--academic-blue: #2563eb;` (xanh dương giáo khoa)
    - `--academic-red: #dc2626;` (đỏ cờ chấm điểm)
    - `--academic-amber: #d97706;` (vàng hổ phách)
    - `--academic-green: #059669;` (xanh ngọc lục bảo)
- **File:** `graph.jsx`, `integral.jsx`, `bbt.jsx`
  - Cập nhật màu sắc các nhãn, slider, badge và giá trị số phù hợp với nền trắng.

### Phase 3: Nâng cấp Đồ thị sang Nét Vẽ Tay (Hand-drawn Sketch)
- **File:** `plugins/math_studio/src/stage/roughRenderer.js`
  - Kích hoạt nét vẽ tay của RoughJS:
    - Trục Oxy: `rc.line` với `roughness: 0.8`, `bowing: 0.8` (như kẻ thước tay).
    - Đường cong $f(x)$: `rc.linearPath` hoặc `rc.curve` với `roughness: 0.7` (như nét phấn lượn mềm mại).
    - Tiếp tuyến: `rc.line` với `roughness: 0.8`, màu đỏ `#dc2626`.
    - Đường $y = m$: nét đứt phác tay màu vàng hổ phách.
    - Điểm cực trị và giao điểm: chấm tròn hoặc vòng tròn phác tay nhẹ.
    - Nền canvas đồ thị: màu trắng ngà giấy kẻ ô `#ffffff` với lưới đồ thị xám thanh mảnh `#e2e8f0`.

### Phase 4: Đóng gói, Kiểm thử & Nghiệm thu
- Biên dịch bundle web: `node plugins/math_studio/build.mjs`.
- Chạy unit test engine & stage: `node --test plugins/math_studio/engine/tests/engine.test.mjs` & `stage.test.mjs`.
- Đóng gói plugin: `node scripts/package_plugin.mjs math_studio`.
- Kiểm tra tính toàn vẹn: `node scripts/validate_plugins.mjs`.
- Kiểm tra kiến trúc: `flutter test test/architecture_test.dart`.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->
**Last active:** 2026-10-29 04:45
**Phase in progress:** completed
**Status:** All 4 phases completed and verified. 12/12 architecture invariants pass, 20/20 unit tests pass, plugins validated and packaged.

### Decisions made this session
- Synchronized `Bridge.insertAnnotation` parameter structure between UI and host bridge SDK.
- Converted full Math Studio UI to Academic White (SGK / Textbook standard).
- Added Catmull-Rom sketch roughness (`roughness: 0.7 - 0.8`) using RoughJS for natural hand-drawn chalkboard feel.
- Enhanced BBT with explicit SVG `<rect>` background and direct `<polygon>` arrowheads compatible with `flutter_svg`.

### Next immediate action
Ready for user demonstration and testing.
