# Brainstorm: Teacher Station - Headless Google Meet Cockpit & High-Definition Broadcasting

**Date:** 2026-10-11
**Status:** Completed

---

## 1. Ideas Explored

- **Direction 1: Tự dựng hạ tầng RTC riêng (WebRTC SFU - LiveKit/Jitsi/Mediasoup):**
  - *Đánh giá:* Chi phí server băng thông cao, bảo trì phức tạp, học sinh phải cài ứng dụng mới hoặc mở web mới. *-> Loại bỏ.*
- **Direction 2: Tích hợp Zoom qua Zoom Meeting Web SDK:**
  - *Đánh giá:* Có SDK chính thức, dễ lấy event chat/hands, nhưng bị rào cản chi phí lớn (bản miễn phí giới hạn 40 phút), giáo viên Việt Nam chuộng Google Meet hơn. *-> Lưu trữ cho B2B tương lai.*
- **Direction 3: "Headless Google Meet Cockpit" (Ký sinh hạ tầng Google Meet + Cam ảo/Screen Share Injection):**
  - *Đánh giá:* Miễn phí hoàn toàn băng thông, hỗ trợ lớp học dài (tài khoản Edu 24h), học sinh chỉ cần link Meet quen thuộc. Giáo viên tương tác 100% trên Teacher Station mà không cần mở giao diện Meet. *-> Được lựa chọn.*

---

## 2. User's Direction

Người dùng lựa chọn **Direction 3 (Google Meet Cockpit)** với các yêu cầu kỹ thuật chi tiết:
1. **Zero-Click cho Giáo viên:** Giáo viên chỉ thao tác trên Web/Desktop App của Teacher Station. Không cần mở trình duyệt ngoài, không cần tự bật mic hay share màn hình thủ công trên Meet.
2. **Dual Stream (2 Luồng chuẩn Google Meet):**
   - **Luồng 1 (Bảng vẽ / Bàn làm việc):** Xuất qua Cam ảo / Presentation Stream với độ nét cao 1080p, tối ưu text/bài tập, khắc phục triệt để hiện tượng vỡ vụn/mờ chữ.
   - **Luồng 2 (Webcam thật):** Quay mặt giáo viên, cho phép can thiệp xử lý trước (Virtual Background, Filter làm đẹp, Face tracking).
3. **Âm thanh tùy biến:** Hệ thống lọc tạp âm thông minh (AI Noise Suppression), làm ấm giọng hoặc đổi tone trước khi bơm vào Meet.
4. **Đồng bộ 2 chiều (Bidirectional Sync):** Toàn bộ tương tác của học sinh trên phòng Meet (tin nhắn chat, giơ tay, bật/tắt mic, biểu tượng cảm xúc) được tự động trích xuất và hiển thị ngay trên UI của Teacher Station. Giáo viên có thể bấm "Duyệt tất cả" hoặc "Tắt mic cả lớp" ngay từ app.

---

## 3. Technology & Architecture Blueprint

- **UI & Trạm điều khiển:** Flutter Desktop / Web (Studio Canvas, Toolbar, Inspector Panel).
- **Trình điều khiển ngầm (Headless Engine):** WebView2 (Chromium Embedded) chạy ẩn dưới background.
- **Bắt hình siêu nét:** Windows.Graphics.Capture (WGC) API trích xuất HWND Bảng vẽ 1080p 60fps không dính cửa sổ đè.
- **Media Pre-processing:**
  - *Video Filter:* MediaPipe / WebGL Shaders (Xóa phông, Virtual Background, Beauty filter).
  - *Audio DSP:* Web Audio API / RNNoise (Lọc tiếng ồn, Equalizer, Voice Morphing).
- **Two-way Data Bridge:** Chrome Extension / DOM Content Script kết hợp `MutationObserver` lắng nghe DOM của Google Meet và giao tiếp với Flutter qua WebSocket / HostObject IPC.

---

## 4. Open Questions & Risks

- **Rủi ro thay đổi DOM của Google Meet:** Google Meet có thể cập nhật cấu trúc HTML/class name theo thời gian. Cần thiết kế bộ selector linh hoạt (dựa trên `aria-label`, data attributes đa ngôn ngữ vi/en).
- **Tài khoản Google của Giáo viên:** Cần cơ chế lưu session/cookie đăng nhập Google trên WebView2 một lần để giáo viên giữ vai trò Host chính thức của phòng.

---
