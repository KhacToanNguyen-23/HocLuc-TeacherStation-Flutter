# Phase 05 — E2E Integration and Clone

**Phase ID:** `phase-05-e2e-integration-and-clone`  
**Priority:** P1  
**Status:** not_started  

---

## Objective
Hoàn thiện toàn diện quy trình nhân bản (Clone) từ một bản kế hoạch bài giảng sang phòng học trực tiếp (Live Classroom), đảm bảo tính cô lập dữ liệu (Data Isolation) và kiểm thử chất lượng end-to-end trên toàn bộ hệ thống.

---

## Scope & Implementation Tasks
1. **Luồng "Tạo phòng học từ Planning":**
   - Hỗ trợ gọi từ 2 điểm:
     - Nút "Dạy ngay" trên từng thẻ bài giảng ở Dashboard.
     - Nút "Tạo phòng học" trên thanh TopBar trong Planning Studio.
   - **Các bước thực thi của luồng:**
     1. Kiểm tra phòng học đang diễn ra (`_activeRoom != null && status == 'ONGOING'`). Nếu có, hiển thị dialog xác nhận "Đóng phòng cũ & Tạo mới".
     2. Mở dialog chuẩn bị phòng học (hoặc tự động tạo qua Google Meet flow hiện có).
     3. Gọi endpoint `POST /api/plannings/{id}/clone-to-classroom` để nhân bản toàn bộ nội dung của plan sang `lesson.json` của phiên phòng học mới.
     4. Khởi tạo `Classroom` mới trên backend với trạng thái `ONGOING`.
     5. Điều hướng người dùng vào `StudioScreen` ở chế độ Live Classroom (kèm Meet link và nút "Rời phòng").
2. **Kiểm tra Tính Toàn Vẹn & Cô Lập Dữ Liệu (Clone Isolation Verification):**
   - Khi ở phòng học mới, giáo viên vẽ thêm nét, thêm trang, hoặc xóa bảng.
   - Sau đó quay lại Dashboard tab "Kế hoạch bài giảng" và mở lại bản planning gốc.
   - **Xác thực:** Toàn bộ nội dung của bản planning gốc vẫn giữ nguyên trạng thái trước khi dạy.
3. **Kiểm tra Hồi quy (Regression Testing):**
   - Đảm bảo luồng tạo phòng học thông thường (từ nút "Bắt đầu" ở Dashboard) vẫn hoạt động nguyên vẹn.
   - Đảm bảo luồng lịch sử phòng học vẫn hoạt động chính xác ở tab "Lịch sử".

---

## Files & Modules Affected
- `frontend/lib/screens/classroom_dashboard_screen.dart`
- `frontend/lib/screens/studio_screen.dart`
- `frontend/lib/services/local_service.dart`
- `backend/api/src/main/java/vn/teaching/service/PlanningService.java`

---

## Dependencies
- Phụ thuộc: `phase-01-backend-planning-api`, `phase-02-frontend-service-and-models`, `phase-03-dashboard-planning-tab`, `phase-04-studio-planning-mode`.

---

## Tests & Acceptance Criteria
- Kịch bản E2E:
  1. Tạo bài giảng "Toán 10 - Bất phương trình" gồm 2 trang có hình vẽ và ghi chú.
  2. Bấm "Tạo phòng học" từ bài giảng đó.
  3. Phòng học Live xuất hiện với đúng 2 trang và hình vẽ đã chuẩn bị.
  4. Vẽ thêm 1 hình tròn màu đỏ và kết thúc phòng học.
  5. Mở lại bài giảng "Toán 10 - Bất phương trình" trong tab Kế hoạch bài giảng: Chỉ có 2 trang ban đầu, không chứa hình tròn màu đỏ vừa vẽ trong lớp.
- Hệ thống chạy mượt mà, không gặp exception hoặc crash trên cả Backend và Frontend.

---

## Risks & Decisions
- Đảm bảo khi clone không bị race condition giữa việc tạo phòng học và việc ghi đè file `lesson.json`.
