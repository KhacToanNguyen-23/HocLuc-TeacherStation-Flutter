# Spec: Teacher Station - Headless Google Meet Cockpit & High-Definition Broadcasting

**Date:** 2026-10-11
**Status:** Ready
**Slug:** teacher-station-meet-cockpit

---

## Problem Statement

Giáo viên dạy học trực tuyến gặp khó khăn khi phải vừa mở Google Meet, vừa mở phần mềm bảng vẽ, dễ gây lỗi phân tâm, chia sẻ nhầm màn hình riêng tư, và chất lượng chia sẻ qua camera thường bị vỡ vụn/mờ chữ. Đồng thời, việc tự xây dựng hạ tầng WebRTC video call tốn kém chi phí băng thông lớn. Giải pháp cần biến Teacher Station thành một "buồng lái VIP" điều khiển Google Meet ngầm, giáo viên chỉ cần làm việc trên app, tự động phát 2 luồng (bảng vẽ siêu nét + webcam đã tút tát) và nhận toàn bộ dữ liệu học sinh (chat, giơ tay, mic) về app.

---

## User Stories

- **[P1]** As a Giáo viên, I want to bấm "Bắt đầu lớp học" trên Teacher Station so that hệ thống tự động khởi tạo và vào phòng Google Meet ngầm bên dưới mà tôi không cần mở trình duyệt Meet.
  *Accepted when:* Phòng Meet được khởi tạo hợp lệ, link được hiển thị trên app để gửi học sinh, WebView2 tự động vượt qua màn hình chờ và tham gia phòng.

- **[P1]** As a Giáo viên, I want màn hình bảng vẽ của tôi được truyền tải tới học sinh với độ nét 1080p sắc nét (không vỡ hạt) so that học sinh đọc rõ từng công thức toán và chữ viết.
  *Accepted when:* Luồng bảng vẽ được bắt qua WGC và inject dưới dạng luồng Presentation/Virtual Camera với độ phân giải ≥ 1080p, chữ viết không bị mờ do nén.

- **[P1]** As a Giáo viên, I want học sinh trên Google Meet nhìn thấy cả 2 luồng: Bảng vẽ bài giảng và Camera quay mặt tôi so that tạo trải nghiệm lớp học tự nhiên chuẩn mực.
  *Accepted when:* Học sinh trong Meet thấy luồng Bảng vẽ ở khung lớn và Camera khuôn mặt giáo viên ở khung nhỏ.

- **[P1]** As a Giáo viên, I want to đọc tin nhắn chat và nhìn thấy học sinh giơ tay trực tiếp trên Teacher Station so that tôi không bị bỏ lỡ tương tác của học sinh.
  *Accepted when:* Tin nhắn gửi trên Meet xuất hiện trên thanh Inspector Panel của app trong vòng < 500ms; trạng thái giơ tay được kích hoạt thông báo trên UI.

- **[P2]** As a Giáo viên, I want to áp dụng bộ lọc xóa phông/background ảo và lọc tiếng ồn cho micro so that hình ảnh và giọng nói của tôi chuyên nghiệp hơn trước khi phát tới học sinh.
  *Accepted when:* Mic được lọc sạch tạp âm (quạt, gõ phím) và camera mặt có thể bật/tắt phông nền ảo ngay trên app.

- **[P2]** As a Giáo viên, I want các nút thao tác nhanh "Duyệt tất cả" (Admit all) và "Tắt tiếng tất cả" (Mute all) từ app so that tôi quản lý lớp trong 1 cú click.
  *Accepted when:* Bấm nút trên Teacher Station làm kích hoạt tự động sự kiện click tương ứng trên giao diện Meet ngầm.

- **[P3]** _(Out of scope cho giai đoạn này)_: Học sinh tương tác vẽ 2 chiều trực tiếp lên bảng vẽ từ Google Meet (do giới hạn một chiều của video stream).

---

## Functional Requirements

1. **FR-01 (Headless Meet Lifecycle):** WebView2 tự động mở `meet.google.com/new`, bắt link phòng mới sinh ra qua URL change event và lưu trữ vào State app.
2. **FR-02 (Zero-Click Auto Join):** Script tự động click nút "Tham gia ngay / Join now", tự động đóng các modal pop-up cấp quyền ban đầu.
3. **FR-03 (WGC Canvas Capture):** Plugin C++ WGC capture khung hình cửa sổ Bảng vẽ (HWND) với tần số 30–60 FPS, độ phân giải 1080p, không bị chèn bởi các cửa sổ nổi khác.
4. **FR-04 (Dual-Feed Transmission):** 
   - Đẩy luồng Bảng vẽ vào Meet dưới dạng Presentation stream hoặc Virtual Camera HD.
   - Bật luồng Webcam vật lý vào Meet dưới dạng Video track chính của giáo viên.
5. **FR-05 (DOM Mutation Observer Bridge):** Inject script vào Meet DOM để:
   - Giám sát vùng `#chat-container` và trích xuất tin nhắn mới.
   - Giám sát danh sách giơ tay và trạng thái micro của học sinh.
   - Bắn dữ liệu về Flutter App qua kênh giao tiếp 2 chiều (`postMessage` / WebView IPC).
6. **FR-06 (Remote Host Controls):** Nhận lệnh từ Flutter App (Admit, Mute all) và thực thi click giả lập vào các nút tương ứng trên Meet DOM.
7. **FR-07 (Audio/Video FX Pipeline):** Tích hợp Web Audio API DSP (Noise Gate, High-pass filter, Equalizer) để xử lý âm thanh trước khi đưa vào luồng mic của Meet.

---

## Non-Functional Requirements

- **Performance (Latency):** Độ trễ từ khi học sinh chat trên Meet đến khi hiển thị trên Flutter App ≤ 500ms.
- **Performance (Framerate):** Luồng Bảng vẽ duy trì ổn định ≥ 30 FPS với độ phân giải tối thiểu 1080p (1920x1080).
- **Resource Usage:** WebView2 + WGC Broadcaster không chiếm quá 25% CPU trên máy tính Intel Core i5 Gen 8 / Ryzen 5 tương đương.
- **Reliability:** Hệ thống có cơ chế tự động thử lại (Retry / Selector Fallback) nếu cấu hình DOM của Google Meet có thay đổi nhỏ về class name.

---

## Success Criteria

- [ ] Tạo phòng & Tham gia tự động hoàn tất trong < 5 giây sau khi bấm nút trên app.
- [ ] Học sinh trên Google Meet xem được bảng vẽ chữ viết rõ nét ở độ phân giải 1080p.
- [ ] Mọi tin nhắn gửi từ Meet được hiển thị tức thì trên Inspector Panel của Flutter App.
- [ ] Giáo viên bấm "Tắt mic cả lớp" từ App làm tắt mic học sinh trên Meet thành công.

---

## Out of Scope

- Không tự phát triển server WebRTC SFU/MCU riêng (toàn bộ tải truyền dẫn giao cho Google Meet).
- Không hỗ trợ vẽ tương tác 2 chiều từ phía học sinh vào bảng vẽ trong giai đoạn này.

---

## Assumptions

- Môi trường chạy chính của giáo viên là Windows 10/11 x64 (đáp ứng điều kiện cài WebView2 Runtime và hỗ trợ WGC API).
- Giáo viên đã đăng nhập tài khoản Google ít nhất 1 lần trên WebView2 để được cấp quyền Host phòng.

---
