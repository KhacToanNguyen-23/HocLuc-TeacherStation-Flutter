# Phase 2: Exact Calculus Solver & Pedagogical BBT Generator

**Plan:** [plan.md](plan.md)  
**Spec Stories:** [P1] US-01 | **Requirements:** FR-01, FR-02, FR-03, FR-04, NFR-01

---

## 1. Mục Tiêu Phase 2
- Xây dựng bộ máy giải tích đại số chính xác (Exact Calculus Engine) bằng JavaScript thuần:
  - `ui/core/fraction.js`: Hỗ trợ lớp phân số chính xác `Fraction(num, den)` với các phép toán cộng, trừ, nhân, chia, rút gọn ước chung lớn nhất (GCD), định dạng LaTeX và chuỗi toán học chuẩn SGK (ví dụ: `-1/3`, `5/2`). Hỗ trợ hiển thị căn thức dạng $\frac{a \pm \sqrt{\Delta}}{b}$.
  - `ui/core/calculus_solver.js`: Khảo sát giải tích đóng cho 4 họ hàm THPT theo chương trình GDPT 2018:
    1. **Bậc ba: $y = ax^3 + bx^2 + cx + d$ ($a \neq 0$)**:
       - $y' = 3ax^2 + 2bx + c$. Biệt thức $\Delta' = b^2 - 3ac$.
       - Nếu $\Delta' \le 0$: Không có cực trị, $y'$ cùng dấu với $a$ trên toàn $\mathbb{R}$.
       - Nếu $\Delta' > 0$: 2 điểm cực trị $x_1 < x_2$. Xác định cực đại, cực tiểu theo dấu $a$.
       - Điểm uốn: $x_U = -\frac{b}{3a}, y_U = y(x_U)$.
       - Giới hạn: $\lim_{x\to \pm\infty} y$.
    2. **Trùng phương: $y = ax^4 + bx^2 + c$ ($a \neq 0$)**:
       - $y' = 4ax^3 + 2bx = 2x(2ax^2 + b)$.
       - Nếu $-\frac{b}{2a} \le 0$: 1 điểm cực trị tại $x = 0$.
       - Nếu $-\frac{b}{2a} > 0$: 3 điểm cực trị tại $x = 0$ và $x = \pm\sqrt{-\frac{b}{2a}}$.
       - Trục đối xứng: $x = 0$.
    3. **Phân thức bậc nhất/bậc nhất: $y = \frac{ax + b}{cx + d}$ ($c \neq 0, ad - bc \neq 0$)**:
       - Tập xác định: $D = \mathbb{R} \setminus \{x_0\}$ với $x_0 = -\frac{d}{c}$.
       - Đạo hàm: $y' = \frac{ad - bc}{(cx + d)^2}$. Luôn âm hoặc dương trên từng khoảng $(-\infty, x_0)$ và $(x_0, +\infty)$.
       - Tiệm cận đứng: $x = -\frac{d}{c}$.
       - Tiệm cận ngang: $y = \frac{a}{c}$.
       - Tâm đối xứng: $I\left(-\frac{d}{c}, \frac{a}{c}\right)$.
    4. **Phân thức bậc hai/bậc nhất: $y = \frac{ax^2 + bx + c}{px + q}$ ($a \neq 0, p \neq 0$)**:
       - Tập xác định: $D = \mathbb{R} \setminus \{x_0\}$ với $x_0 = -\frac{q}{p}$.
       - Tiệm cận đứng: $x = -\frac{q}{p}$.
       - Tiệm cận xiên: $y = \alpha x + \beta$ với $\alpha = \frac{a}{p}, \beta = \frac{bp - aq}{p^2}$.
       - Đạo hàm: Nghiệm của $y'=0$ và tính nhanh cực trị: $y_{CT/CĐ} = \frac{2ax_i + b}{p}$.
- Xây dựng bộ sinh Bảng biến thiên SVG vector sư phạm (`ui/render/bbt_generator.js`):
  - Dòng $x$: $-\infty$, các nghiệm $x_i$, điểm gián đoạn $x_0$, $+\infty$ sắp xếp tăng dần.
  - Dòng $y'$: số $0$ tại nghiệm, vạch đôi `||` tại điểm gián đoạn, dấu `+`, `-` chuẩn xác.
  - Dòng $y$: Mũi tên vector $\nearrow, \searrow$. Đầu mũi tên đặt đúng cao độ tương đối: $-\infty$ ở sát đáy hàng, cực tiểu ở khoảng 25% chiều cao, cực đại ở khoảng 75% chiều cao, $+\infty$ ở đỉnh hàng. Tại điểm gián đoạn có vạch đôi `||` xuyên suốt.
  - Nền trong suốt hoặc nền bảng đen dịu mắt, xuất ra chuỗi XML `<svg>` chuẩn.

---

## 2. Tiêu Chí Nghiệm Thu (Acceptance Criteria)
- [ ] Tính đúng và lập chuẩn xác Bảng biến thiên cho 5 hàm kiểm thử bắt buộc:
  1. $y = x^3 - 3x^2 + 2$ (2 cực trị: $CĐ(0, 2), CT(2, -2)$).
  2. $y = x^3 + 3x$ (hàm đồng biến trên $\mathbb{R}$, không cực trị).
  3. $y = x^4 - 2x^2 - 1$ (3 cực trị: $x=0, x=\pm 1$).
  4. $y = \frac{2x+1}{x-1}$ (TCĐ $x=1$, TCN $y=2$, $y' < 0$ trên từng khoảng).
  5. $y = \frac{x^2 - x + 1}{x - 1}$ (TCĐ $x=1$, TCX $y=x$, 2 cực trị $x=0, x=2$).
- [ ] Thời gian tính toán và sinh SVG Bảng biến thiên $< 30$ms.
- [ ] Chuỗi SVG sinh ra hợp lệ, hiển thị sắc nét khi phóng to thu nhỏ.
