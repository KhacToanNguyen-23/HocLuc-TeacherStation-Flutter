# Phase 06: Tổng kiểm tra hệ thống và Release lên Origin Develop

## Mục tiêu
Kiểm thử toàn diện toàn bộ các tính năng sau khi hội tụ về `develop`, đảm bảo hệ thống sẵn sàng hoạt động mà không có bất kỳ lỗi biên dịch hay hồi quy nào.

## Các bước thực hiện
1. **Full Frontend Test Suite:**
   ```powershell
   flutter test
   ```
2. **Windows Native Build Dry-Run:**
   ```powershell
   flutter build windows --debug
   ```
3. **Backend Health Check:**
   - Chạy `mvn test-compile` trên `backend/api`.
4. **Push hoàn tất:**
   ```powershell
   git push origin develop
   ```
   Thông báo cho cả nhóm kéo `develop` mới nhất về máy cá nhân.
