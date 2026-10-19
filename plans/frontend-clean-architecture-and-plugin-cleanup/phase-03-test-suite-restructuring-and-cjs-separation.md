# Phase 03: Test Suite Restructuring & CJS Separation

**Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-clean-architecture-and-plugin-cleanup/plan.md)  
**Status:** Completed  
**Target Directory:** `frontend/test/`

---

## 1. Mục Tiêu & Yêu Cầu

Tổ chức lại toàn bộ 64 file test đang nằm phẳng trong `frontend/test/` thành các thư mục con có cấu trúc:

1. **`test/architecture/`:**
   - `architecture_test.dart`
2. **`test/e2e_browser/`:**
   - Chuyển `meet_admission_bridge.browser.cjs` và `meet_screen_share.test.cjs` vào thư mục này để tách biệt hoàn toàn script Node.js khỏi test runner của Flutter.
3. **`test/features/auth/`:**
   - `auth_modal_test.dart`, `google_connection_identity_test.dart`.
4. **`test/features/classroom_meet/`:**
   - Tất cả các bài test liên quan đến Meet, Microphone, Audio Translation, Classroom API và Dashboard (23 test files).
5. **`test/features/plugin_engine/`:**
   - Các bài test liên quan đến manifest, marketplace, storage, web server, process supervisor, casio e2e, english e2e (10 test files).
6. **`test/features/studio_board/`:**
   - Các bài test liên quan đến drawing engine, smart chalk, smart pen, pdf stage, switcher, sticker (22 test files).
7. **`test/features/exams/`:**
   - `exam_integration_test.dart`, `webview_exam_session_test.dart`.

---

## 2. Tiêu Chí Nghiệm Thu

- Không còn bất kỳ file test nào nằm phẳng ngoài root `frontend/test/` (ngoại trừ file chốt chặn nếu cần, hoặc toàn bộ chuyển vào `test/architecture/architecture_test.dart`).
- Cập nhật đường dẫn import trong các file test.
- Chạy `flutter test` và xác nhận toàn bộ test suite đều **PASS**.

