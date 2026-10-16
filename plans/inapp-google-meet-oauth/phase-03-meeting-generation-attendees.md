# Phase 3: Headless Meeting Generation with Student Attendees

**Goal:** Hoàn thiện và xác thực cơ chế backend tự động đồng bộ học sinh từ Google Classroom và tạo sự kiện Google Calendar kèm Google Meet link với danh sách `attendees`.

---

## Tasks

1. **Kiểm tra Backend `GoogleClassService.java`:**
   - Xác nhận hàm `schedule` và `start` tạo Calendar event với `conferenceData` loại `hangoutsMeet`.
   - Đảm bảo toàn bộ email học sinh (`students` có `meetAllowed == true`) được đưa vào mảng `attendees`.
   - Trả về đối tượng `course` có `meetingUrl` hợp lệ dạng `https://meet.google.com/xxx-yyyy-zzz`.

2. **Frontend `GoogleWorkspaceScreen` / `ClassroomDashboardScreen`:**
   - Khi giáo viên nhấn "Bắt đầu buổi học" hoặc "Chuẩn bị phòng": gọi API backend để nhận link Meet đã có sẵn học sinh.
   - Truyền link Meet này vào đối tượng `TeachingTarget`.

## Verification Criteria
- Link Meet được sinh tự động bởi backend qua Calendar API mà không cần mở `meet.google.com/new` thủ công trên trình duyệt.
- Học sinh đăng nhập bằng đúng email trong danh sách lớp khi bấm vào link Meet sẽ được vào thẳng phòng mà không thấy thông báo chờ Host duyệt.
