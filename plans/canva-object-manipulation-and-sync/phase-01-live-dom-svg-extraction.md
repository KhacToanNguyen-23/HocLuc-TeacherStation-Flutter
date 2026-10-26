# Phase 1: Live DOM SVG Extraction (Math Studio Plugin)

**Objective:** Bê nguyên vẹn đối tượng SVG mà JSXGraph / 3D Engine / BBT Engine đã vẽ trên màn hình panel Math Studio sang Bảng phấn, loại bỏ hoàn toàn hàm render thứ hai (`generateGraphSvg`) gây sai lệch màu sắc và tỷ lệ.

---

## 1. Context & Root Cause
- Hiện tại, khi giáo viên bấm "Xong" hoặc "Ghim lên bảng", `handlePinToBoard` trong `app.js` lại gọi hàm `generateGraphSvg()` tự vẽ lại chuỗi SVG từ các công thức toán học.
- Hàm này tự ý gán màu và thiết lập bounding box riêng, khiến đồ thị trên bảng không khớp 100% với những gì giáo viên đang nhìn thấy trong panel.
- Trong khi đó, DOM của `#graphContainer` (hoặc `#integralGraphContainer`, `#geometry3dContainer`, `#bbtContainer`) đã chứa sẵn thẻ `<svg>` vector hoàn chỉnh và sắc nét mà JSXGraph đã render.

---

## 2. Implementation Steps

1. **Thêm hàm trích xuất `exportLiveContainerSvg(containerEl, options)` trong `plugins/math_studio/ui/app.js`:**
   - Tìm thẻ `<svg>` bên trong `containerEl`.
   - Tạo bản sao `cloneNode(true)` để không làm xáo trộn DOM preview đang hiển thị.
   - Bổ sung `xmlns="http://www.w3.org/2000/svg"`, `width="100%"`, `height="100%"`.
   - Nếu `options.transparentBg === true`: đảm bảo `style.backgroundColor = 'transparent'` và gỡ bỏ fill nền opaque để khi ghim lên bảng đen, đồ thị hòa nhập tự nhiên với màu phấn bảng.
   - Thêm nhãn phụ trợ nếu có (ví dụ: công thức và nhãn cận nếu JSXGraph render dạng overlay).

2. **Cập nhật `handlePinToBoard` trong `plugins/math_studio/ui/app.js`:**
   - Với `activeView === 'integral'`: trích xuất DOM SVG từ `#integralGraphContainer`.
   - Với `activeView === 'geometry3d'`: trích xuất DOM SVG từ `#geometry3dContainer` (hoặc `geometry3dEngine.generateSvg({ theme: 'chalkboard' })`).
   - Với `activeView === 'bbt'`: trích xuất DOM SVG từ `#bbtContainer`.
   - Với `activeView === 'graph'`: trích xuất DOM SVG từ `#graphContainer`.
   - Nếu container có SVG hợp lệ $\rightarrow$ dùng ngay SVG trích xuất; nếu chưa có (fallback) $\rightarrow$ mới dùng hàm sinh SVG dự phòng.

3. **Đóng gói plugin:**
   - Chạy `node scripts/validate_plugins.mjs --fix` để đóng gói lại `plugins/math_studio.hlep` đồng bộ Schema v2.1.

---

## 3. Acceptance Criteria
- [ ] Khi bấm "Ghim lên bảng", chuỗi SVG gửi sang Flutter là bản sao chính xác từ thẻ `<svg>` đang hiển thị trong panel.
- [ ] Không còn sai lệch màu sắc (đường cong màu đỏ `#DC2626`, cận tích phân đỏ, cực trị xanh navy viền trắng y hệt panel).
- [ ] `node scripts/test_math_studio.mjs` đạt 7/7 tests (100%).
- [ ] `node scripts/validate_plugins.mjs` đạt 3/3 plugins valid (0 lỗi).

