# Brainstorm: Trang Sảnh Giáo Viên (Teacher Lobby) & Luồng Vào Thẳng Phòng Học

**Date:** 2026-10-10

## Ideas Explored
1. **Dừng lại 2-3 giây ở Sảnh để hiện popup link Meet:** Người dùng từ chối để tối ưu tốc độ vào lớp.
2. **Vào thẳng phòng Bảng vẽ (Được chọn):** Tại Sảnh, giáo viên bấm "Bắt đầu lớp học", hệ thống tự động khởi tạo Meet và điều hướng ngay vào Bảng vẽ (StudioScreen). Link Meet và nút sao chép nằm sẵn trên thanh công cụ nổi của Bảng vẽ.
3. **Thoát phòng học:** Khi giáo viên bấm nút Đóng lớp trên Bảng vẽ, app điều hướng quay trở lại Trang Sảnh.

## User's Direction
- Có một màn hình Sảnh đón tiếp cơ bản khi mở app (chưa cần UI đăng nhập phức tạp).
- Tại Sảnh có nút to: Bấm tạo lớp là tự động join Google Meet ngầm và tự động chuyển thẳng vào trang bảng vẽ.
- Khi đóng lớp / rời phòng, quay về lại Trang Sảnh.

## Open Questions
- Không còn câu hỏi mở.

## Risks
- Đảm bảo animation chuyển trang mượt mà giữa Lobby và Whiteboard Studio.
- Đảm bảo khi quay lại Lobby, tài nguyên WebView / Meet cũ được reset sạch sẽ.
