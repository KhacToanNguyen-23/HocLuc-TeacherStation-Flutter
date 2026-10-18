# Spec: Chế Độ Hiển Thị Sát Viền Thân Máy (`frameless: true`) Cho Plugin Máy Tính Casio

**Slug:** `frameless-casio-plugin`  
**Date:** 2026-10-17  
**Brainstorm Report:** `plans/reports/261017-frameless-casio-plugin-brainstorm.md`

---

## 1. Bối Cảnh & Vấn Đề (Problem Statement)

Hiện tại khi mở plugin **Máy Tính Khoa Học Casio** trên bảng phấn, chiếc máy tính bị bao quanh bởi:
1. Thanh tiêu đề cửa sổ nổi (`FloatingPluginWindow`) khá dày ở phía trên.
2. Phần nền xám trắng (`#edf1f5`), thanh điều hướng `hocluc.com` (gồm nút menu, chụp ảnh, loa, xoay) ở trên và dòng chữ `© 2026 hocluc.com` ở dưới đáy của trang web gốc.

Điều này làm chiếc máy tính chiếm diện tích thừa trên bảng phấn và có viền trắng bao quanh kém thẩm mỹ. Giáo viên cần chiếc máy tính hiển thị **chỉ đúng thân máy tính Casio** nằm gọn trên bảng phấn, có thể nắm kéo ở gờ trên thân máy và bấm nút `×` nhỏ gọn để đóng.

---

## 2. User Stories & Phân Loại Ưu Tiên (P1 / P2 / P3)

### P1 — Bắt buộc (Core MVP)

1. **[P1 - Giáo viên] Hiển thị chỉ đúng thân máy tính Casio sát viền trên bảng phấn:**
   - **Là một** giáo viên đang giảng bài trên bảng phấn,
   - **Tôi muốn** khi mở Máy Tính Khoa Học Casio, trên bảng chỉ xuất hiện đúng thân máy tính màu xám đen (màn hình LCD + bàn phím) bo góc tự nhiên, không có nền trắng bao quanh, không có logo `hocluc.com` hay dòng bản quyền thừa,
   - **Để** tiết kiệm tối đa diện tích bảng phấn và tạo cảm giác trực quan như đang đặt một chiếc máy tính thật trên bảng.

2. **[P1 - Giáo viên] Kéo di chuyển và Đóng máy tính ngay trên gờ trên của thân máy:**
   - **Là một** giáo viên sử dụng chuột hoặc màn hình cảm ứng,
   - **Tôi muốn** nắm kéo trực tiếp vào gờ trên của vỏ máy Casio để di chuyển máy tính tới bất kỳ góc nào trên bảng và bấm nút `×` nhỏ ở góc phải trên của thân máy để đóng,
   - **Để** thao tác nhanh gọn mà không cần thanh tiêu đề cửa sổ cồng kềnh.

3. **[P1 - Developer / Kiến trúc] Thuộc tính `"frameless": true` trong Manifest Schema v2.1 (Zero-Hardcode):**
   - **Là một** lập trình viên phát triển plugin thiết bị (máy tính, thước đo góc, đồng hồ bấm giờ),
   - **Tôi muốn** khai báo `"frameless": true` trong `manifest.json` để Host tự động bật chế độ cửa sổ nổi sát viền mà không phải hardcode tên plugin trong `frontend/lib/`,
   - **Để** giữ nguyên tính đóng gói độc lập của kiến trúc Clean Microkernel.

---

## 3. Tiêu Chí Nghiệm Thu Định Lượng (Measurable Success Criteria)

- **SC-01 (0px viền trắng bao quanh):** Toàn bộ `.calculator-app-heading` (`hocluc.com`), `.calculator-copyright` (`© 2026 hocluc.com`) và khoảng đệm nền `#edf1f5` xung quanh `.calc-face` trong plugin Casio được ẩn/xóa bỏ 100%; thân máy `.calc-face` khớp sát 100% khung hiển thị (`328x556`, bo góc `24px`).
- **SC-02 (Zero-Hardcode Invariant):** `flutter test test/architecture_test.dart` đạt **5/5 PASS** (không có bất kỳ câu lệnh `if (id == 'com.hocluc.plugin.casio')` nào trong `frontend/lib/`).
- **SC-03 (Đóng gói `.hlep` thật & Kiểm thử E2E):** Gói `plugins/casio_calculator.hlep` được đóng gói lại với `frameless: true` và `embed.css`, vượt qua 100% bài kiểm thử `flutter test test/casio_calculator_e2e_test.dart`.

---

## 4. Thiết Kế Kỹ Thuật Tóm Tắt

1. **Mở rộng `PluginManifest` & `PluginCatalogItem`:**
   - Bổ sung trường `final bool frameless;` (đọc từ `json['frameless'] == true` hoặc `json['ui']['frameless'] == true`, mặc định `false`).
2. **Nâng cấp `FloatingPluginWindow` (`frontend/lib/widgets/floating_plugin_window.dart`):**
   - Khi `plugin.manifest.frameless == true`:
     - Bỏ thanh Header bar rời rạc bên trên; dùng `ClipRRect(borderRadius: BorderRadius.circular(24))` ôm sát nội dung WebView.
     - Đặt một dải nắm kéo trong suốt tích hợp thanh gạch nắm mảnh (`drag pill`) ở chính giữa gờ trên thân máy (`height: 24px`) và nút đóng `×` nhỏ gọn (`22x22`) ở góc trên bên phải thân máy.
3. **Tinh chỉnh giao diện gói `plugins/casio_calculator`:**
   - Thêm tệp `plugins/casio_calculator/ui/embed.css` được nhúng vào `plugins/casio_calculator/ui/index.html`:
     - Ẩn `.calculator-app-heading`, `.calculator-copyright`, `.update-banner`.
     - Đặt `.calculator-app`, `.calculator-fit-stage` tràn viền `padding: 0; margin: 0; background: transparent;`.
     - Đặt `.calculator-app .calc-playground-face` và `.calculator-app .calc-face` chiếm trọn `width: 100% !important; height: 100% !important; position: static !important; transform: none !important; border-radius: 24px !important; padding: 18px 12px 14px !important;` để bàn phím và màn hình LCD luôn hiển thị đầy đủ, sắc nét và khít tuyệt đối với khung cửa sổ nổi (`328x556`).
   - Cập nhật `plugins/casio_calculator/manifest.json` (`"frameless": true`, `"default_width": 328`, `"default_height": 556`) và chạy `node scripts/package_plugin.mjs casio_calculator`.

