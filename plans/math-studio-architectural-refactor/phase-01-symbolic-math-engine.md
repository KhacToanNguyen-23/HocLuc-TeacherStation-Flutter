# Phase 01: Symbolic Math CAS Engine (`math_cas.js`)

**Status:** Not Started  
**Target Files:**
- `plugins/math_studio/ui/core/math_cas.js`
- `scripts/test_math_cas.mjs`

---

## Technical Details

1. **Symbolic Differentiation & Evaluator:**
   - Xây dựng AST parser phân tích biểu thức toán học thành cây cú pháp trừu tượng (hoặc sử dụng module CAS toán học gọn nhẹ).
   - Định nghĩa quy tắc đạo hàm giải tích chuẩn mực:
     - $(x^n)' = n \cdot x^{n-1}$
     - $(u \pm v)' = u' \pm v'$
     - $(u \cdot v)' = u'v + uv'$
     - $(\frac{u}{v})' = \frac{u'v - uv'}{v^2}$
     - $(\sin u)' = u' \cdot \cos u$, $(\cos u)' = -u' \cdot \sin u$, $(\tan u)' = u'(1 + \tan^2 u)$
     - $(e^u)' = u' \cdot e^u$, $(\ln u)' = \frac{u'}{u}$

2. **Root & Extrema Finding (`findExtrema`, `findRoots`):**
   - Tìm tập xác định $D$ (loại trừ các điểm kỳ dị mẫu số $= 0$).
   - Tìm nghiệm $f'(x) = 0$:
     - Với đa thức bậc $\le 4$: Sử dụng công thức giải tích nghiệm chính xác (Cardano, Ferrari).
     - Với hàm phức tạp / lượng giác / siêu việt: Kết hợp chia khoảng và Newton-Raphson tự động tìm toàn bộ nghiệm trên khoảng quan sát $[-10, 10]$.
   - Xét dấu đạo hàm qua các nghiệm để phân loại chính xác: Cực đại (CĐ, $f'$ đổi dấu $+ \to -$), Cực tiểu (CT, $f'$ đổi dấu $- \to +$), hoặc điểm uốn.

3. **Definite Integral & Area:**
   - Tính $\int_a^b f(x)dx$ và $S = \int_a^b |f(x)|dx$ bằng thuật toán Gauss-Kronrod hoặc Simpson tích nghiêng chính xác tới 6 chữ số thập phân.

---

## Verification
- Viết `scripts/test_math_cas.mjs` kiểm thử 10 dạng hàm:
  - Bậc 3: $y = x^3 - 3x^2 + 2$
  - Trùng phương: $y = x^4 - 2x^2 - 1$
  - Bậc cao: $y = x^5 - 5x$
  - Lượng giác: $y = \sin(x)^2 + 1$
  - Hữu tỉ: $y = \frac{2x + 1}{x - 1}$, $y = \frac{x^2 - x + 1}{x - 1}$
  - Siêu việt: $y = x \cdot e^{-x}$, $y = \ln(x^2 + 1)$
- Tất cả các bài test đều phải đạt kết quả giải tích chính xác 100%.
