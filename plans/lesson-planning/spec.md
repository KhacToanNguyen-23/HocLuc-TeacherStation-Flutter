# Spec: Lesson Planning & Classroom Launch

**Date:** 2026-10-14  
**Status:** Ready

---

## Problem Statement
Giáo viên cần không gian chuẩn bị bài giảng trước (viết vẽ bảng, dàn trang, chèn tài liệu, ghi chú, đặt câu hỏi) một cách độc lập trước buổi học mà không cần khởi tạo phòng học thực tế có kết nối Google Meet. Sau khi chuẩn bị xong, giáo viên có thể dùng chính bản kế hoạch này để khởi tạo phòng học thực tế nhiều lần cho các lớp khác nhau mà không làm thay đổi bản kế hoạch gốc.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a teacher, I want to create and manage lesson plans from a dedicated "Kế hoạch bài giảng" tab on the dashboard, so that I can organize my teaching materials before classes.  
  *Accepted when:* Tab "Kế hoạch bài giảng" hiển thị danh sách các bài giảng đã lưu với đầy đủ thông tin (tiêu đề, môn học, thời gian tạo/cập nhật, số trang) và nút "Tạo kế hoạch bài giảng" khi danh sách trống.

- **[P1]** As a teacher, I want to prepare lesson content using the familiar Teaching Studio whiteboard interface (drawing tools, multi-page canvas, stickers, smart chalk tools, notes), so that my preparation experience matches the actual classroom environment.  
  *Accepted when:* Khi mở một bản planning, StudioScreen chuyển sang chế độ Planning: ẩn Google Meet link bar, thay nút "Rời phòng" bằng nút "Lưu bài giảng / Thoát", và có nút "Tạo phòng học".

- **[P1]** As a teacher, I want to click "Tạo phòng học" directly from the Planning Studio or from the Planning card in Dashboard, so that a new live classroom is launched populated with the exact planned content without modifying the original template.  
  *Accepted when:* Hệ thống khởi tạo phòng học mới với trạng thái ONGOING, sao chép (clone) toàn bộ nội dung của planning sang phòng học mới, và mở giao diện Live Studio; bản planning gốc không bị ảnh hưởng bởi nét vẽ trong giờ học.

- **[P2]** As a teacher, I want to duplicate or delete existing lesson plans from the dashboard list.  
  *Accepted when:* Mỗi thẻ bài planning trong danh sách có nút xóa và nhân bản bài giảng nhanh.

- **[P3]** _(out of scope — noted for future)_: Xuất/nhập file planning ra định dạng tệp tin rời hoặc chia sẻ bài giảng giữa các giáo viên trong hệ thống.

---

## Functional Requirements

<!-- Number each. Be specific. -->

1. **FR-01 (Dashboard 3-Tab Layout):**
   - Khu vực danh sách chính trên Dashboard chuyển thành cấu trúc 3 tab ngang: `[Phòng học]`, `[Kế hoạch bài giảng]`, `[Lịch sử]`.
   - Chuyển tab mượt mà, giữ trạng thái lọc/dữ liệu của từng tab.
2. **FR-02 (Planning List & Empty State):**
   - Tab "Kế hoạch bài giảng" hiển thị danh sách dạng lưới/thẻ các bản planning đã lưu (Tiêu đề, Môn học, Ngày cập nhật, Số trang).
   - Nếu chưa có dữ liệu, hiển thị empty state minh họa kèm nút "Tạo kế hoạch bài giảng".
   - Mỗi thẻ có hành động: "Mở soạn tiếp" (Edit in Planning Studio), "Dạy ngay" (Launch Classroom), "Xóa".
3. **FR-03 (Planning Studio Mode):**
   - Khi mở tạo mới hoặc chỉnh sửa planning, StudioScreen nhận cờ `isPlanning: true` và `planningId`.
   - Top bar: Ẩn Meet URL bar (hoặc hiển thị nhãn "Chế độ soạn bài").
   - Thay nút đỏ "Rời phòng" bằng nút "Lưu / Thoát" và nút chính "Tạo phòng học" (nút xanh nổi bật).
   - Giáo viên thao tác vẽ, xóa, chèn tài liệu PDF/ảnh, tạo trang mới, đổi tên trang, ghi chú... bình thường.
4. **FR-04 (Planning CRUD API - Backend):**
   - Cung cấp các endpoint REST API trong backend:
     - `GET /api/plannings`: Lấy danh sách metadata của các bản planning.
     - `GET /api/plannings/{id}`: Lấy chi tiết toàn bộ nội dung bài giảng (lesson JSON snapshot).
     - `POST /api/plannings`: Tạo mới bản planning.
     - `PUT /api/plannings/{id}`: Cập nhật nội dung bản planning.
     - `DELETE /api/plannings/{id}`: Xóa bản planning.
5. **FR-05 (Clone to Live Classroom Flow):**
   - Khi bấm "Tạo phòng học" (từ Planning Studio hoặc từ thẻ Planning trên Dashboard):
     - Nếu có phòng học ONGOING khác đang mở, hiển thị modal xác nhận đóng phòng cũ.
     - Khởi tạo phòng học mới qua `ClassroomService.createClassroom(...)`.
     - Sao chép toàn bộ cấu trúc dữ liệu lesson (trang, nét vẽ, nhãn dán, câu hỏi, ghi chú) của bản planning sang dữ liệu bài giảng của phòng học mới.
     - Điều hướng giáo viên vào phòng học trực tiếp (Live Studio).

---

## Non-Functional Requirements

- **Performance:** Thao tác nạp và clone bài giảng từ planning vào phòng học mới hoàn tất trong < 1.5 giây.
- **Data Integrity:** Nét vẽ, chỉnh sửa phát sinh trong buổi dạy trực tiếp tuyệt đối không ghi đè vào bản planning gốc.
- **Usability:** 100% thanh công cụ vẽ, phím tắt và thao tác trên bảng vẽ hoạt động đồng nhất giữa Planning Mode và Live Classroom Mode.

---

## Success Criteria

- [x] Tạo mới 1 bản kế hoạch bài giảng, thêm 3 trang vẽ và tài liệu, bấm lưu: dữ liệu xuất hiện chính xác trong tab "Kế hoạch bài giảng".
- [x] Bấm "Tạo phòng học" từ bản kế hoạch: Phòng học mới được kích hoạt, tải đủ 3 trang nội dung đã soạn.
- [x] Trong phòng học vừa tạo, vẽ thêm nét mới và kết thúc phòng học: Mở lại bản planning gốc, các nét vẽ thêm trong buổi học không xuất hiện (đảm bảo tính toàn vẹn của template gốc).
- [x] Dashboard chuyển đổi linh hoạt và chính xác giữa 3 tab `[Phòng học]`, `[Kế hoạch bài giảng]`, `[Lịch sử]`.

---

## Out of Scope

- Đồng bộ real-time nhiều giáo viên cùng cộng tác trên 1 bản planning (Collaborative planning).
- Xuất/nhập file bài giảng ra định dạng tệp zip/package bên ngoài.

---

## Assumptions

- `StudioState` có các phương thức `exportLessonJson()` và `restoreFromJson()` hoạt động ổn định và bao quát toàn bộ tài nguyên trên bảng.
- Dữ liệu lưu trữ dạng JSON file ở backend đáp ứng tốt hiệu năng lưu trữ và nạp bài giảng của từng giáo viên.

---

## [NEEDS CLARIFICATION]

- Không có điều kiện chặn.
