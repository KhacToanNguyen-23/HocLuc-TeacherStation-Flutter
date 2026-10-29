# Phase 3: Triển khai 3 Trang Chuyên sâu & Tương tác 2 Chiều

## Mục tiêu
Hiện thực hóa 3 trang chức năng trong `plugins/math_studio/ui/`:
- **Trang 1: Đồ thị & Khảo sát**: Ô nhập gọn gàng hiện ngay $y'$, thẻ kết quả giải tích, tương tác 2 chiều (kéo điểm $M(x_0)$ trượt tiếp tuyến, kéo đường $y=m$ biện luận nghiệm).
- **Trang 2: Bảng biến thiên (BBT)**: Vector SVG bảng xét dấu toàn màn hình chuẩn SGK.
- **Trang 3: Tích phân & Khối tròn xoay**: Thanh trượt số hình chữ nhật Riemann $n \in [4, 50]$, khối tròn xoay 3D render trực tiếp từ đồ thị với nét liền/nét đứt chuẩn SGK và xoay đa góc nhìn tự do.

## File tác động
- `plugins/math_studio/ui/index.html`
- `plugins/math_studio/ui/app.js`
- `plugins/math_studio/ui/style.css`
- `plugins/math_studio/ui/core/math_engine.js` (parser linh hoạt nhận diện mọi biểu thức, tính vi tích phân)
- `plugins/math_studio/ui/render/excalidraw_stage.js` (kết nối dữ liệu toán học vào canvas Excalidraw, nhãn chống đè chéo)
- `plugins/math_studio/ui/render/bbt_table.js` (render bảng biến thiên SGK)
- `plugins/math_studio/ui/render/solid_revolution.js` (quét mặt tròn xoay 3D với nét liền/nét đứt)

## Các bước triển khai
1. **Bộ giải tích tự do (`math_engine.js`)**:
   - Nhận chuỗi biểu thức $f(x)$ bất kỳ.
   - Tính đạo hàm $y' = f'(x)$, nghiệm $f'(x) = 0$, cực đại, cực tiểu, điểm uốn.
   - Tìm tiệm cận đứng (nghiệm mẫu), tiệm cận ngang ($\lim_{x\to\pm\infty}$), tiệm cận xiên.
   - Tìm nguyên hàm tổng quát $F(x) + C$.
2. **Trang 1 (Đồ thị & Khảo sát)**:
   - Header: Tab Switcher chuyển đổi 3 trang mượt mà.
   - Cột trái: Ô nhập $f(x)$ và $y'$ siêu gọn, thẻ đơn điệu & cực trị, thẻ tiệm cận, thẻ nguyên hàm.
   - Cột phải: Khung Excalidraw Canvas:
     - Kéo điểm $M(x_0)$ trên đường cong $\rightarrow$ tiếp tuyến xoay góc theo độ dốc tức thì.
     - Kéo đường thẳng $y = m$ lên xuống $\rightarrow$ đếm số giao điểm và cập nhật số liệu.
     - Tự động né nhãn chữ (collision offset) không bị đè lên trục hay đường cong.
3. **Trang 2 (Bảng biến thiên)**:
   - Render bảng 3 hàng $x, y', y$ với các mũi tên tăng giảm chuẩn SGK.
   - Tự động hiển thị các mốc vô cùng $-\infty, +\infty$, nghiệm và giá trị cực trị.
4. **Trang 3 (Tích phân & Khối tròn xoay)**:
   - Cận tích phân $[a, b]$, nút tìm giao điểm tự động.
   - Thanh trượt số hình chữ nhật Riemann $n \in [4, 50]$ minh họa các bậc thang khít dần vào đường cong.
   - Chế độ Khối tròn xoay 3D: Quét đường cong quanh trục $Ox$, phân tách nét liền (mặt ngoài) và nét đứt (mặt khuất phía sau), hỗ trợ giữ chuột xoay đa chiều góc nhìn (orbit tilt).

## Tiêu chí hoàn thành (Verification)
- Chuyển đổi mượt mà giữa 3 trang.
- Nhập các hàm phức tạp (bậc 3, bậc 4, phân thức, sin, e^x) đều tính đúng $y'$ và vẽ đường cong chuẩn.
- Thao tác kéo thả điểm $M$ và đường $y=m$ phản hồi nhạy bén (< 16ms).
- Kéo thanh trượt Riemann $n$ cập nhật đúng số cột hình chữ nhật trên canvas.
- Khối tròn xoay hiển thị đúng quy tắc nét liền/nét đứt SGK và xoay được góc nhìn 3D.

