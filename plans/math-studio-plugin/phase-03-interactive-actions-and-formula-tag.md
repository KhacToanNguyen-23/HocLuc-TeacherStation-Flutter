# Phase 3: Tương tác 2 Chiều: Phát quay tức thì, Nhân bản & Sửa nhanh Công thức

**Goal:** Hiện thực hóa các hành vi tương tác sư phạm tức thì từ thanh Floating Context Bar và nhãn công thức toán học trực tiếp trên bảng.

---

## Detailed Tasks

1. **Nhãn công thức toán học tương tác (Formula Tag):**
   - Đặt ở góc trên bên trái bên trong Bounding Box (`y = 1.5 + sin(x)`).
   - Nhấp vào nhãn công thức: Cho phép gõ trực tiếp chuỗi hàm mới ngay trên bảng (Inline TextField).
   - Nhấn Enter: Hệ thống kích hoạt tính toán lại đồ thị và cập nhật hình vẽ ngay lập tức.

2. **Hành động nút `[ ⟳ Phát quay ]`:**
   - Khi bấm: Trạng thái đối tượng chuyển `isRevolved = !isRevolved`.
   - Gọi hàm sinh SVG khối tròn xoay 2.5D, tạo chuyển động quay biến hình phẳng thành chiếc bình 3D sinh động chuẩn SGK.

3. **Hành động nút `[ ⧉ Nhân bản ]`:**
   - Tạo bản sao `BoardSticker` mới với độ dời tọa độ (offset dx: 30px, dy: 30px) trên trang bảng hiện tại.

4. **Đảm bảo tính trung lập kiến trúc (Zero Hardcoded Invariants):**
   - Mọi hành vi mở rộng của sticker được xử lý thông qua cơ chế Generic Action của Host Bridge và StudioState, tuyệt đối không hardcode ID plugin hay tên môn học vào `frontend/lib/`.

