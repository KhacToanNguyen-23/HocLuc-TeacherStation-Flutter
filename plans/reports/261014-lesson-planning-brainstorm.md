# Brainstorm: Lesson Planning & Direct Classroom Creation

**Date:** 2026-10-14

## Ideas Explored
- **Ý tưởng cốt lõi:** Cho phép giáo viên tạo trước các bản kế hoạch bài giảng (Planning / Giáo án điện tử) trên chính giao diện bảng trắng Studio quen thuộc trước khi buổi học diễn ra.
- **Phương án A (Direct State):** Chuyển trực tiếp bản planning thành phòng học đang diễn ra. *(Bị loại vì các nét vẽ, tương tác của học sinh trong buổi dạy sẽ làm thay đổi hoặc làm bẩn giáo án gốc, không thể tái sử dụng)*.
- **Phương án B (Clone / Template - Được chọn):** Bản planning đóng vai trò như một template mẫu. Khi giáo viên nhấn "Tạo phòng học", hệ thống nhân bản (clone) toàn bộ nội dung sang phòng học trực tiếp mới. Giáo viên có thể dùng lại bài giảng cho nhiều lớp khác nhau (10A1, 10A2...).
- **Bố cục Dashboard:**
  - Lựa chọn hệ thống 3 tab ngang rõ ràng: `[Phòng học] - [Kế hoạch bài giảng] - [Lịch sử]`.
  - Tab "Kế hoạch bài giảng" hiển thị danh sách các bài giảng đã lưu cùng các nút hành động (Soạn tiếp, Dạy ngay, Xóa).
- **Trải nghiệm trong Planning Studio:**
  - Giữ nguyên toàn bộ thanh công cụ vẽ, tài liệu, nhãn dán, đồng hồ, ghi chú để giáo viên chuẩn bị trực quan.
  - Ẩn/tắt liên kết Google Meet (vì đang ở bước chuẩn bị bài giảng trước giờ học).
  - Góc trên bên phải: Thay nút đỏ "Rời phòng" bằng nút "Lưu bài giảng / Thoát" và nút hành động chính "Tạo phòng học" (Dạy ngay).

## User's Direction
- **Cơ chế:** Dùng cơ chế **Clone (nhân bản)** khi tạo phòng từ planning để giữ nguyên vẹn bài giảng gốc.
- **Vị trí Dashboard:** Chuyển khu vực nội dung thành **3 tab ngang** gồm `[Phòng học]`, `[Kế hoạch bài giảng]`, `[Lịch sử]`.
- **Giao diện:** Tái sử dụng không gian Teaching Studio hiện tại cho Planning Studio, bổ sung nút "Tạo phòng học" nổi bật.

## Open Questions
- Khi bấm "Tạo phòng học" từ Planning, có hiển thị popup xác nhận tạo Meet (để giáo viên chọn nhập link Meet hoặc tạo tự động) hay tạo tự động với cấu hình mặc định?
- Tần suất tự động lưu (auto-save) trong lúc soạn bài giảng (ví dụ lưu mỗi khi đổi trang, đổi nét vẽ sau 5 giây debounced hay chỉ khi bấm Lưu).

## Risks
- Kích thước payload bài giảng (nhiều trang, tài liệu đính kèm, annotations) có thể lớn: cần đảm bảo serialize/deserialize JSON hiệu quả và clone nhanh (< 1.5s).
- Xử lý phiên phòng học cũ: Nếu đang có phòng học ONGOING trên hệ thống khi bấm "Tạo phòng học", cần có cảnh báo đóng phòng cũ tương tự luồng hiện tại.
