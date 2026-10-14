# Phase 02 — Frontend Service and Models

**Phase ID:** `phase-02-frontend-service-and-models`  
**Priority:** P1  
**Status:** not_started  

---

## Objective
Xây dựng Data Model `PlanningMeta` và mở rộng `LocalService` trong Flutter để thực hiện các cuộc gọi API quản lý Planning tới Backend Java.

---

## Scope & Implementation Tasks
1. **Tạo Data Model `PlanningMeta` (`frontend/lib/models/planning_meta.dart`):**
   - Trường dữ liệu: `id`, `title`, `subject`, `pageCount`, `createdAt`, `updatedAt`.
   - Các phương thức helper: `fromJson`, `toJson`, định dạng ngày tạo/cập nhật hiển thị thân thiện với người dùng (ví dụ: "10:15 - 14/10/2026").
2. **Mở rộng `LocalService` (`frontend/lib/services/local_service.dart`):**
   - `Future<List<PlanningMeta>> getPlannings()`: Gọi `GET /api/plannings`.
   - `Future<Map<String, dynamic>> getPlanningContent(String id)`: Gọi `GET /api/plannings/{id}`.
   - `Future<PlanningMeta> createPlanning({required String title, required String subject, required Map<String, dynamic> content})`: Gọi `POST /api/plannings`.
   - `Future<bool> updatePlanning({required String id, String? title, String? subject, Map<String, dynamic>? content})`: Gọi `PUT /api/plannings/{id}`.
   - `Future<bool> deletePlanning(String id)`: Gọi `DELETE /api/plannings/{id}`.
   - `Future<bool> clonePlanningToClassroom(String id)`: Gọi `POST /api/plannings/{id}/clone-to-classroom`.

---

## Files & Modules Affected
- `frontend/lib/models/planning_meta.dart` (mới)
- `frontend/lib/services/local_service.dart` (chỉnh sửa bổ sung methods)

---

## Dependencies
- Phụ thuộc: `phase-01-backend-planning-api` (API backend sẵn sàng).

---

## Tests & Acceptance Criteria
- Unit test hoặc integration test `LocalService`:
  - `getPlannings()` phân tích mảng JSON thành `List<PlanningMeta>` an toàn, không ném exception khi mảng rỗng.
  - Các hàm POST/PUT gửi đúng token `X-Companion-Token` và headers cần thiết.
- `flutter analyze` vượt qua không có lint error mới.

---

## Risks & Decisions
- Đảm bảo xử lý timeout và fallback gracefully khi backend Java chưa khởi động xong.
