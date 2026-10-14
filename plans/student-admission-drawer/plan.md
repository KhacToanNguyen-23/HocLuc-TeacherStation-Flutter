# Plan: In-Drawer Waiting Room & DOM Knock Detection Fix

**Date:** 2026-10-14  
**Mode:** --fast  
**Risk:** normal — Multi-file UI and DOM script adjustments, no schema changes, fully testable.  
**Spec:** [plans/student-admission-drawer/spec.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/student-admission-drawer/spec.md)  

---

## Architecture Overview
1. **Bridge DOM Scanner Optimization (`meet_bridge_script.dart`):**
   - Loại bỏ hoàn toàn điều kiện lọc `b.offsetParent === null` đối với các nút duyệt vì popup duyệt của Google Meet dùng `position: fixed` (vốn có `offsetParent === null` theo chuẩn W3C).
   - Mở rộng selector tìm nút duyệt sang `button, [role="button"], [jsaction*="admit" i]`.
   - Quét cả văn bản chứa trong các thẻ thông báo cha (`div[role="alert"], div[role="status"], div[jsname]`) để trích xuất tên học sinh đang chờ nếu có.
2. **In-Drawer Waiting Room UI (`studio_students_drawer.dart`):**
   - Khi `meetService.pendingAdmitCount > 0`, hiển thị một Card nổi bật màu vàng hổ phách/cam (Amber) ngay dưới hàng của Chủ phòng (Giáo viên).
   - Card hiển thị:
     - Biểu tượng `Icons.person_add_alt_1_rounded`.
     - Tiêu đề: "Đang chờ duyệt ($count học sinh)".
     - Nút "Cho vào tất cả" (nền xanh, chữ trắng) kích hoạt `meetService.admitAllPending()`.
     - Switch nhỏ hoặc toggle "Tự động duyệt học sinh" để giáo viên rảnh tay giảng bài.
3. **Đồng bộ hóa Trạng thái & Kiểm thử tự động:**
   - Đảm bảo khi bấm "Cho vào tất cả" ở Drawer hay Banner, `lastAdmitCount` và `pendingAdmitCount` lập tức trở về 0, UI cập nhật tức thì.
   - Thêm widget test cho `StudioStudentsDrawer` khi có học sinh chờ duyệt.

---

## Phase Breakdown

- [x] **Phase 1: Fix Bridge DOM Scanner & Remove `offsetParent` Restriction**  
  *Covers: [P1] DOM Knock Detection, Fixed Position Toast Recognition*  
  Sửa `meet_bridge_script.dart` để không lọc bỏ phần tử `offsetParent === null`, mở rộng selector tìm nút duyệt và phương thức `admitAll()`.

- [x] **Phase 2: In-Drawer Waiting Room Card & Actions**  
  *Covers: [P1] In-Drawer Waiting Room, Auto-Admit Switch*  
  Thêm card "Đang chờ duyệt" vào [studio_students_drawer.dart](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/widgets/studio/studio_students_drawer.dart) với nút "Cho vào tất cả" và switch tự động duyệt.

- [x] **Phase 3: Automated Tests & Verification**  
  *Covers: All Acceptance Criteria*  
  Chạy `flutter test`, kiểm tra widget tests cho cả Banner và Drawer khi có `pendingAdmitCount > 0`.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-14 13:22  
**Phase in progress:** Completed Phase 3  
**Status:** All 3 phases completed, 113 unit & widget tests passed with 0 failures.  

### Decisions made this session
- Gỡ bỏ `offsetParent === null` trong [meet_bridge_script.dart](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/services/meet_bridge_script.dart) vì popup duyệt của Google Meet dùng `position: fixed` (luôn có `offsetParent === null` theo chuẩn W3C).
- Mở rộng selector tìm nút duyệt `button, [role="button"], [jsaction*="admit" i]` và thêm nhận diện câu thông báo `muốn tham gia cuộc gọi này` / `wants to join this call`.
- Tích hợp Card Waiting Room nổi bật màu vàng hổ phách (Amber) ngay dưới hàng Chủ phòng trong [studio_students_drawer.dart](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/widgets/studio/studio_students_drawer.dart) với nút **"Cho vào tất cả"** và Switch **"Tự động duyệt học sinh"**.
- Viết test [studio_students_drawer_test.dart](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/test/studio_students_drawer_test.dart) kiểm thử toàn diện hành vi Drawer.
- Toàn bộ 113 tests pass 100%.

### Next immediate action
- Sẵn sàng bàn giao cho giáo viên chạy thử nghiệm thực tế.
