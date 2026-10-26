# Phase 02: Single JSXGraph Board & WYSIWYG Live DOM SVG Serializer

**Status:** Not Started  
**Target Files:**
- `plugins/math_studio/ui/export/board_exporter.js`
- `plugins/math_studio/ui/render/graph_plotter.js`
- `plugins/math_studio/ui/app.js`

---

## Technical Details

1. **Elimination of Hand-Crafted `generateGraphSvg` String Concatenation:**
   - Xóa bỏ việc tự viết code ghép nối thẻ `<line>`, `<circle>`, `<text>` thủ công (vốn là nguyên nhân gây lệch vạch số, mất trục và đứt gãy đường cong).
   - Thống nhất: JSXGraph là nơi DUY NHẤT vẽ đồ thị.

2. **`export/board_exporter.js` (Live DOM SVG Serializer):**
   - Khi người dùng bấm `[📌 Ghim vào bảng]`:
     1. Lấy trực tiếp phần tử `<svg>` đang hiển thị trong `#graphContainer`.
     2. Tạo một bản deep-clone của SVG này.
     3. Đọc toạ độ `viewBox` chuẩn và thêm thuộc tính `preserveAspectRatio="xMidYMid meet"`.
     4. Inline toàn bộ style đồ họa cần thiết cho theme Chalkboard:
        - Nền trong suốt (`fill="transparent"`).
        - Trục toạ độ và tick mark chuyển sang màu trắng phấn (`#ffffff`, `stroke-width: 1.5`).
        - Nhãn toạ độ và số trục chuyển sang font chữ đậm rõ nét trên bảng đen.
        - Đường cong hàm số giữ màu sắc rực rỡ chuẩn SGK (đỏ phấn `#f87171` hoặc đỏ tươi `#dc2626`).
        - Vùng tích phân tô bóng bán trong suốt (`rgba(220, 38, 38, 0.22)`).
     5. Kiểm tra tính toàn vẹn XML (không có thẻ nào bị unclosed) bằng hàm kiểm tra DOM.
     6. Trả về chuỗi SVG hoàn chỉnh và gửi qua SDK RPC `window.HocLuc.board.insertAnnotation`.

---

## Verification
- Ghim thử các đồ thị phức tạp: đồ thị hàm bậc 3, hàm phân thức có tiệm cận, miền tích phân tô màu $S$.
- So sánh pixel-for-pixel giữa màn hình xem trước trong Studio và sticker xuất hiện trên bảng chalkboard: Hoàn toàn đồng nhất 100%.
