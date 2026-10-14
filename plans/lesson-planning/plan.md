# Plan: Lesson Planning & Classroom Launch

**Slug:** lesson-planning  
**Mode:** Hard  
**Risk:** normal — multi-file backend CRUD + Flutter dashboard tab & studio planning mode  
**Date:** 2026-10-14  
**Status:** Completed  

---

## Overview
Cung cấp cho giáo viên công cụ chuẩn bị bài giảng trước (Lesson Planning) trên chính bảng trắng Teaching Studio quen thuộc. Toàn bộ kế hoạch được quản lý trong tab "Kế hoạch bài giảng" mới trên Dashboard. Khi sẵn sàng dạy, giáo viên có thể nhân bản (clone) bài giảng này thành phòng học trực tiếp mà không làm ảnh hưởng đến bản kế hoạch gốc.

---

## Phases Overview

| Phase | File | Objective | Priority | Stories Covered |
|---|---|---|---|---|
| **01** | `phase-01-backend-planning-api.md` | Xây dựng Model, Service, và REST Controller quản lý Planning ở backend Java Spring Boot | P1 | FR-04, FR-05 (Backend) |
| **02** | `phase-02-frontend-service-and-models.md` | Xây dựng Model Planning và mở rộng `LocalService` trong Flutter để kết nối API Planning | P1 | FR-04 (Client), FR-05 |
| **03** | `phase-03-dashboard-planning-tab.md` | Chuyển đổi Dashboard sang hệ thống 3 tab ngang (`Phòng học`, `Kế hoạch bài giảng`, `Lịch sử`) và xây dựng danh sách Planning | P1, P2 | FR-01, FR-02 |
| **04** | `phase-04-studio-planning-mode.md` | Tích hợp chế độ `isPlanningMode: true` vào `StudioScreen` và `StudioTopBar`, bổ sung nút "Lưu & Thoát" và "Tạo phòng học" | P1 | FR-03 |
| **05** | `phase-05-e2e-integration-and-clone.md` | Hoàn thiện luồng nhân bản (Clone) từ Planning sang Live Classroom, kiểm tra toàn vẹn dữ liệu và kiểm thử tổng thể | P1 | FR-05, All Acceptance Criteria |

### Checklist
- [x] Phase 01: Backend Planning API (`phase-01-backend-planning-api.md`)
- [x] Phase 02: Frontend Service and Models (`phase-02-frontend-service-and-models.md`)
- [x] Phase 03: Dashboard Planning Tab (`phase-03-dashboard-planning-tab.md`)
- [x] Phase 04: Studio Planning Mode (`phase-04-studio-planning-mode.md`)
- [x] Phase 05: E2E Integration and Clone (`phase-05-e2e-integration-and-clone.md`)

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-14 11:00
**Phase in progress:** None (All phases completed)
**Status:** Feature implemented and all tests passing (flutter test 96/96 passed, mvn test 7/7 passed, flutter analyze 0 issues)

### Decisions made this session
- Cập nhật `StudioTopBar` khi ở chế độ planning: ẩn Meet URL bar thay bằng badge "Kế hoạch bài giảng", ẩn nút đỏ "Rời phòng", bổ sung nút "Thoát" và nút nổi bật "Tạo phòng học".
- Nâng cấp `StudioScreen`: hỗ trợ nạp bài giảng cũ, lưu trực tiếp vào API Planning, cảnh báo chưa lưu với `PopScope` và nút "Tạo phòng học" trực tiếp từ giao diện bảng.
- Xây dựng unit và widget tests chuyên biệt trong `test/lesson_planning_test.dart` kiểm tra serialization, planning card, empty state và top bar controls.
- Toàn bộ 96 bài test Flutter và 7 bài test backend Maven đều pass 100%.

### Next immediate action
Finalize feature, conduct spec coverage review and prepare git commit.

---

## File Ownership Matrix

- `backend/api/src/main/java/vn/teaching/model/Planning.java` (Phase 01)
- `backend/api/src/main/java/vn/teaching/service/PlanningService.java` (Phase 01)
- `backend/api/src/main/java/vn/teaching/controller/PlanningController.java` (Phase 01)
- `frontend/lib/models/planning_meta.dart` (Phase 02)
- `frontend/lib/services/local_service.dart` (Phase 02)
- `frontend/lib/screens/classroom_dashboard_screen.dart` (Phase 03)
- `frontend/lib/widgets/dashboard/planning_list_card.dart` (Phase 03)
- `frontend/lib/screens/studio_screen.dart` (Phase 04, 05)
- `frontend/lib/widgets/studio/studio_top_bar.dart` (Phase 04)
- `frontend/lib/models/studio_state.dart` (Phase 04)

---

## Verification Strategy
- **Backend:** Kiểm thử biên dịch `mvn clean compile` và xác nhận các API CRUD qua HTTP client.
- **Frontend Flutter:** `flutter analyze` không có cảnh báo/lỗi mới.
- **Tính toàn vẹn (Clone Isolation):** Kiểm tra snapshot gốc của planning không bị biến đổi khi có nét vẽ phát sinh trong phòng học live.
