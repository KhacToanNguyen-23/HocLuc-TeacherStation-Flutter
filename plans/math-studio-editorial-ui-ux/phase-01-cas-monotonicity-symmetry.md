# Phase 01: CAS Engine Extension — Monotonicity & Symmetry

**Goal:** Mở rộng module giải tích số và hình học giải tích trong `plugins/math_studio/ui/core/math_cas.js` để tự động xác định các khoảng đơn điệu ($\nearrow, \searrow$), điểm uốn $U$, tâm đối xứng $I$, và trục đối xứng theo chuẩn SGK Toán 12.

---

## Scope & Target Files
- `plugins/math_studio/ui/core/math_cas.js`

---

## Detailed Implementation Tasks

1. **Task 1.1: Triển khai hàm `findMonotonicityIntervals(f, derFn, extrema, singularXs, bounds)`**
   - Thu thập các điểm tới hạn (nghiệm $f'(x) = 0$ và điểm gián đoạn $x \in singularXs$).
   - Sắp xếp và phân hoạch trục số thành các khoảng mở chuẩn SGK: $(-\infty; p_1), (p_1; p_2), \dots, (p_n; +\infty)$.
   - Chọn điểm kiểm tra đại diện (sample midpoint) để đánh giá dấu của $f'(x)$.
   - **Phòng thủ Edge Case**: Với các hàm có $f'(0) = 0$ nhưng đồng biến toàn miền (như $y = x^3$), nếu $f'(x_{\text{test}}) \approx 0$, lấy thêm các điểm kiểm tra phụ $x_{\text{test}} \pm 0.35$ để kết luận chính xác dấu đạo hàm trên toàn khoảng, tránh bỏ sót khoảng $(-\infty; +\infty)$.
   - Trả về danh sách khoảng đồng biến (`increasing`), khoảng nghịch biến (`decreasing`), và chuỗi tóm tắt sư phạm (`summary.fullText`).

2. **Task 1.2: Triển khai hàm `findInflectionAndSymmetry(f, ast, extrema, asymptotes)`**
   - **Điểm uốn $U(x_0; y_0)$**: Quét nghiệm đạo hàm cấp hai $f''(x) = 0$ sử dụng `secondDerivativeAt` và kiểm tra điều kiện đổi dấu qua lân cận $x_0 \pm 0.05$.
   - **Tâm đối xứng $I(x_0; y_0)$**:
     - *Hàm phân thức*: Lấy giao điểm của tiệm cận đứng và tiệm cận xiên/ngang, kiểm tra điều kiện đối xứng tâm: $\frac{f(x_0 + t) + f(x_0 - t)}{2} = y_0$.
     - *Hàm bậc ba*: Tâm đối xứng trùng với điểm uốn $U$.
   - **Trục đối xứng**: Kiểm tra tính đối xứng chẵn qua trục $Oy$ ($x = 0$) hoặc qua đường thẳng $x = x_0$ đối với hàm bậc bốn trùng phương và parabol bậc hai.

3. **Task 1.3: Tích hợp vào `analyzeFunction(rawExpr, bounds)`**
   - Gọi `findMonotonicityIntervals` và `findInflectionAndSymmetry`.
   - Bổ sung trường `monotonicity`, `inflectionPoints`, `centerOfSymmetry`, `axisOfSymmetry` vào đối tượng kết quả `analysis`.

---

## Verification & Criteria
- Chạy benchmark Node.js đối với các hàm số tiêu biểu:
  - Bậc 3: $y = x^3 - 3x \implies$ ĐB: $(-\infty; -1), (1; +\infty)$, NB: $(-1; 1)$, Điểm uốn/Tâm đối xứng: $I(0; 0)$.
  - Bậc 4 trùng phương: $y = x^4 - 2x^2 \implies$ Trục đối xứng: $x = 0$.
  - Phân thức nhất biến: $y = \frac{2x+1}{x-1} \implies$ TCĐ $x = 1$, TCN $y = 2$, Tâm đối xứng: $I(1; 2)$.
- Thời gian tính toán cho mỗi hàm số: $\le 3\text{ms}$.
