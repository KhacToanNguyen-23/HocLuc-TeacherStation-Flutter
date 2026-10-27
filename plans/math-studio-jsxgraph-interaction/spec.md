# Spec: Tối Ưu Tương Tác Kéo Thả & Khử Mờ Trục Đồ Thị JSXGraph

## 1. Problem Statement
Sau khi tích hợp JSXGraph, xuất hiện 4 điểm yếu về mặt tương tác và hiển thị sư phạm:
1. Trục hoành $Ox$ bị mờ và dày đặc vạch phụ li ti như thước kẻ chia milimet, gây khó nhìn số.
2. Không kéo được các điểm cực trị do bị gán `fixed: true`.
3. Kéo mút cận tích phân $a, b$ bị giật, giá trị mút bị lệch với ô input phía trên (ví dụ đồ thị ghi $3.4$ nhưng ô input là $4.2$).
4. JSXGraph hiển thị nhãn $\int = \text{giá trị}$ đại số có dấu (âm/dương), lệch với bản chất bài toán tính diện tích hình phẳng SGK ($S = \int |f(x)|dx$).

## 2. Requirements & User Stories

### P1: Khử Mờ Trục Tọa Độ SGK (Crisp Axes)
- **US1.1:** Tắt hoàn toàn vạch phụ li ti (`minorTicks: 0`, `insertTicks: false`). Chỉ giữ các vạch số nguyên chính cách nhau theo `tickStepX`, `tickStepY`.
- **US1.2:** Chữ số trên trục $Ox, Oy$ hiển thị với cỡ chữ 12px, font-weight 600, màu tối sắc nét `#0F172A` (chế độ sáng) và `#FFFFFF` (chế độ bảng phấn), áp dụng `-webkit-font-smoothing: antialiased`.

### P1: Tương Tác Mút Tích Phân & Tính Diện Tích SGK (Reactive Integral Bounds)
- **US2.1:** Kéo mút $a, b$ mượt mà 60 FPS mà không destroy / rebuild board giữa chừng.
- **US2.2:** Khi kéo glider $a$ hoặc $b$, giá trị trong ô input `boundAInput`, `boundBInput` và huy hiệu diện tích $S$ cập nhật tức thời theo thời gian thực.
- **US2.3:** Hỗ trợ hít nam châm (magnetic snap) vào bước 0.5 khi kéo gần số nguyên hoặc nửa nguyên.
- **US2.4:** Ẩn hoàn toàn nhãn `\int = ...` có dấu của JSXGraph (`withLabel: false`). Luôn tính diện tích theo công thức hình phẳng tuyệt đối: $S = \int_a^b |f(x)| dx$.

### P1: Mở Khóa Kéo Cực Trị Nắn Đồ Thị 2 Chiều (Interactive Curve Fitting)
- **US3.1:** Điểm cực trị cho phép kéo thả (`fixed: false`).
- **US3.2:** Khi giáo viên kéo điểm cực trị, hệ thống tính toán lại hàm số qua `computeFormulaFromDrag` và cập nhật tức thời vào `mathInput.value`.

### P1: Đảm Bảo Kiểm Thử & Đóng Gói
- **US4.1:** Tất cả 5 test suites chạy thành công 100%.
- **US4.2:** 12 Bất biến kiến trúc của dự án đạt 12/12 PASS.
- **US4.3:** Đóng gói `plugins/math_studio.hlep` đồng bộ 100%.

## 3. Success Criteria
- Trục $Ox, Oy$ hiển thị rõ ràng từng con số, 0% hiện tượng mờ nhòe.
- Kéo mút $a, b$ mượt mà, giá trị trên đồ thị khớp 100% với ô input phía trên.
- Kéo điểm cực đại/cực tiểu làm thay đổi dáng điệu đường cong tức thời.
- Nhãn $\int = \text{âm}$ biến mất hoàn toàn, thay bằng diện tích $S$ dương chuẩn SGK.

