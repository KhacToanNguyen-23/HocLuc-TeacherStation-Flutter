# Spec: Teacher Station Broadcasting (Virtual Camera)

**Date:** 2026-10-09
**Status:** Draft

---

## Problem Statement
Giáo viên cần một ứng dụng hỗ trợ giảng dạy (có bảng trắng, công cụ dạy học, lọc âm thanh) hoạt động đồng bộ với Google Meet. Thay vì xây dựng nền tảng RTC đắt đỏ như ClassIn, chúng ta dùng Google Meet để chịu tải và truyền dẫn, trong khi ứng dụng (Flutter + Java) đóng vai trò "Trạm phát sóng", trộn mọi nội dung thành luồng Virtual Camera & Microphone.

---

## User Stories

- **[P1]** As a Giáo viên, I want to bấm nút "Bắt đầu dạy" so that toàn bộ bảng trắng và công cụ của tôi tự động phát qua Camera Ảo lên Google Meet.
  Accepted when: Học sinh trên Google Meet nhìn thấy màn hình bảng trắng của giáo viên thông qua luồng video Camera.

- **[P1]** As a Giáo viên, I want to tích hợp trực tiếp giọng nói của tôi qua ứng dụng so that ứng dụng có thể tự động lọc tiếng ồn trước khi đẩy qua Google Meet bằng Mic ảo.
  Accepted when: Âm thanh thu từ mic thật được xử lý và truyền qua Virtual Microphone vào Google Meet.

- **[P2]** As a Giáo viên, I want to hiển thị luồng Camera của chính tôi lồng ghép (PIP) vào bên trong không gian Bảng trắng so that học sinh vừa thấy bài giảng vừa thấy mặt tôi.
  Accepted when: Webcam của giáo viên hiển thị như một layer bên trong Flutter App.

- **[P3]** _(out of scope — noted for future)_ Hệ thống cho phép học sinh tương tác ngược lại trên bảng trắng thông qua Google Meet (vô thi). 

---

## Functional Requirements

1. FR-01: Ứng dụng phải đăng ký một Virtual Camera và Virtual Microphone trên OS (Windows).
2. FR-02: Backend (Java Service) phải nhận lệnh `/api/output/start` và `/api/output/stop` để điều khiển luồng phát sóng.
3. FR-03: Ứng dụng phải có khả năng capture liên tục (≥24 fps) giao diện Flutter (hoặc Whiteboard HTML) để đẩy vào Virtual Camera.
4. FR-04: Âm thanh thu từ Mic thật phải được định tuyến qua Java Service để xử lý âm thanh (Noise Cancellation) trước khi ra Virtual Mic.

---

## Non-Functional Requirements

- Performance: Độ trễ (latency) từ thao tác vẽ trên bảng đến khi xuất ra Virtual Camera phải < 100ms.
- Performance: Tốc độ khung hình (framerate) của Virtual Camera phải duy trì ổn định ở mức ≥ 24 FPS.
- CPU Usage: Quá trình mix video và capture không được vượt quá 20% CPU trên các máy tính chuẩn (Intel i5 Gen 8th trở lên).
- Security: Cài đặt driver ảo phải vượt qua các cảnh báo bảo mật cơ bản hoặc có hướng dẫn cài đặt rõ ràng.

---

## Success Criteria

- [ ] FPS Output: >= 24 FPS khi đẩy luồng UI ra Virtual Camera.
- [ ] Audio Latency: < 150ms độ trễ âm thanh từ Mic vật lý đến Virtual Mic.
- [ ] API Connection: Java service xử lý thành công lệnh POST `/api/output/start` mà không ném lỗi 501.

---

## Out of Scope

- Xây dựng hệ thống chat hoặc video call riêng (sử dụng hoàn toàn Google Meet).
- Cung cấp công cụ vẽ tương tác hai chiều (real-time collaboration) dành riêng cho học sinh ở Phase này (do bị giới hạn bởi tính một chiều của Video Stream).

---

## Assumptions

- OS mục tiêu hiện tại là Windows (do đã có WinForms Wrapper và script PowerShell).
- Người dùng (Giáo viên) có quyền Administrator để cài đặt driver Virtual Camera/Microphone lần đầu tiên.

---

## [NEEDS CLARIFICATION]

- [ ] Giải pháp kỹ thuật Mix Video (Sử dụng OBS Core C++ nhúng hay tự viết Desktop Duplication / Media Foundation plugin)?
- [ ] Học sinh có cần công cụ riêng để xem bài tập không (hay chỉ thuần tuý xem qua Google Meet)?
