# Brainstorm: Header Icon Tối giản, Panel Trượt Đè (Overlay) & Quản lý Học sinh Chuẩn Zoom/Meet

**Date:** 2026-10-12

## Ideas Explored
1. **Header Icon Tối giản (TopBar):**
   - Loại bỏ toàn bộ nút chữ dài (chuyển nút "Lưu bài" thành Icon đĩa mềm Lưu `Icons.save_outlined`).
   - Đồng bộ kích thước mọi nút chức năng thành icon button 36x36px với tooltip rõ ràng khi hover.
   - Nút Rời phòng chuẩn Zoom: Nút bo góc nền đỏ đậm (`Color(0xFFE11D48)` hoặc `Color(0xFFDC2626)`), chữ trắng hoặc icon nổi bật ở góc phải.
   - Gọn gàng thanh link Meet: chỉ icon link + mã rút gọn, trạng thái lưu bằng dot/icon nhỏ.

2. **Panel Trượt Đè (Overlay Drawer - Không bóp méo UI):**
   - Thay vì đưa panel Tiện ích / Học sinh vào `Row` ngang cùng với bảng vẽ (làm bảng vẽ bị co lại/bóp méo), chuyển toàn bộ panel sang dạng **Overlay** trong `Stack` (`Positioned(top: 0, bottom: 0, right: 0, width: 320)`).
   - Không có lớp phủ mờ (no scrim backdrop) theo đúng yêu cầu người dùng: bảng vẽ đằng sau vẫn hiển thị rõ nét 100%.
   - Panel có bóng đổ mượt (`boxShadow`) tách biệt rõ ràng với bảng vẽ.

3. **Quản lý Học sinh Chuẩn Zoom & Google Meet:**
   - Header: "Người tham gia (1)" + Nút đóng `✕`.
   - Body:
     - Hàng đầu tiên: Bạn (Chủ phòng / Host) kèm micro.
     - Danh sách học sinh kết nối thật sự. Khi chưa có học sinh: Hiển thị dòng thông báo tinh tế *"Đang đợi học sinh tham gia..."*.
     - Bỏ ô tìm kiếm cồng kềnh.
   - Footer đáy: Nút "Tắt tiếng tất cả" (Mute All) đặt ở chân trang chuẩn Zoom.

## User's Direction
- Nút rời phòng: Chuẩn Zoom (nền đỏ đậm nổi bật).
- Nền khi mở panel: Không cần mờ nhẹ (không dùng scrim), để bảng vẽ lộ rõ đằng sau.
- Header: Toàn bộ dùng style icon đơn giản.
- Panel: Trượt đè lên mép phải, không bóp méo UI bảng vẽ.
- Học sinh: Quản lý tối giản chuẩn Zoom & Meet.

## Open Questions
- Không có (Các yêu cầu đã được xác định cụ thể và rõ ràng).

## Risks
- Đảm bảo widget tests cho `studio_test.dart` và `meet_cockpit_inspector_test.dart` tiếp tục pass 100% với cấu trúc Stack Overlay mới.
