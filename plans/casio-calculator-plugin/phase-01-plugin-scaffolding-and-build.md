# Phase 01: Plugin Scaffolding & Web Bundle Build

**Goal:** Chuẩn bị hạ tầng đóng gói động, biên dịch repo `HocLucCalculator` thành bundle web tĩnh tương thích WebView2 local file, và thiết lập thư mục plugin chuẩn `plugins/casio_calculator/`.

---

## 1. Scope & Action Items

1. **Nâng cấp công cụ đóng gói `scripts/package_plugin.mjs`:**
   - Cho phép nhận tham số tên thư mục plugin từ dòng lệnh (ví dụ: `node scripts/package_plugin.mjs casio_calculator`), thay vì hardcode `english_assistant`.
   - Giữ tương thích ngược khi không truyền tham số (mặc định vẫn là `english_assistant`).
2. **Build bundle tĩnh từ `HocLucCalculator`:**
   - Sử dụng repo đã clone trong scratch space.
   - Thêm `base: './'` vào `vite.config.ts` để sinh asset dạng relative URL.
   - Chạy `npm run build` để xuất bundle ra thư mục `dist/`.
3. **Cấu trúc thư mục `plugins/casio_calculator/`:**
   - Tạo `plugins/casio_calculator/manifest.json` chuẩn v2 (`id: "com.hocluc.plugin.casio"`, `placement: "floating_window"`, `backend: null`, `permissions: ["board:insert_annotation"]`).
   - Đặt icon nhận diện `icon.png` vào thư mục plugin.
   - Chép toàn bộ sản phẩm `dist/*` vào `plugins/casio_calculator/ui/`.
   - Bổ sung `sdk.js` vào `plugins/casio_calculator/ui/sdk.js`.

---

## 2. Verification Criteria
- [ ] `node scripts/package_plugin.mjs --help` hoặc lệnh chạy nhận đúng thư mục plugin mục tiêu.
- [ ] Thư mục `plugins/casio_calculator/` có đầy đủ: `manifest.json`, `icon.png`, `ui/index.html`, `ui/sdk.js`, `ui/assets/`.
- [ ] `manifest.json` hợp lệ theo schema v2 (chạy `flutter test test/architecture_test.dart` kiểm tra bất biến 4).
