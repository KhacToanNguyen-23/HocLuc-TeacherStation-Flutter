# Brainstorm: Trang Đăng Nhập & Đăng Ký Chuẩn Flat Modal (SĐT, Email, Google & OTP)

**Date:** 2026-10-11

## Ideas Explored
1. **Phương pháp xác thực thứ 3 tiện lợi nhất tại Việt Nam:**
   - *Zalo Login / Zalo QR:* Tiện cho người dùng đại chúng, nhưng phức tạp về quy trình cấp Zalo App ID và ZNS doanh nghiệp.
   - *Google Sign-In (Được chọn):* Cực kỳ quen thuộc với giáo viên và các đơn vị giáo dục (Gmail, tài khoản trường đại học/phổ thông). Tương thích 100% với kiến trúc Google Meet / Calendar API hiện có của Mộc Studio.
2. **Kiểu giao diện (UI Form Layout):**
   - *Fullscreen Screen riêng:* Tách biệt nhưng làm gián đoạn trải nghiệm người dùng khi đang ở sảnh chờ (Lobby).
   - *Modal Pop-up chia đôi 50/50 phong cách Flat (Được chọn):* Cột trái là đồ họa minh họa thương hiệu Mộc ("Trạm Giảng Dạy - Dạy học tốt hơn cho giáo viên"), cột phải là Form đăng nhập/đăng ký gọn gàng, hiện đại.
3. **Cơ chế xác thực SĐT & Email:**
   - *Mật khẩu cố định:* Dễ quên, phải làm thêm luồng Quên mật khẩu.
   - *Xác thực bằng OTP (Được chọn):* Hiện đại, bảo mật cao, không cần nhớ mật khẩu. Nhập SĐT/Email -> nhận mã OTP 6 số để đăng nhập/đăng ký tức thì.

## User's Direction
- Chọn **Google** làm phương pháp tiện ích bổ sung số 1.
- Giao diện **Modal chia đôi phong cách Flat** (ảnh mẫu đính kèm).
- Xác thực đăng nhập và đăng ký bằng **mã OTP** gửi về Số điện thoại / Email.

## Open Questions
1. Cơ chế gửi OTP trong môi trường Dev: Mô phỏng Mock OTP (cố định `123456` hoặc in console log backend) trước khi cấu hình SMS Gateway / SMTP thật?
2. Lưu trữ phiên đăng nhập (Session/Token): Lưu token đăng nhập vào `SharedPreferences` / `LocalStorage` trên Flutter client và quản lý phiên tại Spring Boot backend.

## Risks
1. Chi phí cước SMS OTP viễn thông Việt Nam: Nếu gửi OTP qua SMS thật sẽ tốn chi phí cho mỗi tin nhắn, nên ưu tiên Email OTP hoặc Mock OTP trong giai đoạn đầu.
2. Trải nghiệm nhập OTP trên Desktop vs Web: Cần thiết kế ô nhập OTP thông minh (tự động nhảy sang ô tiếp theo, hỗ trợ dán mã 6 số từ clipboard).
