
# Spec: Tinh giản Lobby 50/50 & Tái cấu trúc Studio Chuẩn Google Meet / Zoom

## 1. Mục tiêu & Phạm vi
- **Lobby Screen (`ClassroomLobbyScreen`):**
  - Tinh giản giao diện thành 2 cột cân đối 50/50 ngang bằng nhau.
  - Cột trái: Khung Video Preview bo góc chuẩn mực, 2 nút bật/tắt Mic và Camera lồng trực tiếp ở đáy video. Loại bỏ cụm 4 nút nền ảo.
  - Cột phải: Tiêu đề buổi học (cho phép sửa nhanh), khung link Meet + nút Sao chép, 1 nút chính "Bắt đầu vào phòng giảng dạy", 1 nút phụ "Hủy / Quay lại Dashboard". Loại bỏ 3 nút bấm phụ dưới link Meet.
- **Studio Screen (`StudioScreen`):**
  - Quét sạch 100% Mock Data: Xóa dải học sinh ngang (Top strip đen), xóa banner "Có 2 học sinh xin vào lớp", xóa slide mock trắc nghiệm Q1 trên canvas, xóa badge kỹ thuật `Java OK`.
  - Bố cục tối giản kiểu Google Meet / Zoom:
    - Top bar: Tên bài giảng, thời gian học, link Google Meet (click để copy), các nút mở panel (👥 Thành viên, 🧩 Tiện ích), nút "Rời phòng" màu đỏ.
    - Left Toolbar: Thanh công cụ bảng vẽ dọc bên trái (Bút vẽ, tẩy, chọn màu, hoàn tác/làm lại, xóa bảng).
    - Stage trung tâm: Bảng vẽ / trình chiếu chiếm toàn bộ không gian, không bị che khuất.
    - Right Panel (Cơ chế Single-Drawer): Chỉ mở tối đa 1 panel bên phải (Thành viên hoặc Tiện ích). Bảng thành viên chỉ hiển thị Host (Giáo viên) + Empty State chờ kết nối, không có học sinh giả.

---

## 2. User Stories & Acceptance Criteria

### User Story 1 (P1 - Lobby 50/50 gọn gàng)
- **Là một** giáo viên chuẩn bị vào lớp,
- **Tôi muốn** một màn hình chờ cân đối 50/50, nhìn rõ camera preview của mình với nút mic/cam ngay trên video,
- **Để** kiểm tra nhanh thiết bị và vào lớp ngay mà không bị rối mắt bởi các nút bấm không cần thiết.
- **Tiêu chí chấp nhận:**
  - Hai cột trái/phải chia đều tỉ lệ 50% / 50%.
  - 2 nút bật/tắt Mic & Cam hiển thị bên trong đáy khung video preview.
  - Cột phải chỉ có tên buổi học, link Google Meet + nút Sao chép, và 2 nút hành động (Vào phòng & Quay lại).

### User Story 2 (P2 - Studio không mock data & chuẩn Google Meet / Zoom)
- **Là một** giáo viên trong phòng học trực tuyến,
- **Tôi muốn** không gian dạy học tinh gọn, chuyên nghiệp giống Google Meet / Zoom,
- **Để** tập trung vào việc giảng dạy trên bảng và quản lý học sinh thật sự.
- **Tiêu chí chấp nhận:**
  - Không có dải 6 học sinh mock ở trên đầu.
  - Không có popup giả mạo "học sinh xin vào lớp".
  - Canvas bảng vẽ trống sạch sẽ, sẵn sàng vẽ hoặc viết bài.
  - Thanh công cụ vẽ đặt ở thanh dọc bên trái.
  - Bấm nút Thành viên hoặc Tiện ích mở đúng 1 panel trượt bên phải, không bị mở đè 2 panel cùng lúc.

---

## 3. Success Metrics
- 100% mock data (học sinh giả, câu hỏi slide giả, admission banner giả) được gỡ bỏ khỏi màn hình Studio.
- Layout Lobby hiển thị chuẩn tỉ lệ 50/50 trên màn hình Desktop.
- Toàn bộ test suite `flutter test` pass 100%.
