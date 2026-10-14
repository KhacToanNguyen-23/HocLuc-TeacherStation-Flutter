# Phase 2: In-Drawer Waiting Room Card & Actions

**Status:** Completed  
**Covers:** [P1] In-Drawer Waiting Room, Auto-Admit Switch  
**Risk:** Normal  

---

## Context
Người dùng mong muốn có chỗ duyệt trực quan ngay trong Drawer "Người tham gia" (bảng bên phải màn hình Studio).

## Tasks
1. Trong `frontend/lib/widgets/studio/studio_students_drawer.dart`:
   - Lắng nghe `widget.meetService.pendingAdmitCount`.
   - Nếu `pendingAdmitCount > 0`:
     - Hiển thị Card nổi bật ở đầu danh sách (dưới hàng Host):
       - Container viền màu cam / vàng (Amber) bo tròn.
       - Icon `Icons.person_add_alt_1_rounded`.
       - Text: `Đang chờ duyệt ($pendingCount học sinh)` với subtitle `Bấm để cho học sinh vào lớp`.
       - Nút ElevatedButton `Cho vào tất cả` gọi `widget.meetService.admitAllPending()`.
       - Switch `Tự động duyệt` đồng bộ với `widget.meetService.autoAdmitEnabled`.
2. Đảm bảo layout co giãn mượt mà, không bị tràn màn hình (overflow) trên mọi kích thước.
