# Spec: Luồng Trang Đăng Nhập & Dashboard Lớp Học Chuẩn Xanh Giáo Dục

**Date:** 2026-10-11  
**Status:** Ready  

---

## Problem Statement
Giáo viên cần một trải nghiệm chuyên nghiệp, rõ ràng: bắt buộc đăng nhập tài khoản trước khi vào làm việc, sau đó chuyển vào Dashboard quản lý lớp học trực quan (gồm 3 tác vụ chính: Tham gia, Bắt đầu, Lên lịch và danh sách/lịch sử phòng học) tuân theo nhận diện thương hiệu màu xanh giáo dục của Học Lực.

---

## User Stories

- **[P1]** As a Teacher, I want to see a full-page Login screen when opening the application so that my session is authenticated before viewing class data.
  Accepted when: The root view displays the 50/50 split Login screen when unauthenticated; user cannot access classroom dashboards without logging in.

- **[P1]** As a Teacher, I want to log in using OTP, Google 1-Click, or the pinned Demo account (Thầy Khắc Toàn) and be navigated seamlessly to the Classroom Dashboard.
  Accepted when: Successful authentication navigates to the Classroom Dashboard within < 200ms and updates TopBar profile information.

- **[P1]** As a Teacher, I want the Classroom Dashboard to have the 3 top action cards (`+ Join`, `Begin`, `Schedule`) and 2 equal columns (`Room list` and `History`) styled in educational green (`AppColors.pine` & `AppColors.lime`).
  Accepted when: Top action row renders 3 rounded cards; bottom section renders 2 equal-width cards for Room list (with filter 'All') and History with clean educational empty-state illustrations.

- **[P1]** As a Teacher, when I click `Begin`, I want to launch the teaching space and whiteboard (`StudioScreen`) immediately.
  Accepted when: Clicking `Begin` opens `StudioScreen` with live drawing tools, webcam PIP, and Google Meet linkage.

- **[P2]** As a Teacher, when I click `+ Join`, I want a dialog to enter a Google Meet room code or link to join an existing session.
  Accepted when: A clean educational-green dialog appears allowing link input and validation.

- **[P2]** As a Teacher, when I click `Schedule`, I want a dialog to view or schedule an upcoming class session.
  Accepted when: A dialog prompts for title, subject, and time, recording it into the session state.

---

## Functional Requirements

1. **FR-01 (Màn hình Login toàn màn hình)**:
   - Xây dựng `LoginScreen` toàn màn hình tận dụng component `AuthHeroPanel` (50% trái) và Form đăng nhập (50% phải).
   - Hỗ trợ đầy đủ: Đăng nhập bằng Số điện thoại (+84 OTP), Email (OTP), Google 1-Click và Thẻ ghim Demo Thầy Khắc Toàn (`khactoan2233@gmail.com`).

2. **FR-02 (Auth Gate Điều Hướng)**:
   - Tại `CompanionApp`, dùng `ListenableBuilder` lắng nghe `GoogleMeetAuthService`:
     - Nếu `isSignedIn == false`: Hiển thị `LoginScreen`.
     - Nếu `isSignedIn == true`: Hiển thị `ClassroomDashboardScreen`.
   - Nút Đăng xuất trên Dashboard sẽ gọi `signOut()` và đưa giáo viên về lại `LoginScreen`.

3. **FR-03 (Bố cục Dashboard chuẩn Ảnh 2 với Theme Xanh Giáo Dục)**:
   - **Header TopBar**:
     - Logo `m` (Học Lực · Mộc), badge giáo viên, thông tin tên & email/sđt, nút Đăng xuất.
   - **Top Action Bar (Hàng 3 thẻ tác vụ)**:
     - Thẻ 1: `+ Tham gia (Join)` với icon dấu cộng xanh giáo dục.
     - Thẻ 2: `Bắt đầu (Begin)` với icon cuốn sách / lớp học và menu tùy chọn.
     - Thẻ 3: `Lên lịch (Schedule)` với icon lịch hẹn.
   - **Main Content (Hàng 2 cột 1:1)**:
     - Cột trái: `Danh sách phòng học (Room list)` kèm bộ lọc `Tất cả (All v)` và minh họa trống (Empty state vector + chữ "Chưa có phòng học nào").
     - Cột phải: `Lịch sử buổi học (History)` và minh họa trống (Empty state vector + chữ "Chưa có bản ghi lịch sử").

4. **FR-04 (Hệ màu Xanh Giáo Dục - Educational Palette)**:
   - Toàn bộ các icon xanh dương (từ ảnh mẫu 2) được chuẩn hóa sang:
     - `AppColors.pine` (`#062319` / `#0A4430`) cho tiêu đề, icon chính và viền active.
     - `AppColors.lime` (`#CBFF8F`) cho điểm nhấn, highlight và badge.
     - `AppColors.paper` (`#F7F8F4`) cho nền trang và thẻ card.
     - Xóa bỏ triệt để các màu xanh dương lạc điệu khỏi dashboard.

---

## Non-Functional Requirements

- **Performance**: Chuyển đổi trạng thái từ Login sang Dashboard tức thì (< 100ms), 60 FPS mượt mà.
- **Responsiveness**: Trên màn hình rộng (Desktop / Tablet ngang > 800px) giữ tỉ lệ 2 cột 1:1; trên màn hình nhỏ tự động co giãn không bị lỗi tràn viền (RenderFlex overflow).
- **Zero Breaking Changes**: Không sửa đổi hoặc phá vỡ các tính năng bảng vẽ `StudioScreen` và backend Spring Boot đang chạy.

---

## Success Criteria

- [ ] `flutter analyze lib` đạt **0 lỗi, 0 cảnh báo**.
- [ ] Toàn bộ bộ test `flutter test` đạt **21/21 tests pass 100%**.
- [ ] Mở ứng dụng lần đầu thấy trang Login toàn màn hình.
- [ ] Bấm đăng nhập (hoặc bấm 1-Click Demo Thầy Khắc Toàn) lập tức vào Dashboard chuẩn bố cục Ảnh 2 với tông màu Xanh Giáo Dục.
- [ ] Bấm `Begin` mở thẳng bảng vẽ `StudioScreen`.

---

## Out of Scope
- Tích hợp hệ thống phân quyền phức tạp (Admin, Học sinh) — tập trung phục vụ tối ưu cho Giáo viên (Teacher).
- Lưu trữ lịch sử vĩnh viễn lên Cloud bên ngoài — sử dụng bộ nhớ cục bộ / Spring Boot Docker đã cấu hình.

---

## Assumptions
- Giáo viên truy cập trạm giảng dạy trên máy tính bàn hoặc laptop qua trình duyệt Web hoặc ứng dụng Windows Desktop.
