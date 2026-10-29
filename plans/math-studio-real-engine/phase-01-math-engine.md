# Phase 1: Engine toán (TDD, Node)

## Mục tiêu
Engine JS thuần, không DOM, chạy được trong Node, tính từ chính biểu thức nhập (không bảng tra theo hàm cụ thể). Dùng mathjs (Apache-2.0) + nerdamer (Apache-2.0).

## File
- `src/engine/parse.js`: chuẩn hoá nhập ("y=", "f(x)=", `^`, nhân ngầm `2x`, `sqrt`, `ln`, `e^x`) → compile qua mathjs; báo lỗi rõ ràng.
- `src/engine/derivative.js`: `mathjs.derivative` + `simplify`; xuất chuỗi hiển thị (unicode mũ) và hàm số học.
- `src/engine/analyze.js`: tập xác định, nghiệm y'=0 (quét + chia đôi, kiểm tra đổi dấu), cực trị, điểm uốn, tiệm cận đứng (điểm mà |f|→∞ qua quét + chia đôi), ngang (giới hạn số ±lớn), xiên (hệ số a,b từ giới hạn), khoảng đơn điệu.
- `src/engine/integrate.js`: nguyên hàm qua nerdamer; hàm không có biểu thức sơ cấp → `{kind:'none'}`; tích phân xác định số (Simpson thích nghi, xử lý điểm kỳ dị đầu mút).
- `src/engine/riemann.js`: tổng Riemann (trái/phải/giữa) trả danh sách cột.
- `src/engine/revolution.js`: V = π∫f²dx quanh Ox.
- `src/engine/bbt.js`: mô hình bảng biến thiên (các cột x, dấu y', chiều biến thiên, giá trị, điểm gián đoạn ‖).
- `engine/tests/engine.test.mjs`: dùng `node --test`.

## Tests viết trước (đáp án chuẩn tính tay)
Bộ hàm: `x^3-3x`, `2x^2-3x+1`, `(2x+1)/(x-1)`, `(x^2+x+1)/(x-1)`, `sin(x)`, `e^(-x^2)`, `sqrt(4-x^2)`, `ln(x)`.
- `2x^2-3x+1`: y' = `4x-3`; cực tiểu (0.75; -0.125); nghiệm 0.5 và 1. (tái hiện lỗi cũ: y' KHÔNG được còn `3x²-3`.)
- `x^3-3x`: y'=`3x^2-3`; cực đại (-1;2), cực tiểu (1;-2); điểm uốn (0;0); nguyên hàm `x^4/4 - 3x^2/2 + C`; tiếp tuyến tại x0=2 là `y = 9x - 16`; số nghiệm y=m: m=0→3, m=2→2, m=3→1, m=-0.5→3.
- `(2x+1)/(x-1)`: y' = `-3/(x-1)^2`; TCĐ x=1; TCN y=2; không cực trị.
- `(x^2+x+1)/(x-1)`: TCĐ x=1; TCX y=x+2; cực đại (1-√3; 3-2√3 ≈ -0.464), cực tiểu (1+√3; 3+2√3 ≈ 6.464).
- `sin(x)`: y'=`cos(x)`; cực trị tại π/2+kπ.
- `e^(-x^2)`: cực đại (0;1); TCN y=0; điểm uốn x=±1/√2.
- `sqrt(4-x^2)`: TXĐ [-2;2]; cực đại (0;2); y' không xác định tại ±2.
- `ln(x)`: TXĐ (0;+∞); TCĐ x=0; nguyên hàm `x ln x - x + C`.
- Riemann `sqrt(x)` [0,4]: tích phân chính xác 16/3 ≈ 5.3333; mode GIỮA n=50 sai ≤ 1%; mode TRÁI/PHẢI sai ≤ 3% (ghi rõ: tiêu chí 1% của spec áp dụng cho mode giữa — mặc định).
- Revolution `sqrt(x)` [0,4]: V = 8π ≈ 25.1327 (±0.01).
- Test "không bảng tra": quét mã nguồn `src/engine/` không chứa khoá hàm cụ thể (vd regex `x\^3`), và đổi hàm thì y' đổi (property test với ≥ 5 đa thức ngẫu nhiên so với đạo hàm số).
- Biểu thức sai cú pháp → lỗi có thông báo, không throw ra UI.

## Tiêu chí hoàn thành
`node --test plugins/math_studio/engine/tests/` xanh toàn bộ; output dán vào Session Notes.

