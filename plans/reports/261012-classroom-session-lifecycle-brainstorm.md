# Brainstorm: Classroom Session Lifecycle, Real Auth & PostgreSQL Persistence

**Date:** 2026-10-12  
**Slug:** classroom-session-lifecycle  

## Ideas Explored

1. **Option A: Auto-generate new room on re-entry (Stateless)**
   - Mỗi lần vào là sinh link mới 100%, bỏ qua phòng cũ.
   - *Đánh giá:* Bị loại vì khi giáo viên rớt mạng hoặc tạm thoát, học sinh trong phòng Meet cũ bị bơ vơ và giáo viên mất host.

2. **Option B: Multi-session parallel rooms (Nhiều phòng song song)**
   - Giáo viên mở cùng lúc 2-3 phòng học khác nhau.
   - *Đánh giá:* Bị loại vì không phù hợp với ôn thi trực tiếp, gây hao tốn tài nguyên và dễ nhầm lẫn link.

3. **Option C: Single Active Session, Real Auth & PostgreSQL Persistence (Được chọn)**
   - Mỗi giáo viên tại một thời điểm chỉ có tối đa **1 phòng đang diễn ra (`ONGOING`)**.
   - Khi thoát phòng ở Studio:
     - **Tạm rời phòng**: Quay về Dashboard, phòng vẫn `ONGOING`, thẻ "Phòng học" hiển thị nút **"Vào lại" (Rejoin)**.
     - **Kết thúc buổi học**: Tự tay bấm thì phòng mới đóng (`COMPLETED`), link Meet giải phóng, chuyển sang thẻ "Lịch sử".
   - Nút **"Bắt đầu"**: Luôn sinh 100% link mới (nhắc nhở nếu đang có phòng cũ chưa đóng).
   - **Xóa bỏ hoàn toàn Mock Account**: Bỏ nút đăng nhập demo Thầy Khắc Toàn; chỉ dùng đăng nhập thật (Email/SĐT + Password hoặc Google thật qua WebView) lưu vào PostgreSQL.
   - **Đăng xuất triệt để**: Bấm "Đăng xuất" xóa sạch token và văng thẳng về màn hình `LoginScreen`.

## User's Direction
- Giáo viên phải **tự tay bấm "Kết thúc buổi học"** thì link phòng mới đóng.
- Thẻ "Phòng học" ở Dashboard hiển thị phòng đang diễn ra để giáo viên bấm vào lại.
- Bấm nút "Bắt đầu" ở Dashboard là luôn luôn 100% tạo phòng mới.
- Lưu trữ dữ liệu lâu dài vào cơ sở dữ liệu **PostgreSQL** trong Docker.
- **Bỏ hết các tài khoản mock data**, chỉ cho phép đăng nhập thật.
- Khi **Đăng xuất** thì xóa sạch stack màn hình và lập tức văng ra trang Login.

## Open Questions & Technical Requirements
1. Khởi chạy PostgreSQL trong Docker và bổ sung bảng `classrooms`, cập nhật bảng `users` hỗ trợ `password_hash`.
2. Cập nhật Spring Boot (`backend/api`): Thêm Spring Data JPA kết nối PostgreSQL `hocluc_dev` và các API quản lý vòng đời buổi học.
3. Gỡ bỏ `_handleDemoQuickLogin` trong Flutter và xóa các API mock demo trong backend.
4. Cập nhật giao diện thẻ "Phòng học" (`_buildRoomListCard`) ở Dashboard hỗ trợ Rejoin.
5. Cập nhật Dialog thoát phòng tại Studio với 2 nút: "Tạm rời phòng" vs "Kết thúc buổi học".
6. Hoàn thiện điều hướng đăng xuất đẩy về `LoginScreen`.
