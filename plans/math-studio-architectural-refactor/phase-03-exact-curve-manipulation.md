# Phase 03: Exact Inverse Mathematical Manipulation

**Status:** Not Started  
**Target Files:**
- `plugins/math_studio/ui/core/curve_manipulator.js`
- `plugins/math_studio/ui/app.js`
- `scripts/test_curve_manipulator.mjs`

---

## Technical Details

1. **Analytical Inverse Solver:**
   - Thay vì các phép nối chuỗi thủ công, kết nối trực tiếp với Symbolic CAS Engine từ Phase 1:
   - Khi kéo một điểm cực đại hoặc cực tiểu $(x_0, y_0)$ đến vị trí mới $(x_1, y_1)$:
     - Điều kiện biên toán học bắt buộc:
       1. $f(x_1) = y_1$ (đồ thị phải đi qua điểm mới).
       2. $f'(x_1) = 0$ (điểm mới phải là điểm cực trị của hàm số).
     - Với hàm đa thức bậc 3 ($y = ax^3 + bx^2 + cx + d$):
       - Giữ nguyên điểm cực trị còn lại $(x_2, y_2)$ và tâm đối xứng uốn, giải hệ phương trình tuyến tính 4 ẩn $\{a, b, c, d\}$ để tìm chính xác phương trình mới.
     - Với hàm trùng phương bậc 4 ($y = ax^4 + bx^2 + c$):
       - Nếu kéo điểm uốn/cực trị tại $x = 0$: thay đổi $c = y_1$.
       - Nếu kéo 2 cực trị đối xứng: giải hệ tìm $a, b$ tương ứng.
     - Với hàm lượng giác & tổng quát ($y = A \cdot \sin(\omega x + \varphi) + C$):
       - Giải tìm biên độ $A$ và độ nâng trục $C$ sao cho đạt cực trị tại $(x_1, y_1)$ chuẩn xác 100%.

2. **Magnetic Grid Snapping:**
   - Hỗ trợ bắt dính (snap) các toạ độ kéo về các số nguyên hoặc phân số nửa bước đẹp ($0.5, 1.5, 2, 2.5$) giúp bài giảng luôn gọn gàng, chuẩn SGK.

---

## Verification
- Chạy `node scripts/test_curve_manipulator.mjs`:
  - Kéo cực trị bậc 3, bậc 4, phân thức, lượng giác $\sin(x)^2 + 1$.
  - Đảm bảo nghiệm $f'(x_1) = 0$ và $f(x_1) = y_1$ thỏa mãn với sai số $\le 10^{-5}$.

