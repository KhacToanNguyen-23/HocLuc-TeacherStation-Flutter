# Phase 3: Tích Hợp Miền Tích Phân & Điểm Tương Tác

## Goal
Tích hợp miền diện tích tích phân, tiệm cận phân thức và các điểm đánh dấu trên JSXGraph board.

## Requirements
1. Miền tích phân:
   - Dùng `board.create('integral', ...)` hoặc `curve` tô màu bán trong suốt `rgba(224, 36, 36, 0.16)`.
   - Hiển thị 2 mút cận $a, b$ với đường gióng lên đường cong.
   - Cho phép kéo mút $a, b$ trực tiếp trên trục hoành hoặc cập nhật từ input.
2. Tiệm cận phân thức:
   - Tiệm cận đứng và tiệm cận ngang vẽ bằng nét đứt (`dash: 2`).
   - Nhãn phương trình tiệm cận đặt ở mép ngoài cùng.
3. Giao điểm $Ox$, $Oy$ và các điểm do người dùng đánh dấu:
   - Tự động kiểm tra trùng lặp với cực trị.
   - Tự động căn chỉnh nhãn chống đè chữ.

## Success Criteria
- Miền tích phân hiển thị phẳng và thanh nhã giữa $a$ và $b$.
- Hàm phân thức bậc 1/1 hiển thị 2 đường tiệm cận nét đứt chuẩn SGK.
- Nhãn không bị đè vào nhau.

