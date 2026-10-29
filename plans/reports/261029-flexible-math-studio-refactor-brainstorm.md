# Brainstorm: Tái cấu trúc Toàn diện Math Studio & Mô hình Plugin Tải Tự do

**Date:** 2026-10-29

## Ideas Explored
1. **Tự code lại từ đầu bằng Flutter Native CustomPaint (Hướng cũ)**: Cố gắng tự viết lại toàn bộ trục $Oxy$, thuật toán vi phân, lưới tọa độ, và ma trận 3D bằng Flutter Dart. **Bị bác bỏ** vì rơi vào bẫy "phát minh lại bánh xe", cồng kềnh, code bị hardcode vào ứng dụng mẹ, và không thể tải độc lập từ Marketplace.
2. **Nhúng nguyên xi website bên ngoài (Iframe Webview)**: Nhúng nguyên trang web của bên thứ ba. **Bị bác bỏ** vì giao diện không đồng bộ, dính nhiều menu/quảng cáo thừa thãi, không tối ưu cho nhu cầu sư phạm Việt Nam.
3. **Mô hình Hybrid: Web Engine Mã Nguồn Mở + Giao Diện Tùy Biến Độc Lập (Được chọn)**:
   - Plugin là một gói độc lập `.hlep` được tải từ Marketplace qua Internet, lưu vào máy giáo viên và chạy offline 100%.
   - Sử dụng Engine mã nguồn mở mạnh mẽ (JSXGraph, Math.js, Three.js) để tính toán giải tích và vẽ đồ thị/khối tròn xoay 3D.
   - Giao diện tùy biến 2 cột hoàn toàn theo phong cách Học Lực: Cột trái (Thông số & Hàm số tự do), Cột phải (Khung render đồ thị & 3D).
   - Ghim đồ thị lên bảng đen với khả năng co giãn, xoay 360 độ tự do bằng 8 điểm neo Canva.

## User's Direction
- **Không hardcode bất kỳ hàm số nào**: Ô nhập hàm số phải linh hoạt 100%, cho phép nhập bất kỳ biểu thức nào (đa thức bậc cao, lượng giác, mũ, logarit, căn thức...). Các dạng hàm SGK chỉ đóng vai trò là "Phím tắt mẫu" (Presets) để bấm nhanh.
- **Tính năng Khối tròn xoay 3D từ đồ thị hàm số**: Sinh ra khối 3D khi quay đồ thị phẳng $y = f(x)$ quanh trục $Ox$, phục vụ đắc lực cho bài học Ứng dụng tích phân tính thể tích trong SGK Toán 12.
- **Kiến trúc Plugin chuẩn**: Tải bằng internet xuống máy giáo viên khi cần, không nhúng cố định làm nặng file `.exe` của ứng dụng mẹ.
- **Ghim bảng đa năng**: Thẻ đồ thị trên bảng đen hỗ trợ phóng to, thu nhỏ, xoay tự do theo 8 điểm neo Canva.

## Open Questions
- Thư viện 3D cho khối tròn xoay: Sử dụng Three.js WebGL hay thuật toán quét đa giác mặt tròn xoay (surface of revolution mesh) tối giản để đảm bảo tốc độ 120 FPS mượt mà trên mọi máy tính giáo viên?
  -> *Giải pháp*: Xây dựng module sinh mesh mặt tròn xoay tham số $(x, f(x)\cos\theta, f(x)\sin\theta)$ tối ưu nhẹ, không cần nạp bundle nặng.

## Risks
1. **Biểu thức hàm số không hợp lệ hoặc chia cho 0**: Khi giáo viên nhập biểu thức phức tạp, engine cần bắt lỗi (try/catch parser) và hiển thị thông báo thân thiện thay vì làm đơ giao diện.
2. **Hiệu năng xoay 3D trên máy tính cấu hình yếu**: Render lưới tròn xoay cần giới hạn số lượng phân đoạn (segments $\approx 32-48$) để vừa mịn màng vừa duy trì tốc độ khung hình cao.

