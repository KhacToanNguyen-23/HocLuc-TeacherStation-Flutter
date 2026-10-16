# Brainstorm: Zero-Click In-App Google Meet & Classroom Unified Auth

**Date:** 2026-10-16

## Ideas Explored
1. **OAuth ngoài trình duyệt + WebView2 đăng nhập riêng (Hiện tại - Đã loại bỏ):**
   - Giáo viên phải đăng nhập Google 2 lần (1 lần trên Chrome để cấp quyền Classroom/Calendar, 1 lần trên WebView2 để host Meet). Gây ma sát UI/UX nghiêm trọng.
2. **Mô hình thuần Companion (Bỏ WebView2, mở Meet trên Chrome ngoài):**
   - Tạo link bằng OAuth backend nhưng mở Meet trên Chrome thật của giáo viên. Nhược điểm: Mất khả năng nhúng giao diện bài giảng, camera ảo và điều khiển DOM Meet trực tiếp từ app.
3. **In-App Unified Edge WebView2 Flow (Được lựa chọn):**
   - Đưa toàn bộ luồng OAuth cấp quyền (Classroom, Calendar, Meet) vào trong chính Edge WebView2 nhúng ngay từ màn hình Login của app.
   - 1 lần đăng nhập duy nhất mang lại cả 2 kết quả: Backend có OAuth tokens gọi API, WebView2 có Google Session cookies để host Meet.

## User's Direction
- "Hướng tới giáo viên làm việc tạo link tạo phòng học toàn bộ trên app, zero click ra bên ngoài."
- Đăng nhập Google hợp nhất diễn ra ngay tại màn hình Login chính của app.
- Giữ nguyên bố cục giao diện Studio hiện tại (Meet hiển thị dock/popup linh hoạt, không ép chia đôi màn hình cố định).

## Open Questions
- Xử lý User-Agent của Edge WebView2 nhằm đảm bảo Google OAuth không chặn với lỗi `disallowed_useragent` (đảm bảo cấu hình Chromium launch flags hoặc chuẩn User-Agent Windows Edge).
- Cơ chế refresh token định kỳ trên backend khi access token 1 giờ của Google hết hạn trong quá trình dạy học dài.

## Risks
- **Google OAuth User-Agent Policy:** Google có thể chặn OAuth nếu WebView2 gửi header User-Agent nhúng bị nhận diện là webview không an toàn. Cần đảm bảo WebView2 dùng profile Edge chính thống hoặc user agent tương đương desktop Chrome/Edge.
- **Quyền Classroom Consumer:** Tài khoản Gmail cá nhân (@gmail.com) khi tạo lớp Classroom ở trạng thái `PROVISIONED` cần kích hoạt hoặc fallback Calendar Event mời email học sinh trực tiếp.
