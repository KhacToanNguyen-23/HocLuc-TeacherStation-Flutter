# Phase 03: Bidirectional Linking, Zero-Lag Wiring & CI Verification

**Goal:** Hoàn thiện cơ chế tương tác hai chiều giữa Inspector và đồ thị JSXGraph, tối ưu luồng debounce, đóng gói plugin và vượt qua toàn bộ cổng kiểm thử kiến trúc CI.

---

## Scope & Target Files
- `plugins/math_studio/ui/app.js`
- `plugins/math_studio/ui/board/graph_board.js`
- `plugins/math_studio/ui/core/store.js`
- `plugins/math_studio.hlep`

---

## Detailed Implementation Tasks

1. **Task 3.1: Mở rộng `renderSpecialPointsList` trong `app.js`**
   - Render đầy đủ 5 phân mục dữ liệu từ `analysis`:
     - Render các thẻ khoảng đơn điệu với icon $\nearrow, \searrow$.
     - Render điểm cực trị với huy hiệu $CĐ, CT$.
     - Render điểm uốn $U$, tâm đối xứng $I$ với nhãn giải thích hình học.
     - Render tiệm cận và giao trục $Ox, Oy$.
   - Mỗi hàng được gán thuộc tính `data-coord-x`, `data-coord-y` để phục vụ tương tác.

2. **Task 3.2: Triển khai tương tác hai chiều trong `graph_board.js` & `app.js`**
   - Bổ sung hàm `highlightPointOnBoard(containerId, x, y)` trong `graph_board.js`:
     - Kiểm tra vị trí điểm; nếu nằm ngoài khung nhìn thì pan mượt mà (smooth animate pan).
     - Kích hoạt class hiệu ứng nhấp nháy phát quang (`.sgk-point-pulsing`) trên SVG circle tương ứng.
   - Bắt sự kiện click trên `.ext-row` trong `app.js` để gọi `highlightPointOnBoard`.
   - Bắt sự kiện click điểm trên JSXGraph canvas để tự động cuộn (scroll-into-view) và highlight dòng tương ứng trên Inspector.

3. **Task 3.3: Tối ưu phản hồi gõ lệnh & Zero-Lag**
   - Giữ nguyên cơ chế In-Place JSXGraph Update (< 1ms) cho đổi màu nét và toggle điểm.
   - Debounce gõ phím biểu thức ở mức tối ưu 80ms, trong khi text input và preview công thức STIX Math phản hồi tức thì 0ms.

4. **Task 3.4: Đóng gói plugin và vượt qua các cổng kiểm thử CI**
   - Kiểm tra cú pháp ES Module của toàn bộ các file JS qua Node.js (0 lỗi).
   - Chạy `node scripts/package_plugin.mjs math_studio` để cập nhật `plugins/math_studio.hlep`.
   - Chạy `node scripts/validate_plugins.mjs` (đạt chuẩn Schema v2.1).
   - Chạy `flutter test test/architecture_test.dart` (12/12 passing invariants).
   - Chạy `flutter analyze --no-fatal-infos` (0 errors, 0 warnings).

---

## Verification & Criteria
- Click điểm trên danh sách $\implies$ điểm trên đồ thị phóng to phát sáng trong < 16ms.
- Toàn bộ cổng CI vượt qua 100%.

