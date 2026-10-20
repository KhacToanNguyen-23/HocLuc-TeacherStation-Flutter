# Phase 01: Dead Code Cleanup & Directory Scaffolding

**Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-clean-architecture-and-plugin-cleanup/plan.md)  
**Status:** Completed  
**Target Directories & Files:**
- `frontend/lib/core/`
- `frontend/lib/features/auth/`
- `frontend/lib/features/classroom_meet/`
- `frontend/lib/features/studio_board/`
- `frontend/lib/features/plugin_engine/`
- `frontend/lib/features/exams/`

---

## 1. Mục Tiêu & Yêu Cầu

1. Xóa các file dead code tồn dư không còn sử dụng:
   - `frontend/lib/services/sidecar_manager.dart`
   - `frontend/lib/services/sidecar_manager_native.dart`
   - `frontend/lib/services/sidecar_manager_web.dart`
   *(Toàn bộ tính năng sidecar đã được chuyển giao hoàn chỉnh cho `process_supervisor.dart`).*
2. Kiểm tra `frontend/pubspec.yaml` để đảm bảo sạch sẽ dependencies.
3. Thiết lập sẵn khung thư mục chuẩn Clean Architecture:
   - `frontend/lib/core/platform/`
   - `frontend/lib/core/network/`
   - `frontend/lib/core/ui/`
   - `frontend/lib/features/auth/presentation/`
   - `frontend/lib/features/auth/services/`
   - `frontend/lib/features/classroom_meet/presentation/`
   - `frontend/lib/features/classroom_meet/services/`
   - `frontend/lib/features/studio_board/presentation/`
   - `frontend/lib/features/studio_board/services/`
   - `frontend/lib/features/plugin_engine/presentation/`
   - `frontend/lib/features/plugin_engine/services/`
   - `frontend/lib/features/exams/presentation/`
   - `frontend/lib/features/exams/services/`

---

## 2. Tiêu Chí Nghiệm Thu

- File dead code bị xóa bỏ hoàn toàn.
- `flutter analyze` không báo lỗi missing import do xóa dead code.
- Cây thư mục Clean Architecture sẵn sàng cho Phase 02.

