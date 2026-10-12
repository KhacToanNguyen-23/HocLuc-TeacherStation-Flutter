# Brainstorm: Tinh Gọn Lobby Chuẩn Google Meet & Bổ Sung Quản Lý Học Sinh (Mic/Cam/Join)

**Date:** 2026-10-12

## Ideas Explored
1. **Tinh gọn Lobby theo chuẩn Google Meet Green Room:**
   - Loại bỏ toàn bộ các khối chữ mô tả rườm rà ("Kiểm tra Thiết bị & Hình ảnh", "Thông tin Buổi học", "Chủ đề bài giảng", "Tín hiệu Micro: -20 dB", "Link lớp học chính thức gửi cho học sinh:...").
   - Bên trái (60%): Khung Camera Preview 16:9 bo góc lớn, các nút tròn điều khiển nổi (Mic, Cam, Phông nền) nằm ngay phía dưới/trên video theo đúng chuẩn Google Meet. Thiết bị Mic/Cam có thể đổi qua icon Cài đặt (Settings).
   - Bên phải (40%): Tiêu đề bài giảng lớn, trạng thái tài khoản giáo viên, hộp sao chép link Meet nhỏ gọn, nút chính "Bắt đầu vào phòng" và nút "Hủy / Quay lại Dashboard".
   - Topbar: Nút "← Quay lại Dashboard" rõ ràng.

2. **Bổ sung Nút Hủy / Rời phòng học:**
   - Tại Lobby: Nút "Hủy / Quay lại" bên cạnh hoặc dưới nút "Bắt đầu".
   - Tại Studio: Thêm nút "Rời phòng / Kết thúc buổi học" (màu đỏ) trên Top Bar có dialog xác nhận để giáo viên quay về Dashboard bất kỳ lúc nào.

3. **Quản lý học sinh tham gia lớp & Mic/Cam (Chuẩn Zoom):**
   - **Student Video/Avatar Strip (Dải học sinh phía trên bảng đen):**
     - Hiển thị danh sách các thẻ học sinh nằm ngang ngay dưới Top Bar (Avatar/Video, Tên, Icon Mic, Icon Cam, Icon Giơ tay ✋).
     - Viền xanh phát sáng khi học sinh đang nói.
     - Có nút thu gọn/mở rộng dải này để giáo viên tối đa hóa diện tích bảng viết khi cần.
   - **Thanh duyệt học sinh nổi (Admission Banner / Floating Knock):**
     - Khi có học sinh bấm link xin vào phòng Meet: Hiện banner nổi ngay trên màn hình ("Nguyễn Văn A xin vào lớp" -> [Cho vào] / [Từ chối], hoặc [Duyệt tất cả]).
   - **Sidebar Học sinh (Participants Drawer):**
     - Nút icon `👥 Học sinh (N)` trên Topbar mở ra danh sách đầy đủ tất cả học sinh trong lớp.
     - Từng học sinh có trạng thái Mic/Cam rõ ràng, nút [Tắt tiếng] riêng cho từng em.
     - Nút [Tắt tiếng tất cả] (Mute All) để giữ trật tự lớp học.
   - **Dữ liệu & Meet Bridge:**
     - Mở rộng `MeetBridgeScript` và `MeetAutomationService` để quét danh sách học sinh (`PARTICIPANTS_UPDATE`) từ DOM Meet thật và cung cấp danh sách học sinh trực quan.

## User's Direction
- Người dùng yêu cầu:
  1. Bố cục Lobby chuẩn Google Meet / Zoom, bỏ hết các description rườm rà gây rối mắt.
  2. Bổ sung nút back / hủy phòng học ở cả Lobby và Studio.
  3. Có chỗ cho phép học sinh join vào Meet, quản lý camera và mic của từng học sinh (dải học sinh ngang trên bảng đen chuẩn Zoom + Sidebar danh sách học sinh).

## Open Questions
- Không có câu hỏi mở. Hướng thiết kế và vị trí thành phần đã được thống nhất hoàn toàn.

## Risks
1. **Diện tích bảng vẽ khi có dải học sinh:** Cần làm dải học sinh nhỏ gọn (chiều cao ~70-80px) và có nút Thu gọn (Collapse/Expand) để không lấn chiếm không gian viết bảng của giáo viên.
2. **DOM selector của Google Meet khi quét danh sách học sinh:** Bridge Script cần fallback an toàn nếu Google Meet thay đổi giao diện DOM, bảo đảm không bao giờ gây gián đoạn Studio.
