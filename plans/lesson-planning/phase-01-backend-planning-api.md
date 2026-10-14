# Phase 01 — Backend Planning API

**Phase ID:** `phase-01-backend-planning-api`  
**Priority:** P1  
**Status:** not_started  

---

## Objective
Xây dựng Model, Service, và REST Controller quản lý kế hoạch bài giảng (Planning) ở backend Java Spring Boot, hỗ trợ lưu trữ tệp JSON an toàn và phục vụ các thao tác CRUD cùng thao tác Clone sang phòng học trực tiếp.

---

## Scope & Implementation Tasks
1. **Tạo Model `Planning`:**
   - Trường dữ liệu: `id`, `title`, `subject`, `pageCount`, `createdAt`, `updatedAt`, `teacherId`.
   - Chứa metadata tóm tắt để hiển thị trên danh sách.
2. **Tạo `PlanningService`:**
   - Đảm bảo thư mục lưu trữ `data/plannings/` được tự động tạo (`Files.createDirectories(...)`) nếu chưa tồn tại.
   - Quản lý danh mục kế hoạch lưu tại `data/plannings.json`.
   - Quản lý nội dung chi tiết bài giảng tại thư mục `data/plannings/{id}.json`.
   - Các phương thức:
     - `List<Planning> getAllPlannings()`
     - `JsonObject getPlanningContent(String id)`
     - `Planning saveOrUpdatePlanning(String id, String title, String subject, JsonObject content)`
     - `boolean deletePlanning(String id)`
     - `boolean cloneToClassroom(String planningId)`: Sao chép nội dung từ `data/plannings/{id}.json` sang `data/lesson.json` của active classroom.
3. **Tạo `PlanningController` (`/api/plannings`):**
   - `GET /api/plannings`: Trả về danh sách metadata.
   - `GET /api/plannings/{id}`: Trả về nội dung JSON bài giảng.
   - `POST /api/plannings`: Tạo mới bản planning.
   - `PUT /api/plannings/{id}`: Cập nhật bản planning.
   - `DELETE /api/plannings/{id}`: Xóa bản planning.
   - `POST /api/plannings/{id}/clone-to-classroom`: Clone sang phòng học.

---

## Files & Modules Affected
- `backend/api/src/main/java/vn/teaching/model/Planning.java` (mới)
- `backend/api/src/main/java/vn/teaching/service/PlanningService.java` (mới)
- `backend/api/src/main/java/vn/teaching/controller/PlanningController.java` (mới)

---

## Dependencies
- Không phụ thuộc phase nào trước đó.

---

## Tests & Acceptance Criteria
- `GET /api/plannings` trả về danh sách JSON (mã 200).
- `POST /api/plannings` tạo mới bản planning và lưu thành công cả metadata lẫn nội dung `data/plannings/{id}.json`.
- `POST /api/plannings/{id}/clone-to-classroom` sao chép chính xác nội dung sang `data/lesson.json`.
- Backend build thành công không lỗi cú pháp: `mvn test-compile`.

---

## Risks & Decisions
- Cần đồng bộ khóa tệp (fileLock) tương tự `StorageService` và `ClassroomService` để tránh xung đột ghi đĩa khi nhiều thao tác diễn ra đồng thời.
