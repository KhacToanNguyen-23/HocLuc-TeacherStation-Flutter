# Spec: Classroom Session Lifecycle, Real Auth & PostgreSQL Persistence

**Date:** 2026-10-12  
**Status:** Ready  

---

## Problem Statement
Hệ thống hiện tại có 3 vấn đề lớn:
1. Khi giáo viên tạm thoát khỏi màn hình giảng dạy (Studio), hệ thống tự động xóa phòng và link Meet, khiến giáo viên không thể vào lại phòng cũ và thẻ "Phòng học" luôn ở trạng thái rỗng.
2. Còn tồn tại tài khoản giả lập (Mock demo Thầy Khắc Toàn) thay vì hệ thống tài khoản và đăng nhập thực tế lưu trong PostgreSQL.
3. Luồng đăng xuất chưa hoàn thiện việc dọn sạch ngăn xếp màn hình để đưa giáo viên về trang đăng nhập một cách triệt để.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** Là một giáo viên, tôi muốn khi bấm nút Thoát ở màn hình Studio có thể chọn **"Tạm rời phòng"** để quay về Dashboard mà phòng Meet vẫn được giữ nguyên và học sinh không bị ngắt kết nối.  
  *Accepted when:* Bấm "Tạm rời phòng", điều hướng về Dashboard, phòng vẫn ở trạng thái `ONGOING`, Google Meet không bị hủy.

- **[P1]** Là một giáo viên, tôi muốn khi có phòng đang diễn ra (`ONGOING`), thẻ **"Phòng học"** ở Dashboard sẽ hiển thị phòng đó kèm nút **"Vào lại" (Rejoin)**.  
  *Accepted when:* Thẻ Phòng học hiển thị tên phòng, link Meet, thời gian đã bắt đầu và nút "Vào lại"; bấm "Vào lại" sẽ đưa giáo viên trực tiếp vào lại Studio với đúng link Meet cũ mà không tạo mới.

- **[P1]** Là một giáo viên, tôi muốn khi tôi chủ động bấm **"Kết thúc buổi học"** thì phòng mới đóng hoàn toàn (`COMPLETED`), link Meet giải phóng và chuyển sang thẻ **"Lịch sử"**.  
  *Accepted when:* Bấm "Kết thúc buổi học", backend cập nhật `status = COMPLETED`, ghi nhận `ended_at`, thẻ Phòng học trở về trạng thái trống, thẻ Lịch sử ghi nhận buổi dạy này.

- **[P1]** Là một giáo viên, tôi muốn khi bấm nút **"Bắt đầu"** ở Dashboard, hệ thống luôn luôn 100% tạo một phòng Google Meet mới. Nếu đang có phòng cũ đang chạy, hệ thống sẽ hỏi tôi có muốn đóng phòng cũ trước khi mở phòng mới hay không.  
  *Accepted when:* Bấm "Bắt đầu" $\rightarrow$ Sinh link Meet mới 100%, ghi bản ghi mới vào database.

- **[P1]** Là một giáo viên, tôi muốn đăng nhập bằng **tài khoản thật** (Email/SĐT + Mật khẩu đã đăng ký, hoặc Google Account thật) và **loại bỏ hoàn toàn tài khoản demo/mock**.  
  *Accepted when:* Nút demo account bị gỡ bỏ; đăng nhập thành công truy vấn từ bảng `users` trong PostgreSQL hoặc token Google thật.

- **[P1]** Là một giáo viên, tôi muốn khi bấm **"Đăng xuất"** thì hệ thống xóa sạch phiên làm việc và văng ngay lập tức về trang Đăng nhập (`LoginScreen`).  
  *Accepted when:* Bấm "Đăng xuất" $\rightarrow$ Xóa token SharedPreferences, xóa sạch stack navigation, hiển thị `LoginScreen`.

- **[P1]** Là một lập trình viên/quản trị viên, tôi muốn thông tin các buổi học và người dùng được lưu trữ bền vững vào cơ sở dữ liệu **PostgreSQL** trong Docker (`hocluc_postgres`).  
  *Accepted when:* Bảng `classrooms` và `users` được quản lý trong PostgreSQL, API Spring Boot đọc/ghi trực tiếp vào PostgreSQL.

---

## Functional Requirements

1. **FR-01 (Database Schema & Persistence):**
   - Bảng `users`: `id`, `name`, `email`, `phone`, `password_hash`, `role`, `avatar_url`, `created_at`.
   - Bảng `classrooms`: `id`, `teacher_id` (FK `users.id`), `title`, `meeting_url`, `status` (`ONGOING`, `COMPLETED`), `started_at`, `ended_at`, `duration_minutes`, `created_at`.
2. **FR-02 (Backend APIs):** Cập nhật `ClassroomController` và `AuthController`:
   - `POST /api/auth/login`: Xác thực tài khoản thật từ PostgreSQL (bỏ mock).
   - `POST /api/auth/register`: Đăng ký tài khoản mới kèm băm mật khẩu.
   - `POST /api/classroom/create`: Tạo phòng mới (status `ONGOING`, lưu vào Postgres).
   - `GET /api/classroom/active`: Lấy phòng đang `ONGOING` của giáo viên.
   - `POST /api/classroom/{id}/end`: Kết thúc buổi học (`status = COMPLETED`, set `ended_at`, tính `duration_minutes`).
   - `GET /api/classroom/history`: Lấy danh sách các phòng `COMPLETED`.
3. **FR-03 (Removal of Mock Accounts):**
   - Gỡ bỏ `_handleDemoQuickLogin` và UI nút bấm demo tại `auth_form_card.dart`.
   - Gỡ bỏ endpoint `loginDemoAccount` trong backend `AuthService.java` và `local_service.dart`.
4. **FR-04 (Studio Exit Dialog UI):**
   - Khi bấm Thoát tại Studio: Popup 2 nút "Tạm rời phòng" (giữ link, về dashboard) và "Kết thúc buổi học" (đóng link, cập nhật DB `COMPLETED`).
5. **FR-05 (Dashboard Room Card & Rejoin UI):**
   - Nếu có phòng `ONGOING`: Thẻ "Phòng học" hiển thị thông tin buổi học kèm badge "Đang phát sóng" và nút **"Vào lại"**.
   - Bấm "Vào lại" $\rightarrow$ Vào thẳng Studio với link Meet cũ.
6. **FR-06 (Logout Navigation):**
   - Bấm "Đăng xuất" tại Avatar Menu $\rightarrow$ `_authService.signOut()`, `Navigator.pushAndRemoveUntil(..., LoginScreen, false)`.

---

## Non-Functional Requirements

- **Bảo mật:** Mật khẩu giáo viên lưu trong PostgreSQL phải được băm an toàn (BCrypt / SHA-256 with salt).
- **Graceful Fallback:** Khi Docker chưa bật, backend Spring Boot log cảnh báo rõ ràng thay vì làm crash Flutter app.
- **Data Integrity:** Chỉ duy nhất 1 phòng `ONGOING` cho mỗi giáo viên tại 1 thời điểm.

---

## Success Criteria

- [ ] Không còn bất kỳ nút hoặc logic nào liên quan đến Demo Account Thầy Khắc Toàn trên UI.
- [ ] Đăng nhập tài khoản thật thành công và lưu thông tin vào PostgreSQL.
- [ ] Thoát phòng bằng "Tạm rời phòng", về Dashboard thấy thẻ "Phòng học" có nút "Vào lại". Bấm "Vào lại" quay lại đúng phòng Meet cũ.
- [ ] Bấm "Kết thúc buổi học", phòng đóng hẳn và chuyển vào thẻ "Lịch sử".
- [ ] Bấm "Đăng xuất", ứng dụng dọn sạch token và lập tức văng ra màn hình `LoginScreen`.
