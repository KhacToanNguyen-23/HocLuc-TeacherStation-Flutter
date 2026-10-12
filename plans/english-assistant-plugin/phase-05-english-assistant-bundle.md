# Phase 05: English Assistant Sample Bundle (`.hlep`) & End-to-End Tests

**Canonical Phase ID:** `phase-05-english-assistant-bundle`  
**Stories Covered:** P1, P2 (Gói hoàn chỉnh, Đóng gói .hlep, End-to-end integration)  
**Priority:** P1  

---

## Objective
Tạo gói plugin mẫu hoàn chỉnh `english_assistant.hlep` theo đúng tài liệu thiết kế (manifest, `ui/index.html`, `ui/app.js`, `engine/service.py`), tích hợp nút cài đặt và trải nghiệm hoàn thiện từ A-Z với bộ test suite toàn diện.

---

## Scope & Implementation Tasks

1. **Khởi tạo thư mục mã nguồn plugin (`plugins/english_assistant/`):**
   - `manifest.json`: Khai báo thông tin gói `com.hocluc.plugin.english`.
   - `icon.png`: Biểu tượng vuông trợ giảng Tiếng Anh 64x64.
   - `ui/index.html` & `ui/app.js`: Giao diện tương tác tiếng Anh, gọi spaCy và LanguageTool, có xử lý bridge postMessage chuẩn xác cho cả Web (`window.parent.postMessage`) và Windows (`window.chrome.webview.postMessage`), kèm mock fallback khi backend offline.
   - `engine/service.py`: Script FastAPI spaCy bóc tách Chủ - Vị - Tân ngữ S-V-O.

2. **Tạo script đóng gói `.hlep` (`scripts/package_plugin.mjs`):**
   - Nén thư mục `plugins/english_assistant/` thành file nhị phân `plugins/english_assistant.hlep`.

3. **Tích hợp nút "Cài thêm tiện ích môn" trong Drawer:**
   - Trong `drawer_questions.dart`, khi bấm "Cài thêm tiện ích môn", cho phép người dùng nạp file `english_assistant.hlep` hoặc chọn cài đặt ngay plugin mẫu Trợ giảng Tiếng Anh chỉ với 1 click.

4. **Viết End-to-End Integration Test (`frontend/test/english_assistant_e2e_test.dart`):**
   - Kiểm tra toàn bộ chu trình:
     1. Khởi động `StudioScreen`.
     2. Mở ngăn kéo Tài liệu -> Bấm mở plugin Trợ giảng Tiếng Anh.
     3. Drawer Panel 420px trượt ra hiển thị `FlatHost`.
     4. Bắn sự kiện giả lập `INSERT_ANNOTATION` với các token S-V-O.
     5. Thẻ `BoardSticker` xuất hiện trên mặt bảng phấn `InteractiveChalkboard`.
     6. Kéo thả di chuyển thẻ thành công.
     7. Kiểm tra dữ liệu bài giảng `studio.save()` chứa thẻ và khôi phục sau reload.

---

## Files Affected
- `plugins/english_assistant/manifest.json` (new)
- `plugins/english_assistant/ui/index.html` (new)
- `plugins/english_assistant/ui/app.js` (new)
- `plugins/english_assistant/engine/service.py` (new)
- `scripts/package_plugin.mjs` (new)
- `frontend/lib/widgets/drawer_questions.dart`
- `frontend/test/english_assistant_e2e_test.dart` (new)

---

## Dependencies
- Phụ thuộc toàn bộ Phase 01, Phase 02, Phase 03, Phase 04.

---

## Tests and Acceptance Criteria
- Chạy `flutter test test/english_assistant_e2e_test.dart`:
  - 100% các bước từ cài đặt, hiển thị panel, nhận bridge message, sinh thẻ S-V-O trên bảng phấn đến lưu bài giảng đều pass.
- Chạy `flutter test` toàn bộ hệ thống: 0 test fail.
- Chạy `flutter analyze`: 0 errors, 0 warnings.
