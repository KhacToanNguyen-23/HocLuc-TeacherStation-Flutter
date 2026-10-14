# Phase 04: Merge nhánh Đề thi V-ACT/HSA của Nguyễn Đức Thịnh

## Mục tiêu
Tích hợp trọn bộ module đề thi V-ACT/HSA, backend Flyway SQL migrations và giao diện quản lý đề thi trong Studio Document Drawer.

## Các bước thực hiện
1. Thực hiện merge:
   ```powershell
   git merge origin/feat/vact-hsa-exam-platform --no-ff -m "merge: integrate V-ACT/HSA exam platform from Nguyen Duc Thinh"
   ```
2. Xác nhận không có xung đột code:
   - Thịnh đã cô lập popup đề thi vào Document Drawer, không đè lên Studio canvas.
3. Chạy test xác nhận:
   ```powershell
   flutter test test/exam_integration_test.dart test/webview_exam_session_test.dart
   ```
4. Kiểm tra backend:
   - Kiểm tra `backend/api/src/main/resources/db/migration/V1__exam_platform.sql`.
