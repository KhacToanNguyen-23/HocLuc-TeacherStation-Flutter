# Phase 5: End-to-End Verification & Edge Cases

**Goal:** Kiểm thử toàn diện toàn bộ quy trình từ lúc khởi động app đến khi kết thúc buổi dạy, đảm bảo tính ổn định và xử lý các trường hợp ngoại lệ.

---

## Tasks

1. **Kiểm thử E2E Full Flow:**
   - Kịch bản: Mở App -> Bấm Đăng nhập Google tại LoginScreen -> WebView2 mở OAuth dialog -> Đăng nhập & cấp quyền -> Chuyển vào Dashboard -> Chọn lớp học Classroom -> Bấm "Bắt đầu buổi học" -> Vào Studio -> Meet nạp link tự động và giáo viên là Host.
2. **Kiểm thử Edge Cases:**
   - Mất kết nối mạng giữa chừng: Hiển thị thông báo thân thiện và cho phép thử lại.
   - Hết hạn Access Token: Backend tự refresh bằng Refresh Token ngầm mà không làm ngắt kết nối giáo viên.
   - Đăng xuất tài khoản: Xóa sạch phiên trong app và cho phép đăng nhập bằng tài khoản Google khác mà không bị lẫn lộn.
3. **Chạy kiểm thử hồi quy (Architecture & Unit tests):**
   - `flutter test`
   - `mvn test` (cho module backend Google integrations)

## Verification Criteria
- 100% kịch bản thành công: Zero-click ra trình duyệt ngoài.
- Giáo viên đăng nhập 1 lần duy nhất và vào dạy bình thường.
- Không có lỗi biên dịch hoặc rò rỉ bộ nhớ.
