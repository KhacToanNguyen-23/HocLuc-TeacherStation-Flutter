# Brainstorm: Tinh gọn Giao diện Math Studio (Hướng 2: Accordion Nâng Cao)

**Date:** 2026-10-26

## Bối cảnh & Vấn đề thực tế
Từ ảnh chụp thực tế màn hình của người dùng (`media_1792974630988_29899343.png`):
1. **Tràn thanh cuộn ngang & dọc:** Cột điều khiển bên trái bị nhồi nhét 5 thẻ riêng biệt khiến giao diện bị kéo dài, phát sinh thanh cuộn dọc. Đặc biệt, cụm "KHUNG NHÌN" có 6 ô nhập số bị tràn chiều ngang sinh ra thanh cuộn ngang dưới đáy làm mất thẩm mỹ.
2. **Thẻ chức năng chiếm chỗ nhưng ít dùng:** Thẻ "MIỀN NGHIỆM" (đang là stub) và "VẬT THỂ TRÒN XOAY" mỗi mục chiếm riêng 1 khối viền lớn chỉ để chứa 1 nút bấm đơn lẻ, làm lấn át 2 chức năng cốt lõi là HÀM SỐ và ĐIỂM CỰC TRỊ.
3. **Thanh Header tabs bị khuất mép phải:** Các tab chuyển chế độ bị tràn sang bên phải khi cửa sổ ở kích thước mặc định.

## Các hướng giải pháp đã xem xét
- **Hướng 1 — Lược bỏ triệt để:** Bỏ hoàn toàn thẻ Miền nghiệm, Vật thể tròn xoay và Khung nhìn số, chỉ giữ lại Hàm số và Điểm; điều chỉnh khung nhìn thuần túy bằng con lăn chuột và kéo rê.
  - *Ưu điểm:* Giao diện siêu gọn.
  - *Nhược điểm:* Mất đi tính năng mô hình tròn xoay SGK lớp 12 và khả năng đặt tỉ lệ khung nhìn chính xác khi in ấn.
- **Hướng 2 — Tinh gọn phân tầng (Người dùng chọn):**
  - Giữ lại 2 khối cốt lõi hiển thị trực diện: **HÀM SỐ** và **ĐIỂM (Cực trị / Giao trục)**.
  - Gom toàn bộ các tính năng phụ ít dùng (**Vật thể tròn xoay**, **Khung nhìn thủ công**, **Miền nghiệm**) vào một mục **`Tùy chọn nâng cao ▾` (Collapsible Accordion)** thu gọn mặc định.
  - Thiết kế lại lưới nhập Khung nhìn dạng 2 cột co giãn để triệt tiêu hoàn toàn thanh cuộn ngang.
  - Thu gọn padding header để các tab hiển thị đầy đủ, không bị cấn mép.

## Hướng đi đã chốt (User's Direction)
- Triển khai theo **Hướng 2**: Gom các mục phụ vào Accordion "Tùy chọn nâng cao", trả lại không gian thoáng sạch và không còn thanh cuộn ngang/dọc không cần thiết.

## Các rủi ro cần kiểm soát
1. Trạng thái bật/tắt của "Vật thể tròn xoay" khi nằm trong accordion thu gọn vẫn phải phản ánh tức thì lên đồ thị mà không làm đứt liên kết state.
2. Grid layout của Khung nhìn phải dùng `grid-template-columns: 1fr 1fr` hoặc `flex` với `min-width: 0` để tuyệt đối không tràn chiều ngang của cột 380px.

