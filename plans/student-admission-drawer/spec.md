# Spec: Student Admission in Studio Students Drawer & Canvas Banner

**Date:** 2026-10-14  
**Status:** Draft  
**Approach:** In-Drawer Waiting Room & Responsive Canvas Banner (Hướng 1)

---

## 1. Problem Statement
Giáo viên đang trong phòng Google Meet thật với vai trò Chủ phòng (`khactoan2233@gmail.com`). Khi học sinh bấm link Meet xin vào phòng, Google Meet hiển thị popup thông báo có người đang chờ duyệt, nhưng Teacher Station chưa hiển thị khu vực duyệt do:
1. `meet_bridge_script.dart` lọc bỏ phần tử có `offsetParent === null` (popup Google Meet có thuộc tính CSS `position: fixed` nên `offsetParent` luôn là `null`).
2. Drawer "Người tham gia" (`StudioStudentsDrawer`) chưa có mục "Đang chờ duyệt" (Waiting Room).

---

## 2. User Stories & Acceptance Criteria

### User Story 1 (P1): Nhận diện yêu cầu xin vào phòng không bị lọc bởi `offsetParent`
- **As a** giáo viên giảng dạy trên Teacher Station,
- **I want** hệ thống phát hiện chính xác khi có học sinh gõ cửa xin vào phòng Google Meet,
- **So that** sự kiện `ADMIT_REQUEST` được gửi về Flutter với `pendingCount > 0`.
- **Acceptance Criteria:**
  - `meet_bridge_script.dart` quét cả `<button>` và `<div role="button">`, `<span role="button">`.
  - Không lọc theo `offsetParent !== null` đối với các phần tử nổi `position: fixed`.
  - Khớp các từ khóa tiếng Việt và tiếng Anh: `cho phép`, `chấp nhận`, `cho vào`, `admit`, `allow`.

### User Story 2 (P1): Khu vực "Đang chờ duyệt" trong Drawer Người tham gia
- **As a** giáo viên mở bảng danh sách học sinh bên phải,
- **I want** nhìn thấy ngay danh sách học sinh đang chờ duyệt ở phần đầu Drawer,
- **So that** tôi có thể bấm "Cho vào" hoặc "Từ chối" trực tiếp ngay trong danh sách lớp.
- **Acceptance Criteria:**
  - Khi `pendingAdmitCount > 0`, hiển thị một Card nổi bật màu cam/xanh: "Đang chờ duyệt ($pendingAdmitCount học sinh)".
  - Có nút bấm "Cho vào tất cả" kích hoạt `meetService.admitAllPending()`.
  - Có toggle công tắc "Tự động duyệt học sinh" ngay trong card này.

### User Story 3 (P1): Toast Banner trên Canvas & Badge trên TopBar
- **As a** giáo viên đang tập trung viết vẽ trên bảng,
- **I want** nhìn thấy thông báo nổi nhẹ ở góc màn hình và badge đỏ trên nút người tham gia,
- **So that** tôi không bị bỏ sót học sinh mà vẫn có thể duyệt 1-chạm mà không cần mở drawer.
- **Acceptance Criteria:**
  - `StudioAdmissionBanner` hiển thị trên Canvas khi `pendingAdmitCount > 0`.
  - Icon `Icons.groups` trên TopBar hiển thị Badge đỏ số lượng học sinh chờ.

---

## 3. Success Criteria
- [ ] Học sinh gõ cửa xin vào $\rightarrow$ `StudioStudentsDrawer` lập tức hiện mục chờ duyệt trong $\le 1$ giây.
- [ ] Bấm "Cho vào tất cả" trong Drawer hoặc Banner $\rightarrow$ học sinh trên web Google Meet được duyệt vào phòng ngay lập tức.
- [ ] Toàn bộ test suite 111+ tests pass 100%.
