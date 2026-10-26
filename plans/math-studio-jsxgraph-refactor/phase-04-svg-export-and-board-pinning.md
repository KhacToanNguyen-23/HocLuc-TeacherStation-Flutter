# Phase 4: Kết Nối app.js & Luồng Ghim Lên Bảng (Studio Board)

## Goal
Kết nối toàn diện giữa JSXGraph Board với `app.js` và giữ nguyên tính tương thích ghim SVG lên bảng viết phấn.

## Requirements
1. `app.js`:
   - Gọi `renderJSXGraphBoard` trong `renderGraphOnly()`.
   - Lắng nghe thay đổi của input hàm số, cận tích phân, khung nhìn và cập nhật board mượt mà.
2. Xuất SVG ghim lên bảng (`insertToBoard`):
   - `generateGraphSvg` trả về chuỗi SVG chuẩn mực (có theme chalkboard khi ghim lên bảng đen).
   - Đảm bảo đồ thị khi chèn vào Studio Board hiển thị đầy đủ vector sắc nét.
3. Hỗ trợ hiển thị công thức $y = x^2 - 2$ với số mũ superscript trên thẻ huy hiệu góc trái.

## Success Criteria
- Nút "Xong" ghim SVG lên bảng hoạt động trơn tru.
- Nhập đổi hàm số trên `mathInput` cập nhật đồ thị tức thời.

