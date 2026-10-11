# Spec: Flat-Style Authentication Modal (Phone, Email, Google & OTP)

**Date:** 2026-10-11  
**Status:** Draft

---

## Problem Statement
Giáo viên và người dùng cần phương thức đăng nhập và đăng ký nhanh chóng, tiện lợi, không phải nhớ mật khẩu phức tạp để sử dụng Mộc Studio. Hệ thống cần giao diện hiện đại dạng modal 2 cột (phong cách Flat), hỗ trợ xác thực tức thì qua mã OTP (Số điện thoại / Email) và 1-click Google Sign-In phù hợp thói quen người dùng Việt Nam.

---

## User Stories

- **[P1]** As a giáo viên, I want to nhập Số điện thoại hoặc Email để nhận mã OTP 6 chữ số so that tôi có thể đăng nhập hoặc đăng ký tài khoản nhanh chóng mà không cần nhớ mật khẩu.  
  Accepted when: Hệ thống gửi mã OTP, hiển thị bộ đếm ngược 60s để gửi lại mã, và tự động xác thực khi nhập đủ 6 chữ số.

- **[P1]** As a giáo viên, I want to đăng nhập 1-click bằng tài khoản Google so that tôi tiết kiệm thời gian và tự động liên kết với quyền Host Google Meet phục vụ buổi dạy.  
  Accepted when: Bấm nút Google ở phía dưới modal, luồng xác thực Google OAuth hoàn tất và cập nhật phiên đăng nhập tức thì.

- **[P1]** As a người dùng, I want to chuyển đổi mượt mà giữa chế độ "Đăng nhập" và "Đăng ký" trên cùng một modal phong cách Flat so that tôi không bị chuyển trang gây mất trạng thái đang làm việc.  
  Accepted when: Giao diện modal pop-up có 2 cột (cột trái: hình minh họa thương hiệu + slogan "Dạy học tốt hơn cho giáo viên"; cột phải: form nhập liệu) với nút chuyển đổi Login/Signup.

- **[P2]** As a người dùng, I want to dán (paste) trực tiếp mã OTP 6 số từ clipboard vào ô nhập so that tôi không phải gõ từng số thủ công.  
  Accepted when: Bấm Ctrl+V hoặc dán vào ô đầu tiên, cả 6 ô OTP tự động điền đầy đủ.

- **[P3]** _(Out of scope)_ Đăng nhập bằng sinh trắc học Windows Hello / FaceID trên máy tính.

---

## Functional Requirements

1. **FR-01 (Flat Modal Layout):** Modal pop-up có kích thước chuẩn desktop/web (~840px x 520px) chia thành 2 phần:
   - Cột trái (45%): Nền xanh thương hiệu Mộc / gradient thanh lịch, typography "Dạy học tốt hơn cho giáo viên", hình minh họa giáo viên và công nghệ giảng dạy.
   - Cột phải (55%): Header "Chào mừng bạn đến với Mộc", trường nhập SĐT/Email, ô nhập OTP, checkbox điều khoản và nút hành động.
2. **FR-02 (Phương thức đầu vào):** Cho phép nhập Số điện thoại (tự động nhận diện đầu số `+84` Việt Nam) hoặc địa chỉ Email hợp lệ.
3. **FR-03 (Quy trình xác thực OTP):**
   - Bước 1: Người dùng nhập SĐT / Email -> Bấm "Gửi mã OTP" (hoặc "Tiếp tục").
   - Bước 2: Hiển thị giao diện nhập mã OTP gồm 6 ô số rời kèm bộ đếm ngược gửi lại mã (Resend countdown 60 giây).
   - Bước 3: Xác thực thành công -> Lưu Access Token và đóng modal, cập nhật header sang trạng thái đã đăng nhập.
4. **FR-04 (Google Sign-In Direct):** Nút biểu tượng Google nằm ở khu vực "Hoặc đăng nhập nhanh bằng" ở đáy form, kích hoạt luồng đăng nhập Google có sẵn của hệ thống.
5. **FR-05 (Chính sách & Điều khoản):** Checkbox "Tôi đã đọc và đồng ý với Điều khoản sử dụng và Chính sách bảo mật" (mặc định tích chọn hoặc bắt buộc xác nhận trước khi đăng ký).
6. **FR-06 (Backend API Verification):**
   - Endpoint `POST /api/auth/otp/send`: Tiếp nhận SĐT/Email và sinh mã OTP (trong môi trường Dev hỗ trợ Mock OTP `123456`).
   - Endpoint `POST /api/auth/otp/verify`: Tiếp nhận SĐT/Email + OTP để trả về User Token và thông tin giáo viên.

---

## Non-Functional Requirements

- **Performance:** Thời gian render modal < 100ms, chuyển đổi giữa bước nhập SĐT sang nhập OTP diễn ra mượt mà với animation < 200ms.
- **Security:** Mã OTP có hiệu lực tối đa 5 phút; giới hạn gửi lại mã tối thiểu cách nhau 60 giây để chống spam (Rate limiting).
- **Usability:** Hỗ trợ phím `Enter` để submit, tự động focus vào ô OTP đầu tiên khi chuyển bước.

---

## Success Criteria

- [ ] Modal mở lên mượt mà theo đúng bố cục 2 cột giống giao diện Flat.
- [ ] Nhập SĐT/Email và nhập mã OTP 6 chữ số đăng nhập thành công trong < 3 giây.
- [ ] Bấm nút Google đăng nhập thành công và cập nhật tên giáo viên lên TopBar.
- [ ] 100% kiểm thử giao diện và backend API chạy qua không có lỗi (`flutter test` và `mvn test` đạt 100%).

---

## Out of Scope

- Tích hợp cổng SMS Brandname trả phí trong môi trường local (sử dụng cơ chế Mock OTP / Console Logging trong giai đoạn thử nghiệm).
- Tích hợp phương thức đăng nhập WeChat / GitHub (thay thế bằng Google phù hợp với giáo viên Việt Nam).

---

## Assumptions

- Người dùng có kết nối internet để nhận OTP qua Email / SMS hoặc gọi Google OAuth.
- Phiên đăng nhập sẽ được lưu trữ cục bộ để duy trì trạng thái khi tải lại trang.

---

## [NEEDS CLARIFICATION]

- [ ] Trong giai đoạn thử nghiệm hiện tại, mã OTP sẽ được trả về trực tiếp trong response / hiển thị thông báo SnackBar trên màn hình để bạn tiện test ngay mà không cần đợi tin nhắn thật?
