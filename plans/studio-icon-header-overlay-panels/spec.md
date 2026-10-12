# Spec: Header Icon Tối Giản, Overlay Panels Không Bóp UI & Quản Lý Học Sinh Chuẩn Zoom/Meet

## 1. Mục tiêu & Phạm vi
- **Header Studio (`StudioTopBar`):**
  - Chuyển toàn bộ các nút thành Icon Button đồng nhất (kích thước 34x34px, có Tooltip khi hover).
  - Nút "Lưu bài" chuyển thành icon đĩa mềm `Icons.save_outlined`.
  - Nút "Rời phòng" thiết kế theo phong cách Zoom: Nút màu đỏ nổi bật (nền đỏ đậm `Color(0xFFDC2626)`, chữ trắng hoặc icon logout trắng rõ nét).
  - Tên bài giảng, icon link Meet và badge trạng thái lưu được tinh chỉnh gọn gàng, không rối mắt.
- **Cơ chế Overlay Drawer (Không bóp UI bảng vẽ):**
  - Các panel bên phải (`StudioStudentsDrawer`, `StudioPluginsMarketplacePanel`, `StudioInspectorPanel`) được đặt đè lên màn hình trong `Stack` (`Positioned(top: 0, bottom: 0, right: 0, width: 320)`).
  - Không có lớp phủ mờ (no backdrop scrim): Bảng vẽ đằng sau vẫn hiển thị rõ ràng 100%, không bị co giật hay thay đổi kích thước.
  - Panel có bóng đổ sang trái (`boxShadow`) phân tách chuyên nghiệp.
- **Quản lý học sinh chuẩn Zoom / Meet (`StudioStudentsDrawer`):**
  - Header: Tiêu đề "Người tham gia (1)" + Nút đóng `✕`.
  - Bỏ ô tìm kiếm cồng kềnh.
  - Body: Thẻ Bạn (Chủ phòng) ở trên, danh sách học sinh (hoặc dòng chờ nhẹ nhàng *"Đang đợi học sinh tham gia..."* khi chưa có ai).
  - Footer đáy: Nút "Tắt tiếng tất cả" (Mute All) đặt ở chân trang theo đúng bố cục của Zoom.

---

## 2. User Stories & Acceptance Criteria

### User Story 1 (P1 - Header Icon & Nút Rời phòng Zoom)
- **Là một** giáo viên đang dạy học,
- **Tôi muốn** thanh Header chỉ có các biểu tượng icon gọn gàng và nút Rời phòng đỏ kiểu Zoom,
- **Để** tập trung tối đa vào bài dạy và không bị rối mắt bởi các nút chữ dài.
- **Tiêu chí chấp nhận:**
  - Không có nút chữ dài trên Header ngoại trừ tên bài giảng và nút Rời phòng đỏ nổi bật kiểu Zoom.
  - Nút Lưu bài là icon đĩa mềm.
  - Các nút có tooltip mô tả rõ ràng khi hover.

### User Story 2 (P2 - Overlay Panels không bóp méo bảng vẽ)
- **Là một** giáo viên đang thao tác tiện ích hoặc quản lý lớp,
- **Tôi muốn** khi bấm mở Tiện ích hoặc Học sinh, bảng đó trượt đè lên mép phải chứ không bóp méo bảng vẽ,
- **Để** không gian bảng vẽ giữ nguyên tỷ lệ 100%, không bị giật hay co nhỏ lại.
- **Tiêu chí chấp nhận:**
  - Bảng vẽ giữ nguyên 100% kích thước khi mở/đóng panel.
  - Panel trượt đè lên ở mép phải trong `Stack`.
  - Không có nền mờ che bảng vẽ.

### User Story 3 (P3 - Quản lý học sinh tối giản Zoom/Meet)
- **Là một** giáo viên điều hành lớp,
- **Tôi muốn** bảng người tham gia gọn gàng, có nút tắt tiếng cả lớp ở chân trang giống Zoom,
- **Để** kiểm soát âm thanh lớp học nhanh chóng.
- **Tiêu chí chấp nhận:**
  - Nút "Tắt tiếng tất cả" nằm ở chân trang (Footer).
  - Bỏ ô tìm kiếm cồng kềnh.

---

## 3. Success Metrics
- Bảng vẽ không bị thay đổi kích thước dù mở hay đóng panel.
- Header đồng bộ 100% icon buttons gọn gàng.
- Toàn bộ test suite `flutter test` pass 100%.
