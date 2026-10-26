# Brainstorm: Đồ Thị Biến Dạng & Uốn Lượn Động Theo Cực Trị (Dynamic Curve Morphing)

**Date:** 2026-10-26

## Ideas Explored
1. **Phương án A (Dynamic Reactive Evaluation - Khuyên dùng):**
   - Đổi hàm của đường cong `functiongraph` trong JSXGraph sang dạng getter động: `(x) => currentAnalysis.eval(x)`.
   - Khi kéo điểm cực trị, bộ giải nghịch đảo `computeFormulaFromDrag` tính lại hàm số tức thời, cập nhật `currentAnalysis` và kích hoạt `board.update()`.
   - Kết quả: Đỉnh của đường cong dính chặt 100% vào con trỏ chuột/chấm tròn xanh, đường cong uốn lượn mềm mại theo ngón tay kéo, nhãn tọa độ và thẻ công thức tự động nhảy số theo thời gian thực.
2. **Phương án B (Vertex Form Constraints):**
   - Ràng buộc trực tiếp phương trình Parabol theo tọa độ $CT(h, k)$: $y = a(x - h)^2 + k$.
   - Giới hạn: Chỉ tối ưu cho hàm bậc 2, khó mở rộng cho hàm bậc 3 và bậc 4.

## User's Direction
Người dùng chọn **Phương án A**:
- Khi di chuyển cực đại / cực tiểu, đường cong đồ thị màu đỏ bắt buộc phải thay đổi và uốn lượn theo ngay lập tức.
- Điểm cực trị không bao giờ được tách rời khỏi đường cong.
- Nhãn tọa độ và công thức phải nhảy số đồng bộ tức thì.

## Technical Root Causes Identified
1. **Đường cong bị đóng băng:** `renderJSXGraphBoard` tạo `functiongraph` với một hàm closure tĩnh lưu `analysis.eval` ban đầu, không truy xuất đến `currentAnalysis` mới khi kéo.
2. **Nhãn cực trị bị tĩnh:** `extPt` được đặt thuộc tính `name` là chuỗi cố định `CT (0; -2)`, không dùng hàm động `() => ...` theo `extPt.X()` và `extPt.Y()`.
3. **Thẻ công thức góc trái tĩnh:** Tạo bằng thẻ text cố định lúc khởi tạo board, không liên kết động với công thức hàm số mới.

## Next Steps
Chuyển sang lập kế hoạch `/bb-plan` và triển khai `/bb-cook`.

