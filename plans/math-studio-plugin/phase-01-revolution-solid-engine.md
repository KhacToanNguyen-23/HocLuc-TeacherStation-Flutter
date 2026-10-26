# Phase 1: Thuật toán Khối tròn xoay 2.5D Siêu nhẹ ("Phát quay" quanh Ox)

**Goal:** Xây dựng mô-đun toán học và kết xuất vector SVG biến miền tích phân phẳng thành vật thể tròn xoay 3D (chiếc bình hoa, khối nón, lăng trụ tròn) theo hình học họa hình chiếu trục đo chuẩn SGK, siêu nhẹ không phụ thuộc WebGL/Three.js.

---

## Detailed Tasks

1. **Tạo mô-đun `plugins/math_studio/ui/render/revolution_solid_plotter.js`:**
   - Đầu vào: Hàm số $y = f(x)$, cận tích phân $[a, b]$, góc nhìn chiếu nghiêng $\alpha$ (mặc định $30^\circ$ theo SGK), tỷ lệ ép elip $\sin(\alpha) \approx 0.35$.
   - Lấy mẫu $N$ điểm dọc theo trục $Ox$ từ $a$ đến $b$.
   - Tính bán kính tại mỗi hoành độ: $r(x) = |f(x)|$.
   - Sinh đường sinh trên: $y_{top}(x) = y_0(x) + r(x)$.
   - Sinh đường sinh dưới: $y_{bot}(x) = y_0(x) - r(x)$.
   - Sinh các đường elip mặt cắt ngang (Cross-section Ellipses):
     - Elip đáy tại $x = a$ và $x = b$.
     - Các elip trung gian tại điểm uốn / cực trị của hàm số.
     - Phân định rõ nét liền (nửa trước nhìn thấy) và nét đứt mờ (nửa sau bị che khuất).
   - Tô màu dải gradient trong suốt (Wireframe mesh + Shaded volume) tạo hiệu ứng khối 3D chân thực như trong video của thầy Tuấn.

2. **Tích hợp vào `graph_plotter.js`:**
   - Thêm tham số tùy chọn `isRevolved: boolean` và `revolutionAngle: number`.
   - Khi `isRevolved === true`: Kích hoạt bộ vẽ khối tròn xoay chèn trực tiếp vào SVG đồ thị.

3. **Kiểm thử tự động:**
   - Tạo `scripts/test_revolution_solid.mjs` kiểm tra tính chính xác của các đường elip và thời gian sinh SVG ($\le 20$ ms).

