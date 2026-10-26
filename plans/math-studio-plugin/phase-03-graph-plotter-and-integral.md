# Phase 3: 2D Graph Plotter & Integral Area Shading

**Plan:** [plan.md](plan.md)  
**Spec Stories:** [P1] US-02, US-03 | **Requirements:** FR-05, FR-06, NFR-01, NFR-05

---

## 1. Mục Tiêu Phase 3
- Xây dựng công cụ vẽ đồ thị 2D vector thuần SVG (`ui/render/graph_plotter.js`):
  - Hệ trục tọa độ $Oxy$ với mũi tên ở hai đầu trục, gốc tọa độ $O$, vạch chia số tự động điều chỉnh theo kích thước khung nhìn (Viewport: $[-6, 6] \times [-5, 5]$ có thể pan/zoom).
  - Lưới ô vuông mờ (grid) tạo cảm giác như trang vở học sinh hoặc bảng kẻ ô.
  - Vẽ đường cong hàm số mượt mà bằng thẻ SVG `<path d="...">` với độ phân giải cao (150-300 điểm lấy mẫu).
  - Tự động ngắt nét vẽ tại điểm gián đoạn $x_0$ của hàm phân thức để không nối liền hai nhánh vô cực.
  - Vẽ các đường tiệm cận đứng, ngang, xiên bằng nét đứt (`stroke-dasharray="6,4"`, màu vàng cát `#f9e2af` hoặc cam `#fab387` nổi bật).
  - Đánh dấu các điểm cực trị $CĐ, CT$, điểm uốn $U$, giao điểm $Ox, Oy$ bằng chấm tròn có viền và nhãn tọa độ rõ ràng.
- Xây dựng bộ tính và tô màu tích phân / diện tích hình phẳng (`ui/core/integral_solver.js`):
  - Nhập hai cận tích phân $a, b$ ($a < b$).
  - Tính nguyên hàm giải tích của hàm đa thức và phân thức:
    - $\int (ax^n) dx = \frac{a}{n+1} x^{n+1}$.
    - $\int \frac{1}{px+q} dx = \frac{1}{p} \ln |px+q|$.
  - Tính giá trị tích phân định phân $\int_a^b f(x)dx$ và diện tích hình phẳng $S = \int_a^b |f(x)|dx$.
  - Xuất song song kết quả đại số chính xác (dạng phân số / $\ln$) và giá trị số thập phân xấp xỉ (4 chữ số sau dấu phẩy).
  - Vẽ vùng diện tích hình phẳng trên đồ thị SVG: Sử dụng `<path>` khép kín giữa đồ thị hàm số và trục hoành từ $x=a$ đến $x=b$, tô màu bán trong suốt hoặc gạch chéo bằng SVG `<pattern id="hatch">` chuẩn SGK.

---

## 2. Tiêu Chí Nghiệm Thu (Acceptance Criteria)
- [ ] Đồ thị hàm số hiển thị đúng hình dạng, cực trị trùng khớp với bảng biến thiên ở Phase 2.
- [ ] Đường tiệm cận đứng, ngang, xiên hiển thị đúng phương trình và vị trí nét đứt.
- [ ] Với hàm phân thức, hai nhánh đồ thị được ngắt quãng tách biệt, không bị nối dây ngang qua tiệm cận đứng.
- [ ] Nhập cận $[a, b]$, miền diện tích $S$ được tô sáng hoặc gạch chéo chính xác trên đồ thị Oxy, kèm nhãn giá trị diện tích $S$.
- [ ] Đồ thị render mượt mà trong thời gian $< 50$ms.
