# Brainstorm: Kéo Thả Cực Trị Cho Mọi Hàm Số & Sửa Lỗi Ghim Lên Bảng

**Date:** 2026-10-26

## Ideas Explored
1. **Dynamic Translation & Scale (Biến đổi tịnh tiến & co giãn):**
   - Với 5 hàm SGK cơ bản (bậc 1, 2, 3, trùng phương, phân thức 1/1): Giữ nguyên thuật toán giải tích giải hệ chính xác.
   - Với hàm số bất kỳ / lượng giác / mũ cao (`'general'`): Khi kéo cực trị, tự động tịnh tiến toạ độ hàm số $y = f(x - \Delta x) + \Delta y$ hoặc cộng trừ offset hằng số $+ C$, đảm bảo 100% mọi hàm số đều phản hồi mượt mà và trực quan theo tay người dùng.
2. **Interactive Anchor Points (Khóa vị trí cực trị tự do):**
   - Kéo điểm tự do như marker trên đồ thị mà không làm biến dạng công thức gốc. Nhược điểm: không thay đổi công thức toán khi giáo viên muốn điều chỉnh tham số. (Bị loại bỏ do người dùng chọn Phương án 1).
3. **Đổi tên nút và chuẩn hóa xuất SVG ra bảng phấn:**
   - Thay đổi nút `[Xong]` thành `[📌 Ghim vào bảng]` với màu sắc và biểu tượng trực quan, hỗ trợ phím tắt `Ctrl + Enter`.
   - Sửa lỗi cú pháp XML sinh thẻ `<tspan>` chưa đóng trong hàm `generateGraphSvg` (nguyên nhân cốt lõi khiến `flutter_svg` từ chối render sticker đồ thị).

## User's Direction
- **Phương án 1 được chọn:** Tự động tịnh tiến & biến đổi công thức động khi kéo cực đại / cực tiểu của các hàm số phức tạp, hàm lượng giác và đa thức bậc cao.
- **Nút Ghim được chọn:** Đổi tên và thiết kế nút thành `📌 Ghim vào bảng` rõ ràng, khắc phục lỗi xuất SVG ra màn hình bảng phấn.

## Open Questions
- Không có câu hỏi còn vướng. Cả hai luồng hành vi đã được thống nhất cụ thể và có giải pháp kỹ thuật rõ ràng.

## Risks
1. **Rủi ro biểu thức công thức phức tạp khi tịnh tiến:** Khi nối chuỗi $+ C$ hoặc $- \Delta x$, cần chuẩn hóa format để biểu thức không bị sinh ra các dấu toán học kỳ lạ như `+ - 2` hoặc `+ 0`.
2. **Tương thích thẻ SVG với Flutter Canvas:** Đảm bảo thẻ `<tspan>` và các thuộc tính SVG luôn tuân thủ chuẩn XML nghiêm ngặt, vượt qua `flutter analyze` và các bài test unit.

