# Brainstorm: Form Đăng nhập Mật khẩu & Form Đăng ký Xác thực (Theo mẫu người dùng)

**Date:** 2026-10-11

## Ideas Explored

1. **Đăng nhập bằng OTP**: Bị loại bỏ hoàn toàn theo yêu cầu. Đăng nhập giờ chỉ dùng Số điện thoại/Email + Mật khẩu.
2. **Form Đăng ký**:
   - Phương án cũ: Chỉ có email + phone + password (không xác thực).
   - Phương án chuẩn theo mẫu người dùng cung cấp (Ảnh "Signup A New Account"):
     - Ô 1: Email hoặc Số điện thoại.
     - Ô 2: Mã OTP xác thực (Verification code) kèm nút bấm "Gửi mã" (Send code) ngay cạnh/trong ô.
     - Ô 3: Mật khẩu (có icon mắt ẩn/hiện).
3. **Nút chuyển đổi form**:
   - Dưới nút Đăng nhập: Để đúng 1 chữ duy nhất: **"Đăng ký"**.
   - Dưới nút Đăng ký: Để đúng 1 chữ duy nhất: **"Quay lại"** (hoặc "Đăng nhập").
4. **Kiểu dáng khung (Input styling)**:
   - Khung vuông vắn, viền xám mảnh chuẩn form công vụ (như hình mẫu người dùng gửi).
5. **Đăng nhập xã hội / Gmail**:
   - Dưới cùng chỉ để 1 icon Google tròn gọn gàng.

---

## User's Direction

### 1. Màn hình Đăng nhập (Mặc định)
- Ô 1: Email hoặc Số điện thoại.
- Ô 2: Mật khẩu (có icon mắt).
- Nút to: `[Đăng nhập]` (hoặc nút Đăng nhập nhanh Demo).
- Dưới nút Đăng nhập: Đúng 1 chữ nhỏ: **`Đăng ký`**.
- Dưới cùng: 1 icon Google tròn duy nhất.

### 2. Màn hình Đăng ký (Theo ảnh mẫu "Signup A New Account")
- Ô 1: Email hoặc Số điện thoại (kèm prefix +84).
- Ô 2: Mã xác thực OTP (Enter verification code) + Nút `Gửi mã` (Send code).
- Ô 3: Mật khẩu (Enter password) + Icon ẩn/hiện mắt.
- Checkbox: Điều khoản & Bảo mật.
- Nút to: `[Đăng ký]`.
- Dưới nút Đăng ký: Đúng 1 chữ nhỏ: **`Quay lại`**.
- Dưới cùng: Icon Google tròn.

---

## Open Questions for $bb-plan

1. Logic backend cho Đăng ký:
   - Endpoint `POST /api/auth/otp/send`: Gửi OTP xác thực khi đăng ký.
   - Endpoint `POST /api/auth/register`: Nhận target (email/phone), OTP, và password -> xác thực OTP rồi tạo tài khoản.
2. Endpoint Đăng nhập:
   - `POST /api/auth/login`: Nhận target + password -> kiểm tra và trả về JWT token.

---

## Risks

1. Đồng bộ luồng gửi OTP chỉ xuất hiện ở bước Đăng ký (Sign up), tuyệt đối không xuất hiện ở bước Đăng nhập.
2. Đảm bảo giao diện form tuân thủ chuẩn khung vuông như ảnh mẫu.
