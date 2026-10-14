# Brainstorm: Zero-Click Google Meet Host Automation & Persistent Session

**Date:** 2026-10-14  
**Status:** Completed  

## Ideas Explored
1. **Chuyển sang Zoom Video SDK:** Học sinh không dùng được app Zoom quen thuộc, giới hạn 10.000 phút participant, Flutter package không hỗ trợ Windows desktop natively. (Loại bỏ).
2. **Chuyển sang WebRTC tự host (LiveKit / Docker SFU):** Phát sinh chi phí cố định thuê VPS và gánh nặng bảo trì server media. (Loại bỏ).
3. **Mô hình PaaS Cloud (Agora RTC):** Tốt về mặt kỹ thuật nhưng đi ngược lại với triết lý "đứng trên vai người khổng lồ" để giải quyết bài toán tải phòng học $0đ$ cho học sinh THPT. (Loại bỏ).
4. **Chuẩn hóa kiến trúc Google Meet Headless với Persistent Profile (Được chọn):** Đứng trên vai Google Meet để $0đ$ chi phí băng thông/phòng học. Khắc phục triệt để lỗi rớt session bằng WebView2 Shared User Data Directory, loại bỏ tham số `authuser` gây lỗi routing, cấp quyền media tự động ở tầng native, loại bỏ toàn bộ thao tác mở Chrome ngoài.

## User's Direction
- **Triết lý sản phẩm:** "Đứng trên vai người khổng lồ (Google Meet)" để giải quyết bài toán tải phòng học cho học sinh THPT với chi phí hạ tầng $0đ$.
- **Định nghĩa Zero-Click:** "Zero-Click ở trang Google Meet" — Giáo viên không bao giờ phải nhìn thấy, mở tab hay thao tác trên trang Google Meet. Mọi thao tác (tạo phòng, duyệt học sinh, giảng dạy) diễn ra 100% trong App Teacher Station.
- **Luồng chuẩn được chọn (Hướng 1 - One-Time Google Setup + Direct Auto-Join):**
  1. Giáo viên ở **Dashboard** bấm **"Bắt đầu"**.
  2. Nếu là lần đầu tiên chưa có session Google: App bật hộp thoại WebView đăng nhập Google một lần duy nhất. Session được lưu vĩnh viễn trong `%APPDATA%/HocLucTeacherStation/EdgeProfile`.
  3. WebView2 ngầm tự động tạo link Google Meet thật (`meet.google.com/xxx-yyyy-zzz`) và tự join phòng làm Host.
  4. App mở **Lobby** với link Meet đã điền sẵn 100%. Giáo viên chỉ kiểm tra Cam/Mic trên màn hình app.
  5. Giáo viên bấm **"Bắt đầu vào phòng giảng dạy"** $\rightarrow$ Vào thẳng Studio, giáo viên đã ở trong phòng Meet từ trước, không có bất kỳ popup hay cảnh báo nào cản trở.
- **Xử lý xung đột Camera phần cứng:** Bổ sung cờ `--use-fake-device-for-media-stream` cho WebView2 ngầm để giải phóng 100% webcam vật lý cho Flutter (`TeacherMediaService`), loại bỏ triệt để lỗi `Camera with given device id already exists`.

## Open Questions & Decisions Resolved
1. **Lỗi chưa có link Meet:** Do WebView2 ngầm redirect sang `accounts.google.com` khi chưa đăng nhập. Xử lý: Phát hiện trạng thái chưa đăng nhập để bật `GoogleWebviewLoginDialog` tương tác 1 lần thay vì để headless timeout.
2. **Lỗi Camera Device Already Exists:** Do Chromium của WebView2 chiếm webcam vật lý. Xử lý: Cách ly WebView2 bằng cờ `--use-fake-device-for-media-stream`.

## Risks
1. **Google Account 2FA:** Khi đăng nhập Google lần đầu trong app, nếu tài khoản có xác thực 2 bước (2FA), giáo viên hoàn tất trên dialog tương tác của App một lần duy nhất.
2. **Duy trì Camera Lifecycle:** Đảm bảo Flutter giải phóng camera controller khi chuyển giữa Lobby và Studio.
