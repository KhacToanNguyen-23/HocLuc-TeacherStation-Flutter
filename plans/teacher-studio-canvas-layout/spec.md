# Spec: Universal Teaching Studio Canvas & Ergonomic Split Layout

**Date:** 2026-10-09  
**Status:** Ready

---

## Problem Statement
Giáo viên giảng dạy trực tuyến cần một không gian Studio chuyên nghiệp, chống mỏi mắt và tối ưu công thái học (ergonomics) cho tỷ lệ xuất hình 16:9 (Virtual Camera cho Google Meet / Zoom). Thay vì các giao diện phân chia môn học rườm rà hoặc chuyển đổi cửa sổ gây gián đoạn bài giảng, hệ thống cung cấp một Bảng ô li xanh đen mặc định đa năng, tích hợp trình đọc PDF cho phép viết vẽ đè trực tiếp theo từng trang và cơ chế chuyển đổi Split/Fullscreen tức thì.

---

## User Stories

- **[P1]** As a Giáo viên, I want to mở ứng dụng là thấy ngay Bảng ô li xanh đen dịu mắt so that tôi có thể bắt đầu giảng bài ngay lập tức cho bất kỳ môn học nào mà không bị phân tâm.  
  *Accepted when:* Ứng dụng khởi động trực tiếp vào Bảng ô li nền xanh đen (#14221D); toàn bộ các dữ liệu gán cứng môn Toán và đồ thị parabol cũ được loại bỏ hoàn toàn.

- **[P1]** As a Giáo viên, I want to rê chuột trên bảng và thấy một chấm sáng (Laser Pointer) so that tôi có thể dễ dàng chỉ trỏ, nhấn mạnh điểm mấu chốt cho học sinh theo dõi.  
  *Accepted when:* Tọa độ con trỏ chuột hiển thị chấm sáng dạ quang mượt mà, hỗ trợ bật/tắt giữa chế độ Bút vẽ (Pen) và chế độ Chỉ trỏ (Laser Pointer).

- **[P1]** As a Giáo viên, I want to import tài liệu PDF đề bài qua hộp thoại File Picker hoặc kéo thả (Drag & Drop) so that việc nạp giáo trình vào tiết dạy diễn ra nhanh nhất.  
  *Accepted when:* Người dùng có thể bấm nút chọn file hoặc kéo thả file `.pdf` vào vùng làm việc; tài liệu hiển thị sắc nét trong không gian dạy.

- **[P1]** As a Giáo viên, I want to viết, vẽ, khoanh tròn trực tiếp đè lên trang PDF và nét vẽ được lưu riêng theo từng trang so that tôi có thể giải đề chi tiết mà không bị lẫn lộn giữa các trang.  
  *Accepted when:* Vẽ trên trang PDF 1 rồi chuyển sang trang 2 thì trang 2 có lớp vẽ trống; khi quay lại trang 1 các nét vẽ cũ vẫn được hiển thị chính xác.

- **[P1]** As a Giáo viên, I want to chuyển đổi tức thì giữa các chế độ hiển thị bằng 1-chạm hoặc phím tắt (F1 Toàn màn hình Bảng, F2 Toàn màn hình PDF, F3 Chia đôi Split 50/50) so that bài giảng liền mạch trên khung hình 16:9.  
  *Accepted when:* Nhấn F1/F2/F3 hoặc click icon trên Top Bar, giao diện chuyển đổi êm ái mà không bị giật lag hay lệch tỷ lệ 16:9.

- **[P2]** As a Giáo viên, I want to hiển thị khung Webcam của chính mình (Camera PIP) ở góc bảng so that học sinh luôn nhìn thấy giáo viên trong khi xem bài giảng.  
  *Accepted when:* Khung PIP $240 \times 135\text{ px}$ bo góc hiển thị ở góc trên bên phải, có thể kéo thả hoặc bấm nút ẩn tạm thời.

- **[P2]** As a Giáo viên, I want to mở danh sách câu hỏi / mục lục bài học dạng Drawer trượt từ cạnh trái so that tôi có thể chọn nội dung dạy tiếp theo mà không làm mất diện tích viết bảng.  
  *Accepted when:* Bấm icon mục lục thì Drawer trượt ra, chọn câu hỏi xong Drawer tự động thu gọn trả lại toàn bộ diện tích cho Canvas.

- **[P2]** As a Giáo viên, I want to có một thẻ Timer đếm ngược nổi nhỏ gọn ở cạnh trên so that tôi quản lý thời gian làm bài của học sinh thuận tiện.  
  *Accepted when:* Thẻ Timer hiển thị số phút:giây nhỏ gọn, bấm mở rộng để cài đặt và bắt đầu đếm giờ.

- **[P3]** _(out of scope — ghi nhận tương lai)_ Học sinh tương tác và viết vẽ hai chiều từ xa trên bảng qua kết nối thời gian thực.

---

## Functional Requirements

1. **FR-01 (Blackboard Grid Theme):** Bảng viết sử dụng nền xanh đen chuẩn bảng phấn học đường (`#14221D` hoặc `#162720`), lưới kẻ ô li học sinh kích thước $24 \times 24\text{ px}$ với độ tương phản dịu mắt, đường kẻ mảnh màu xanh xám rêu mờ.
2. **FR-02 (Interactive Freehand Drawing Engine):** Bảng vẽ tương tác xây dựng bằng `Flutter CustomPainter` kết hợp thư viện `perfect_freehand` (MIT) để tạo nét mực mượt mà, tự nhiên (stroke smoothing, variable stroke width như bút phấn/bút viết bảng thật), hỗ trợ các công cụ: Bút viết (Pen), Tẩy (Eraser), và Xóa tất cả.
3. **FR-03 (Laser Pointer Cursor):** Khi di chuyển chuột trên vùng Canvas/PDF ở chế độ chỉ trỏ (Laser Pointer mode), con trỏ hiển thị dạng chấm sáng dạ quang (bán kính 4–6px, hiệu ứng tỏa sáng nhẹ) giúp học sinh dễ định vị điểm nhìn.
4. **FR-04 (High-Performance PDF Engine via pdfrx):** Tích hợp thư viện `pdfrx` (Engine Google PDFium, Apache 2.0) để render tài liệu PDF phần cứng mượt mà trên cả Flutter Web và Windows Desktop; hỗ trợ import file `.pdf` thông qua cả hộp thoại hệ thống (`FilePicker`) và kéo thả tệp (`Drag & Drop`).
5. **FR-05 (Per-page PDF Annotations):** Lưu trữ nét vẽ chú thích theo từng trang tài liệu (`Map<int, List<BoardStroke>>`). Khi chuyển đổi trang PDF qua lại trên `pdfrx`, bảng vẽ tự động tải đúng danh sách nét vẽ của trang đó mà không bị lem hay mất dữ liệu.
6. **FR-06 (Ergonomic 16:9 Layout):** Khung làm việc chính luôn giữ tỷ lệ $16:9$ chuẩn phát sóng (tránh méo hình khi truyền qua Virtual Camera), cung cấp 3 chế độ hiển thị:
   - `Mode Full Board:` 100% diện tích là bảng ô li xanh đen.
   - `Mode Full PDF:` 100% diện tích là trang PDF (có khoảng lề nháp hai bên).
   - `Mode Split View:` Nửa trái là trang PDF đề bài (50%), nửa phải là bảng ô li giải bài (50%).
7. **FR-07 (Quick Viewport Switching):** Hỗ trợ chuyển đổi nhanh giữa 3 chế độ qua phím tắt (`F1`, `F2`, `F3`) và các nút chuyển đổi 1-chạm trên thanh điều khiển Top Bar.
8. **FR-08 (Floating Camera PIP Card):** Khung Camera PIP tỷ lệ 16:9 ($240 \times 135\text{ px}$) bo tròn góc 12px, có viền mảnh tinh tế, ghim mặc định góc trên phải, hỗ trợ nút ẩn/hiện nhanh.
9. **FR-09 (Collapsible Sidebar/Drawer):** Bảng danh sách câu hỏi / mục lục bài học được chuyển thành Drawer trượt từ cạnh trái (animation $\le 250\text{ms}$), tự động đóng sau khi chọn để giải phóng không gian viết.
10. **FR-10 (Floating Timer Widget):** Widget đồng hồ đếm ngược thiết kế dạng viên thuốc (pill badge) nhỏ gọn ở cạnh trên, hỗ trợ đếm ngược có âm báo kết thúc.

---

## Technical Stack & Libraries

- **PDF Engine:** `pdfrx` (Google PDFium backend, Apache-2.0) — render PDF nhanh, hỗ trợ zoom mượt, tương thích Web & Windows.
- **Stroke Smoothing:** `perfect_freehand` (MIT) — thuật toán mô phỏng nét bút thư pháp/bút bảng mịn, bo góc tự nhiên.
- **Rendering Layer:** Flutter `CustomPainter` tối ưu hóa repaint boundary.
- **File Ingestion:** `file_picker` (Apache-2.0) + `desktop_drop` (MIT).

---

## Non-Functional Requirements

- **Performance:** Tốc độ tương tác viết/vẽ và chuyển trang duy trì ổn định $\ge 60\text{ FPS}$; độ trễ phản hồi chuột/bút $< 16\text{ms}$.
- **Ergonomics & Visual Comfort:** Toàn bộ bảng màu nền tối được căn chỉnh giảm thiểu phát xạ ánh sáng xanh, chống mỏi mắt cho giáo viên và học sinh trong các buổi học dài $\ge 2\text{ giờ}$.
- **Platform Compatibility:** Tương thích mượt mà trên cả môi trường Flutter Web preview (chạy qua Java service cổng 47831) và Windows Desktop native runner.

---

## Success Criteria

- [ ] Khởi động ứng dụng mở ngay Bảng ô li xanh đen sạch sẽ, không còn phụ thuộc vào dữ liệu môn Toán gán cứng.
- [ ] Chuyển đổi giữa 3 chế độ (F1 Full Bảng, F2 Full PDF, F3 Split 50/50) diễn ra trong $< 100\text{ms}$ mượt mà.
- [ ] Import file PDF thành công qua cả File Picker và Kéo-thả.
- [ ] Viết đè lên PDF và lật qua lại giữa các trang bảo toàn 100% nét vẽ của từng trang.
- [ ] Con trỏ chuột Laser Pointer hiển thị trơn tru, không giật lag trên bề mặt Canvas.
- [ ] Camera PIP, Timer và Drawer mục lục hoạt động độc lập dạng floating/drawer, không lấn chiếm không gian viết chính.

---

## Out of Scope

- Chưa triển khai hệ thống học sinh vẽ tương tác 2 chiều từ xa (bảo lưu cho giai đoạn sau).
- Chưa triển khai tính năng nhận dạng chữ viết tay (OCR) hay chuyển đổi nét vẽ thành text toán học tự động.

---

## Assumptions

- Tỷ lệ khung hình của Studio được tối ưu hóa cho màn hình chuẩn 16:9 để sẵn sàng kết nối vào luồng Virtual Camera.
- Trình duyệt/máy tính của giáo viên hỗ trợ chuẩn WebGL / Canvas rendering tiêu chuẩn của Flutter.
