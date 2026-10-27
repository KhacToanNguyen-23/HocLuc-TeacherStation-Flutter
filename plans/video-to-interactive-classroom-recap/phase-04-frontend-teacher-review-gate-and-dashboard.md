# Phase 4: Frontend Teacher Review Gate & Dashboard Integration

**Status:** Not Started  
**Spec Coverage:** P1 (Story 4), P2 (Story 7), FR-07  
**Package:** `frontend/lib/features/classroom_meet/presentation/`

---

## 🎯 Goal
Xây dựng giao diện Cổng Kiểm Duyệt Sư Phạm (`RecapReviewDialog`) để giáo viên kiểm tra và tinh chỉnh nhanh mốc thời gian, PDF tóm tắt và câu hỏi trắc nghiệm trước khi xuất bản; đồng thời tích hợp các thẻ trạng thái và nút bấm vào `ClassroomDashboardScreen`.

---

## 🛠️ Tasks

1. **Interactive Review Gate Modal (`RecapReviewDialog`):**
   - **Tab 1: Mốc thời gian (Timestamps Editor):**
     - Danh sách các mốc: `MM:SS - Tiêu đề mốc`.
     - Cho phép giáo viên sửa nhanh text, bấm nghe/xem thử đoạn đó trên video preview, hoặc bấm icon xóa mốc thừa.
   - **Tab 2: Bản tóm tắt kiến thức (PDF Cheatsheet Preview):**
     - Card xem trước các công thức và mẹo giải do AI sinh ra.
     - Cho phép mở rộng toàn màn hình để đọc kỹ.
   - **Tab 3: Bộ câu hỏi trắc nghiệm (Quiz Editor):**
     - Hiển thị từng câu hỏi kèm 4 lựa chọn (có radio button đánh dấu đáp án đúng).
     - Cho phép giáo viên click đổi đáp án đúng nếu AI chọn nhầm.
     - Có nút `[ 🗑️ Xóa ]` và `[ 🔄 Sinh câu khác ]`.
   - **Nút hành động (Footer Actions):**
     - Nút `[ Lưu bản nháp (Draft) ]`: Lưu trạng thái chưa công khai.
     - Nút `[ Phê duyệt & Đăng lên Classroom ]`: Kích hoạt Backend xuất bản ngay lập tức.

2. **Tích Hợp Vào Classroom Dashboard (`ClassroomDashboardScreen`):**
   - Trên mỗi thẻ buổi học đã hoàn thành:
     - Trạng thái `Chưa phân tích` $\rightarrow$ Nút bấm: `[ ⚡ Tạo bài ôn tập ĐGNL ]`.
     - Trạng thái `Đang phân tích` $\rightarrow$ Badge xoay nhẹ: `[ AI đang xử lý... ]`.
     - Trạng thái `Chờ duyệt` $\rightarrow$ Badge nổi bật: `[ 🔔 Xem bản nháp ôn tập ]` (Click mở `RecapReviewDialog`).
     - Trạng thái `Đã xuất bản` $\rightarrow$ Badge xanh: `[ ✓ Đã đăng lên Classroom ]` kèm link mở nhanh trên web Classroom.
   - Hỗ trợ nút `[ Chọn video có sẵn ]` (P2) cho phép chọn file MP4 cũ trong máy hoặc từ Drive.

---

## 🧪 Verification
- Widget test `RecapReviewDialogTest`: Kiểm tra tương tác sửa mốc thời gian, đổi đáp án quiz, gọi callback phê duyệt.
- Widget test `ClassroomDashboardRecapBadgeTest`: Kiểm tra hiển thị đúng các trạng thái badge tương ứng với dữ liệu từ LocalService.
- Đảm bảo 100% component tuân thủ Design System (AppColors, AppRadii, typography chuẩn Manrope/Literata).

