# Phase 4: Studio Screen Seamless Host Session

**Goal:** Đảm bảo khi mở màn hình Studio dạy học, WebView2 tự động mở link Google Meet và nhận diện giáo viên là Host bằng cookie phiên đã lưu từ Phase 1, giữ nguyên toàn bộ công cụ Studio hiện có.

---

## Tasks

1. **Kiểm tra `MeetAutomationService` và `WebviewEnvironmentService`:**
   - Đảm bảo WebView2 trong Studio dùng cùng `_resolvedUserDataPath` (`%APPDATA%\HocLucTeacherStation\EdgeProfile`).
   - Nạp link Meet (`existingUrl`) vào WebView2 mà không chuyển hướng về trang login của Google.

2. **Kiểm tra `StudioScreen`:**
   - Hiển thị Meet trong dock/drawer popup hiện tại của `MeetAdmissionShell` khi giáo viên cần xem học sinh / chat / giơ tay.
   - Duy trì camera ảo bài giảng và stream âm thanh trơn tru.

## Verification Criteria
- WebView2 trong Studio mở link Meet và giáo viên lập tức là Chủ phòng (Host) với đầy đủ quyền quản lý cuộc họp.
- Không xuất hiện bất kỳ cửa sổ yêu cầu đăng nhập tài khoản Google nào nữa.
