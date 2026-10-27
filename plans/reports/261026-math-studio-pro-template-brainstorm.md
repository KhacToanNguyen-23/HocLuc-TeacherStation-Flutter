# Brainstorm: Nâng Cấp Template Đồ Thị Chuẩn Pro (Hybrid Desmos + SGK)

**Date:** 2026-10-26

## Bối cảnh & Điểm yếu của Template cũ
Dựa trên ảnh chụp thực tế màn hình của người dùng (`media_1792976477909_de938859.png`):
1. **Chữ số trục bị mờ căm và nhợt nhạt:** Font 9px màu xám mờ `#526984` bị nhòe pixel trên màn hình hiện đại.
2. **Xung đột đè chữ nặng nề (Text Collision):** Đỉnh cực tiểu bị đè chồng 2 lớp chữ `CT(0, -2)` và nhãn tọa độ; trên trục Ox nhãn nghiệm `-1.4` và mút tích phân `a = -1` dính vào nhau gây rối mắt.
3. **Miền tích phân kiểu gạch chéo CAD thô:** Sọc đỏ 45° nét dày trông giống bản vẽ kỹ thuật cũ, làm thô và che lấp đường cong đồ thị.
4. **Công thức góc trên viết dạng code thô:** Hiển thị `y = x^2 - 2` bằng text thô có dấu mũ `^`, không đạt chuẩn toán học.

## Các giải pháp đã phân tích
- **Phong cách 1 (Thuần Desmos):** Số trục to rõ 12px, nền tích phân trong suốt hiện đại (không gạch sọc), ẩn nhãn tĩnh và chỉ hiện tooltip nổi khi nhấp/hover.
- **Phong cách 2 (Thuần SGK Việt Nam):** Đồ thị sư phạm kinh điển với đường gióng nét đứt vuông góc từ cực trị xuống 2 trục $Ox, Oy$, mút cận tích phân rõ ràng.
- **Phong cách 3 (Hybrid Sư phạm Hiện đại — Người dùng chọn):**
  - Giữ nét đồ họa sắc sảo, chống nhòe và bảng màu trong suốt thanh nhã chuẩn Desmos.
  - Sử dụng hệ thống **đường gióng nét đứt SGK** và căn chỉnh offset thông minh để triệt tiêu 100% hiện tượng đè chữ.
  - Render công thức toán chuẩn superscript ($y = x^2 - 2$) và các chấm điểm tương tác chuẩn vector cao cấp.

## Hướng đi đã chốt (User's Direction)
- Triển khai toàn diện theo **Hướng 3 (Hybrid Desmos + SGK)**: Nâng cấp toàn bộ render engine SVG của `graph_plotter.js` và `style.css` lên chuẩn Pro.

## Các rủi ro cần kiểm soát
1. Khi có nhiều điểm cực trị và mút cận gần nhau, thuật toán layout nhãn phải tự động tính offset hoặc gộp đường gióng để không bao giờ bị đè chữ.
2. SVG rendering phải duy trì tỷ lệ 60 FPS khi giáo viên kéo nắn điểm uốn/cực trị 2 chiều.

