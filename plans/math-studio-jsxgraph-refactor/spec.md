# Spec: Nâng Cấp Engine Đồ Thị Chuẩn Sư Phạm Quốc Tế JSXGraph (Hướng B)

## 1. Problem Statement
Đồ thị vẽ bằng việc nối chuỗi SVG thủ công (`graph_plotter.js`) gặp phải 3 vấn đề cố hữu của phương pháp vẽ tay:
1. **Nét vẽ thô và mờ nhòe:** Trên các màn hình laptop và bảng tương tác có tỉ lệ thu phóng (HiDPI / Scaling 125%-150%), các thẻ SVG không có cơ chế sub-pixel alignment khiến chữ số và trục tọa độ bị răng cưa/mờ nét.
2. **Đè chữ (Text Collisions):** Khi cực trị hoặc điểm giao trục nằm sát nhau hoặc sát gốc tọa độ $O$, các nhãn tọa độ cứng bị đè lên nhau, gây khó đọc và thiếu chuyên nghiệp.
3. **Thiếu tính tương tác tự nhiên:** Việc kéo thả điểm, zoom mượt mà cần rất nhiều logic thủ công dễ phát sinh lỗi góc cạnh.

## 2. Target Solution (Hướng B)
Tích hợp **JSXGraph (v1.9.2)** - Thư viện toán học giải tích & hình học động mã nguồn mở chuẩn quốc tế từ Đại học Bayreuth:
- Tải offline hoàn toàn trong plugin (`plugins/math_studio/ui/vendor/jsxgraph/`).
- Engine vector SVG tối ưu với thuật toán **Label Collision Avoidance** (tự động né chữ thông minh).
- Đường cong hàm số mượt mà với **Adaptive Sampling** (tự làm mịn đoạn cong gắt, ngắt đoạn tiệm cận tự nhiên).
- Hệ trục $Ox, Oy$, mũi tên trục, lưới toạ độ, đường gióng nét đứt chuẩn Sách Giáo Khoa Việt Nam.
- Tương thích 100% với luồng ghim đồ thị lên bảng phấn (Studio Board) của Học Lực.

## 3. P1 User Stories & Acceptance Criteria
- **US1 (P1): Sắc nét & Không mờ:** Bảng vẽ JSXGraph hiển thị chữ số trục (11.5px Dark Charcoal), lưới tọa độ mờ và đường cong $y=f(x)$ sắc sảo, không mờ nhòe trên mọi độ phân giải.
- **US2 (P1): Triệt tiêu đè chữ:** Nhãn các điểm cực trị (CĐ, CT), giao điểm trục và mút cận tích phân ($a, b$) tự động đổi vị trí tránh đè lên nhau.
- **US3 (P1): Đầy đủ nghiệp vụ giải tích SGK:**
  - Đường gióng nét đứt SGK từ cực trị xuống $Ox, Oy$.
  - Miền tích phân gạch phẳng bán trong suốt thanh lịch giữa 2 cận $a, b$.
  - Tiệm cận đứng, ngang (hàm phân thức).
  - Thẻ công thức toán học $y = x^2 - 2$ hiển thị trang nhã.
- **US4 (P1): Giữ nguyên API và xuất bản lên Studio Board:**
  - `generateGraphSvg(...)` vẫn trả về chuỗi SVG hoàn chỉnh cho các file test tự động và tính năng xuất SVG.
  - Nút "Xong" ghim SVG lên bảng phấn hoạt động trơn tru.
- **US5 (P1): Đạt 12/12 Bất biến kiến trúc & Đóng gói .hlep hợp lệ.**

