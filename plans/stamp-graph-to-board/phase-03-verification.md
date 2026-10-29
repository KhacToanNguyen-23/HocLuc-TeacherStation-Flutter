# Phase 3: Kiểm thử Tự động & Bảo vệ Kiến trúc

## Mục tiêu
Đảm bảo tất cả các quy tắc kiến trúc (12/12 invariants), không có tên plugin hay chuỗi môn học bị hardcode trong `frontend/lib/`, và phân tích mã nguồn Flutter không có cảnh báo/lỗi nào.

## File tác động
- Kiểm thử kiểm tra các file đã sửa đổi và toàn bộ test suite hiện có.

## Các lệnh kiểm thử bắt buộc
1. Chạy phân tích cú pháp tĩnh:
   ```powershell
   flutter analyze --no-fatal-infos
   ```
   *Yêu cầu: 0 errors, 0 warnings.*
2. Chạy cổng bảo vệ kiến trúc (Architecture Gate):
   ```powershell
   flutter test test/architecture_test.dart
   ```
   *Yêu cầu: 12/12 passing invariants (100%).*
3. Chạy kiểm thử runtime của plugin native:
   ```powershell
   flutter test test/features/plugin_engine/native_plugin_runtime_test.dart
   ```
   *Yêu cầu: Tất cả các bài test vượt qua.*
4. Xác thực đồng bộ plugin:
   ```powershell
   node scripts/validate_plugins.mjs
   ```
   *Yêu cầu: 0 errors.*

