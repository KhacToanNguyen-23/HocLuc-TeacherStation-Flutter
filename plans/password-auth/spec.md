# Spec: Password Authentication & Verification Signup Flow

**Date:** 2026-10-11
**Status:** Ready

---

## Problem Statement
Đơn giản hóa trải nghiệm đăng nhập cho giáo viên: Đăng nhập bằng Email/SĐT và Mật khẩu (không dùng OTP khi đăng nhập). Quy trình Đăng ký tài khoản mới được thiết kế trực quan theo chuẩn biểu mẫu (Email/SĐT + Mã xác thực OTP + Mật khẩu), có khung viền vuông vắn, nút chuyển đổi tối giản (chữ "Đăng ký" và "Quay lại"), và 1 icon Google tròn gọn gàng.

---

## User Stories

- **[P1]** Là một giáo viên, tôi muốn đăng nhập bằng Email hoặc Số điện thoại cùng Mật khẩu để vào hệ thống ngay lập tức mà không phải chờ mã OTP.
  Accepted when: Nhập Email/SĐT + Password -> Bấm [Đăng nhập] -> Vào Dashboard.

- **[P1]** Là một giáo viên, tôi muốn bấm vào chữ nhỏ "Đăng ký" dưới nút Đăng nhập để chuyển sang form Đăng ký tài khoản mới.
  Accepted when: Bấm chữ "Đăng ký" -> Chuyển sang form Đăng ký.

- **[P1]** Là một giáo viên mới, tôi muốn đăng ký bằng Email hoặc Số điện thoại, nhận mã xác thực OTP ngay trong ô nhập và đặt Mật khẩu để hoàn tất đăng ký.
  Accepted when:
  - Điền Email/SĐT -> Bấm "Gửi mã" -> Nhập mã OTP nhận được.
  - Nhập Mật khẩu.
  - Bấm [Đăng ký] -> Đăng ký thành công và tự động đăng nhập.

- **[P1]** Là một giáo viên, tôi muốn bấm chữ nhỏ "Quay lại" dưới nút Đăng ký để trở về form Đăng nhập bất cứ lúc nào.
  Accepted when: Bấm chữ "Quay lại" -> Trở về form Đăng nhập.

- **[P1]** Là một giáo viên, tôi muốn đăng nhập nhanh bằng Gmail thông qua 1 icon Google tròn duy nhất.
  Accepted when: Bấm icon Google tròn -> Đăng nhập Google 1-chạm.

- **[P2]** Là người dùng trải nghiệm, tôi muốn có nút [⚡ Đăng nhập nhanh] để vào tài khoản Thầy Khắc Toàn Demo 1-chạm.
  Accepted when: Bấm Đăng nhập nhanh -> Vào thẳng Dashboard.

---

## Functional Requirements

### 1. Màn hình Đăng nhập (Login)
1. **FR-L01**: Ô nhập Email hoặc Số điện thoại: Khung viền vuông (`borderRadius: 4px - 6px`), viền xám `slate300`, focus `sky600`.
2. **FR-L02**: Ô nhập Mật khẩu: Ký tự ẩn mặc định, có nút icon mắt để bật/tắt hiển thị mật khẩu.
3. **FR-L03**: Nút chính `[Đăng nhập]`: Nền xanh dương `sky600`, chữ trắng.
4. **FR-L04**: Nút chuyển đổi form: Đặt ngay dưới nút Đăng nhập, hiển thị **đúng 1 chữ duy nhất: `Đăng ký`** (chữ nhỏ, màu xanh/xám, có thể click).
5. **FR-L05**: Đăng nhập Gmail: Hiển thị **đúng 1 icon Google tròn** duy nhất ở phía dưới.
6. **FR-L06**: Nút `[⚡ Đăng nhập nhanh]` 1-chạm tài khoản Demo.

### 2. Màn hình Đăng ký (Signup - Theo ảnh mẫu)
1. **FR-S01**: Tiêu đề form: Đăng ký tài khoản (`Đăng ký`).
2. **FR-S02 (Ô 1)**: Email hoặc Số điện thoại (kèm selector prefix `+84`).
3. **FR-S03 (Ô 2)**: Nhập mã xác thực (Enter verification code) tích hợp nút bấm `Gửi mã` (Send code) nằm ngay bên phải ô nhập, có đếm ngược cooldown 60s khi đã gửi.
4. **FR-S04 (Ô 3)**: Nhập mật khẩu (Enter password) có icon mắt ẩn/hiện.
5. **FR-S05**: Checkbox "Tôi đồng ý với Điều khoản & Chính sách bảo mật".
6. **FR-S06**: Nút chính `[Đăng ký]` (Signup).
7. **FR-S07**: Nút chuyển đổi: Đặt ngay dưới nút Đăng ký, hiển thị **đúng 1 chữ duy nhất: `Quay lại`** (chữ nhỏ, click để quay về form Đăng nhập).

### 3. Backend APIs
1. `POST /api/auth/login`: Nhận `{ "identifier": "...", "password": "..." }` -> Trả về `{ "success": true, "token": "...", "user": {...} }`.
2. `POST /api/auth/otp/send`: Gửi mã OTP xác thực phục vụ bước Đăng ký.
3. `POST /api/auth/register`: Nhận `{ "target": "...", "otp": "...", "password": "..." }` -> Kiểm tra OTP, tạo tài khoản và trả về JWT session.
4. `POST /api/auth/demo`: Giữ nguyên cho tài khoản Demo.

---

## Non-Functional Requirements
- **Kiểu dáng khung (Input style)**: Toàn bộ các ô nhập có viền khung vuông vắn (`borderRadius: BorderRadius.circular(6)`), viền nét đơn sắc nét giống 100% ảnh mẫu.
- **Tốc độ phản hồi**: Gửi mã và xác thực < 300ms.
- **Trải nghiệm**: Không giật lag khi chuyển đổi giữa form Đăng nhập và Đăng ký.

---

## Success Criteria
- [ ] Màn hình Đăng nhập hoàn toàn không còn OTP, đăng nhập bằng Email/SĐT + Mật khẩu.
- [ ] Dưới nút Đăng nhập hiển thị đúng 1 chữ: `Đăng ký`.
- [ ] Dưới nút Đăng ký hiển thị đúng 1 chữ: `Quay lại`.
- [ ] Form Đăng ký gồm đúng 3 ô: Email/SĐT, Mã OTP + nút Gửi mã, Mật khẩu.
- [ ] Khung nhập viền vuông vắn chuẩn như ảnh mẫu.
- [ ] Dưới cùng chỉ có 1 icon Google tròn duy nhất.
- [ ] 22/22 Flutter tests và backend tests pass 100%.
