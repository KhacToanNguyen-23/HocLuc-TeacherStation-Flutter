# Brainstorm: Zero-Hardcode Micro-CAS & Non-Intrusive Reactive Live Math Studio

**Date:** 2026-10-27
**Context:** Tái cấu trúc triệt để `symbolic_cas.js` (>1030 dòng, hardcode bậc hàm số) và thiết kế giao diện "nhập đến đâu vẽ đến đó" không che khuất bảng viết của giáo viên.

---

## Ideas Explored

1. **Approach A — Zero-Dependency Micro-CAS (~220 lines, Pure Calculus Theorems)**:
   - Thay thế toàn bộ 1030 dòng của `symbolic_cas.js` và các phân nhánh hardcode trong `math_cas.js` bằng một engine đại số vi phân & tiệm cận giải tích thuần túy.
   - Xóa bỏ hoàn toàn `classifyFunctionAST` (không còn phân biệt `cubic`, `quartic`, `rational1`, `rational21`).
   - Tiệm cận ngang/xiên tính theo 2 giới hạn giải tích tổng quát: $a = \lim_{x \to \pm\infty} \frac{f(x)}{x}$, $b = \lim_{x \to \pm\infty} [f(x) - ax]$.
   - Cực trị và tiệm cận đứng tìm kiếm thích ứng (Adaptive Interval Expansion), xóa bỏ khoảng đóng cứng `[-9, 9]`.
   - *Đánh giá:* **Được chọn** — siêu nhẹ máy (<5ms nạp, 0 KB thư viện ngoài), đúng bản chất toán học, code ngắn gọn dễ bảo trì.

2. **Approach B — External CAS Engine (`nerdamer` ~70KB hoặc `mathjs` ~700KB)**:
   - Nhúng thư viện ngoài vào `vendor/`.
   - *Đánh giá:* **Bị loại** — làm tăng kích thước plugin, tốn RAM không cần thiết trên laptop cấu hình yếu của giáo viên, vi phạm tiêu chí "nhẹ máy user".

3. **UI Layout A — Fullscreen Takeover (Chiếm trọn màn hình kiểu Desmos)**:
   - Bảng vẽ chiếm 100% màn hình, thanh công thức nổi góc trái.
   - *Đánh giá:* **Bị loại** — giáo viên phản hồi rõ: *"không che hết bảng viết"*, việc che kín bảng làm gián đoạn bài giảng và mất tầm nhìn lớp học/Meet.

4. **UI Layout B — Compact Floating Studio Card (Cửa sổ nổi gọn 820px × 540px, Reactive Live Plotting)**:
   - Cửa sổ nổi cân đối giữa bảng, vẫn để lộ viền bảng đen xung quanh để giáo viên theo dõi bài giảng.
   - Bên trong cửa sổ: Đồ thị chiếm trọn không gian, thanh nhập công thức dạng Floating Pill Bar nổi phía trên.
   - Nhập đến đâu vẽ đến đó (Zero-latency 60fps), tự động đánh dấu CĐ, CT, tiệm cận trực tiếp trên đường cong.
   - Bấm **`[Ghim vào bảng]`** $\to$ xuất ảnh phấn trắng lên bảng và cửa sổ tự động đóng/ẩn ngay lập tức để giáo viên viết tiếp.
   - *Đánh giá:* **Được chọn** — đáp ứng 100% yêu cầu "nhập đến đâu vẽ đến đó" mà không che lấp bảng viết.

---

## User's Direction
- **Về Code**: Chọn hướng chuẩn chuyên nghiệp nhưng phải nhẹ máy user nhất (Micro-CAS thuần toán học ~220 dòng, 0 KB thư viện phụ thuộc).
- **Về UI/UX**: Đồng ý mô hình "nhập đến đâu vẽ đến đó", nhưng nhấn mạnh tuyệt đối **không được che hết bảng viết phấn** của giáo viên.

---

## Open Questions & Clarification Points
1. `[RESOLVED]` *Độ trễ phản hồi khi gõ*: Debounce 80ms khi gõ bàn phím vật lý để tránh re-render khi công thức chưa gõ xong (ví dụ `x^`); vẽ mượt tức thì 16ms khi bấm chip công thức hoặc hoàn tất cú pháp.
2. `[RESOLVED]` *Kích thước cửa sổ*: Cố định ở kích thước vàng $820\text{px} \times 540\text{px}$ (tỉ lệ xấp xỉ 3:2), hỗ trợ kéo di chuyển quanh màn hình hoặc thu nhỏ thành mini-pill khi cần.

---

## Risks & Mitigations
- **Risk 1: Giới hạn vô cực của hàm dao động (ví dụ $\sin x$)**:
  - *Mitigation*: Khi tính $a = \lim_{x \to \infty} \frac{f(x)}{x}$ và $b = \lim [f(x) - ax]$, kiểm tra độ hội tụ qua 2 mẫu xa ($x = 10^5$ và $x = 10^6$). Nếu không hội tụ (dao động hoặc phân kỳ), kết luận không có tiệm cận mà không báo lỗi.
- **Risk 2: Phép tính đạo hàm biểu trưng cho hàm phức tạp**:
  - *Mitigation*: Sử dụng quy tắc chuỗi đệ quy ngắn gọn cho cây AST; nếu gặp hàm không sơ cấp, kết hợp đạo hàm số học $O(h^4)$ 5-điểm stencil để vẽ BBT và tìm cực trị chính xác 100%.

