# Phase 3: Automated Tests & Verification

**Status:** Completed  
**Covers:** All Acceptance Criteria  
**Risk:** Low  

---

## Tasks
1. Thêm widget test cho `StudioStudentsDrawer` trong `frontend/test/studio_students_drawer_test.dart`:
   - Xác minh khi `pendingAdmitCount == 0`, không hiện Card chờ duyệt.
   - Xác minh khi `pendingAdmitCount == 2`, hiện Card "Đang chờ duyệt (2 học sinh)".
   - Bấm "Cho vào tất cả" $\rightarrow$ `meetService.pendingAdmitCount` trở về 0 và Card biến mất.
2. Chạy toàn bộ test suite `flutter test` đảm bảo 100% tests pass.
