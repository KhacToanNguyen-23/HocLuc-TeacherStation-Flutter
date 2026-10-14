# Phase 03 — Dashboard Planning Tab

**Phase ID:** `phase-03-dashboard-planning-tab`  
**Priority:** P1  
**Status:** not_started  

---

## Objective
Tái cấu trúc khu vực nội dung bên dưới của `ClassroomDashboardScreen` thành hệ thống 3 tab ngang rõ ràng: `[Phòng học] - [Kế hoạch bài giảng] - [Lịch sử]`, đồng thời xây dựng giao diện hiển thị danh sách kế hoạch bài giảng với trải nghiệm cao cấp.

---

## Scope & Implementation Tasks
1. **Thiết kế Thanh 3 Tab ngang trên Dashboard:**
   - Tạo bộ chọn tab trực quan tại khu vực nội dung dưới:
     - Tab 1: **Phòng học** (`_buildRoomListCard`)
     - Tab 2: **Kế hoạch bài giảng** (`_buildPlanningListCard`)
     - Tab 3: **Lịch sử** (`_buildHistoryCard`)
   - Hiệu ứng chuyển tab mượt mà, lưu giữ vị trí tab hiện tại trong state của màn hình.
2. **Xây dựng Widget `PlanningListCard` (`frontend/lib/widgets/dashboard/planning_list_card.dart`):**
   - Header của Card: Tiêu đề "Kế hoạch bài giảng", bộ lọc môn học (Tất cả, Toán, Văn, Anh...), và nút bấm nổi bật "+ Soạn bài mới" (mở dialog nhập tên bài & tạo bản planning mới).
   - **Trạng thái Trống (Empty State):** Khi chưa có bài planning nào, hiển thị minh họa trực quan `DashboardEmptyCard` hoặc custom illustration kèm nút "Tạo kế hoạch bài giảng".
   - **Danh sách Bài giảng (Grid/List View):**
     - Hiển thị từng thẻ bài giảng: Tên bài, môn học, số trang đã soạn, thời gian cập nhật gần nhất.
     - Nút hành động nhanh trên mỗi thẻ:
       - **Soạn tiếp (Chỉnh sửa):** Mở `StudioScreen` ở chế độ Planning.
       - **Dạy ngay (Tạo phòng):** Kích hoạt quy trình clone bài giảng và mở phòng học trực tiếp.
       - **Xóa:** Hiển thị popup xác nhận xóa bản planning.
3. **Tích hợp State & API trong Dashboard:**
   - Tự động gọi `_loadPlannings()` khi người dùng chuyển sang tab "Kế hoạch bài giảng" hoặc sau khi soạn bài trở về.

---

## Files & Modules Affected
- `frontend/lib/screens/classroom_dashboard_screen.dart` (chỉnh sửa layout 3 tab và gắn logic)
- `frontend/lib/widgets/dashboard/planning_list_card.dart` (mới)

---

## Dependencies
- Phụ thuộc: `phase-02-frontend-service-and-models` (cần API client `LocalService`).

---

## Tests & Acceptance Criteria
- Người dùng có thể nhấn chuyển đổi qua lại giữa 3 tab `[Phòng học]`, `[Kế hoạch bài giảng]`, `[Lịch sử]` mà không bị lỗi giao diện hoặc mất dữ liệu.
- Tab "Kế hoạch bài giảng" hiển thị chính xác empty state khi chưa có bài, và hiển thị danh sách khi đã có dữ liệu.
- Bấm "+ Soạn bài mới" mở ra dialog nhập tên bài giảng và điều hướng vào màn hình Studio.

---

## Risks & Decisions
- Đảm bảo layout co giãn responsive tốt ở các độ phân giải màn hình từ compact (800px) đến wide desktop (>1200px).
