# Brainstorm: Luồng Trang Đăng Nhập & Dashboard Lớp Học Chuẩn Xanh Giáo Dục

**Date:** 2026-10-11  
**Author:** Pair Programming Antigravity & User  
**Status:** Completed Exploration  

---

## 1. Bối cảnh & Thách thức
Hiện tại, khi mở ứng dụng Teacher Station, màn hình ban đầu hiển thị Lobby với ô tạo lớp học trực tiếp, việc đăng nhập chỉ là modal tùy chọn qua nút ở TopBar.
Người dùng yêu cầu tái cấu trúc luồng trải nghiệm:
1. **Trang Đăng nhập chuyên biệt (Dedicated Full-Page Auth)**:
   - Truy cập vào ứng dụng sẽ xuất hiện trang Đăng nhập trước (bố cục 50/50 Split phong cách Flat hiện tại nhưng toàn màn hình).
   - Chỉ sau khi đăng nhập thành công (qua OTP Điện thoại, Email, Google 1-Click hoặc nút Ghim Demo Thầy Khắc Toàn), người dùng mới được điều hướng vào **Dashboard Lớp học**.
2. **Dashboard Lớp học chuẩn bố cục Ảnh 2**:
   - Thanh điều khiển trên cùng (Top Action Bar) với 3 thẻ tác vụ lớn:
     - `+ Tham gia (Join)`: Nhập mã phòng hoặc link Google Meet để vào lớp.
     - `Bắt đầu (Begin)`: Khởi tạo phòng học trực tuyến và mở bảng vẽ StudioScreen tức thì.
     - `Lên lịch (Schedule)`: Đặt lịch hẹn buổi học sắp diễn ra.
   - Bố cục 2 cột bên dưới:
     - Cột trái: `Danh sách phòng học (Room list)` kèm bộ lọc `Tất cả (All)`, minh họa trống khi chưa có phòng.
     - Cột phải: `Lịch sử buổi học (History)`, minh họa trống khi chưa có lịch sử.
3. **Quy chuẩn thiết kế (Design Rule)**:
   - Tuân thủ nghiêm ngặt **Màu xanh giáo dục (Educational Green Theme)**:
     - Màu chủ đạo: Xanh thông đậm (`AppColors.pine #062319` và `#0A4430`).
     - Màu điểm nhấn / Badge: Xanh mạ non (`AppColors.lime #CBFF8F`).
     - Màu nền & Card: Giấy ấm (`AppColors.paper #F7F8F4`), viền xám sáng (`#E1E5DB`).
     - Chuyển đổi toàn bộ các icon/nút bấm màu xanh dương của mẫu gốc sang màu xanh giáo dục của Học Lực.

---

## 2. Các hướng tiếp cận đã thảo luận (Ideas Explored)

### Hướng A: Modal Auth Guard trên nền Dashboard mờ
- Giữ nguyên LobbyScreen cũ, khi chưa đăng nhập thì làm mờ nền và mở bắt buộc FlatAuthModal.
- *Đánh giá*: Không tạo cảm giác phân định rõ ràng giữa giai đoạn xác thực và giai đoạn làm việc trong lớp học. (Đã loại bỏ).

### Hướng B (Lựa chọn chính thức): Two-Screen Architecture (AuthScreen -> ClassroomDashboardScreen)
- **Màn hình 1 - `LoginScreen` (Full-page Split 50/50)**:
  - Tận dụng `AuthHeroPanel` bên trái và Form đăng nhập bên phải (OTP, Google, Pinned Demo Khắc Toàn).
  - Có Auth Guard: Nếu đã đăng nhập sẵn thì tự động chuyển thẳng vào Dashboard.
- **Màn hình 2 - `ClassroomDashboardScreen` (Ảnh 2 với theme Xanh Giáo Dục)**:
  - TopBar: Logo Mộc, Tên giáo viên, Avatar/Email và nút Đăng xuất.
  - Hàng trên: 3 Action Cards bo tròn viền xanh giáo dục (`Join`, `Begin`, `Schedule`).
  - Hàng dưới: 2 cột chia tỉ lệ 1:1 (`Room list` và `History`).
  - Action `Begin`: Kích hoạt `StudioScreen` (Bảng vẽ 16:9 + webcam PIP + PDF).

---

## 3. Kiến trúc Luồng Dữ liệu (State & Navigation)
- Quản lý phiên đăng nhập: `GoogleMeetAuthService` đóng vai trò Auth State Provider.
  - Khi `isSignedIn == false`: Root App hiển thị `LoginScreen`.
  - Khi `isSignedIn == true`: Root App hiển thị `ClassroomDashboardScreen`.
  - Bấm `Đăng xuất` trên Dashboard -> Trở về `LoginScreen`.
- Backend Spring Boot: Đã sẵn sàng các endpoint `/api/auth/otp/send`, `/api/auth/otp/verify`, `/api/auth/demo` và seed PostgreSQL Docker.

---

## 4. Các câu hỏi mở & Giảm thiểu rủi ro
1. **Rủi ro chuyển trang bị giật lag**: 
   - Giải pháp: Chuyển trang mượt mà qua Material Page Route hoặc ListenableBuilder gắn liền với `GoogleMeetAuthService.isSignedIn`.
2. **Khả năng tương thích Responsive**:
   - Trên desktop/tablet rộng: 2 cột 1:1 theo đúng Ảnh 2.
   - Trên màn hình hẹp (< 768px): Tự động xếp chồng dọc để tránh tràn viền (overflow).
