# Brainstorm: Tinh giản Lobby 50/50 & Tái cấu trúc Studio Chuẩn Google Meet/Zoom

**Date:** 2026-10-12

## Ideas Explored
1. **Lobby Screen (Màn hình Chờ / Chuẩn bị phòng):**
   - Loại bỏ cụm 4 nút hiệu ứng nền ảo (Gốc, Mờ nhẹ, Mờ sâu, Phòng học ảo) vì không có xử lý AI thực tế, làm vỡ bố cục.
   - Lồng 2 nút bật/tắt Mic và Camera trực tiếp vào bên trong khung video (ở đáy giữa/dưới) chuẩn Google Meet Green Room.
   - Loại bỏ 3 nút phụ rườm rà dưới link Meet ("Tạo link mới", "Mở trên Chrome", "Dán link có sẵn"), chỉ giữ lại link Meet + nút Sao chép.
   - Cân đối tỷ lệ 2 cột 50% / 50% ngang bằng nhau và căn giữa màn hình.

2. **Studio Screen (Màn hình Lớp học / Giảng dạy):**
   - **Xóa bỏ hoàn toàn Mock Data:**
     - Xóa dải Top Carousel học sinh (dải đen che đầu với 6 học sinh mock: Nguyễn Văn An, Trần Thị Bình,...).
     - Xóa banner popup nổi "Có 2 học sinh xin vào lớp".
     - Xóa nội dung slide trắc nghiệm Q1 mock trên canvas bảng vẽ, trả lại không gian bảng vẽ / stage tinh khôi.
     - Ẩn badge kỹ thuật `Java OK` trên top bar.
   - **Tái cấu trúc bố cục chuẩn Google Meet / Zoom:**
     - **Top Bar:** Tối giản với Tên bài giảng, thời lượng/mã phòng, link Meet (rút gọn/sao chép), nút Rời phòng nổi bật.
     - **Left Toolbar (Theo yêu cầu người dùng):** Thanh công cụ bút vẽ, màu sắc, tẩy được đặt dọc ở mép trái.
     - **Right Side Panel:** Cơ chế Single-Drawer (chỉ mở tối đa 1 bảng tại 1 thời điểm: Danh sách thành viên 👥 hoặc Tiện ích môn học 🧩). Panel thành viên không chứa học sinh mock, chỉ hiển thị Giáo viên (Host) và thông báo chờ học sinh tham gia.
     - **Main Stage:** Mở rộng tối đa, thông thoáng không bị che khuất.

## User's Direction
- **Trang Lobby:** Bố cục 50/50 gọn gàng, nút Mic và Camera lồng trực tiếp bên trong video preview.
- **Trang Studio:** Bố cục thanh thoát kiểu Google Meet/Zoom, thanh công cụ giảng dạy đặt ở thanh dọc bên trái. Loại bỏ hoàn toàn mock data.

## Open Questions
- Điều hướng các trang bảng: Đặt nút trang bảng tích hợp vào Left Toolbar hoặc một floating controller nhỏ ở góc dưới bảng.

## Risks
- Cần cập nhật các widget test của `classroom_lobby_screen_test.dart` và `studio_test.dart` tương ứng với giao diện mới để đảm bảo bộ test luôn pass 100%.
