# Phase 1: Zero-Dependency Symbolic CAS Engine (`symbolic_cas.js` & `math_cas.js`)

## Context & Objectives
Triệt tiêu hoàn toàn hardcode trong giải tích toán học bằng việc tự động hóa vi phân ký hiệu (Symbolic Differentiation) cho mọi hàm số, sinh ra chuỗi hiển thị $y' = f'(x)$ chính xác tuyệt đối, đồng thời kết hợp với bộ giải nghiệm và tiệm cận tổng quát trong `math_cas.js`.

## Scope of Work
1. Tạo module `plugins/math_studio/ui/core/symbolic_cas.js`:
   - Tokenizer & AST Recursive Descent Parser cho biểu thức toán học.
   - Các quy tắc vi phân:
     - Đạo hàm hàm lũy thừa: $(x^n)' = n x^{n-1}$
     - Đạo hàm tổng/hiệu: $(u \pm v)' = u' \pm v'$
     - Đạo hàm tích: $(u \cdot v)' = u'v + uv'$
     - Đạo hàm thương: $(u/v)' = (u'v - uv')/v^2$
     - Đạo hàm hàm hợp lượng giác: $\sin(u)' = u'\cos(u)$, $\cos(u)' = -u'\sin(u)$, $\tan(u)' = u'(1+\tan^2(u))$
     - Đạo hàm hàm mũ/logarit/căn thức: $(e^u)' = u'e^u$, $(\ln(u))' = u'/u$, $(\sqrt{u})' = u'/(2\sqrt{u})$
   - Bộ rút gọn đại số (Algebraic Simplifier): loại bỏ $0 \cdot u$, $1 \cdot u$, $0 + u$, $u^1$, $u^0$.
   - Hàm `diff(expr)` trả về chuỗi công thức đạo hàm đẹp.
2. Nâng cấp `plugins/math_studio/ui/core/math_cas.js`:
   - Tích hợp `diff(expr)` để tự động gán `derLatex: "y' = " + diff(cleanExpr)`.
   - Kết hợp tìm nghiệm giải tích và số học lai cho $f'(x) = 0$ trên mọi miền xác định.
3. Viết test runner độc lập: `scripts/test_symbolic_cas.mjs`.

## Verification Commands
- `node scripts/test_symbolic_cas.mjs` (Phải pass 100% cho đa thức, lượng giác, phân thức, căn thức).
- `node scripts/test_math_cas.mjs` (Pass 5/5).

