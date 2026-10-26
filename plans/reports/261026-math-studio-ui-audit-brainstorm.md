# Brainstorm: Kiểm tra & Khắc phục toàn diện các vấn đề UI/UX của Plugin Math Studio

**Date:** 2026-10-26

## Ideas Explored
- **Vấn đề 1 (Cache Stale `%LOCALAPPDATA%`)**: `PluginManager.init()` đang nạp bản cũ từ `%LOCALAPPDATA%\HocLuc\plugins\com.hocluc.plugin.math_studio\v2.1.0\` và bỏ qua bản mới trong `plugins/math_studio/` nếu cùng version `2.1.0`. Giải pháp: Tự động đồng bộ / cập nhật từ gói `.hlep` hoặc thư mục nguồn mới nhất khi khởi chạy và tăng version hoặc kiểm tra thời gian sửa đổi (`lastModified`).
- **Vấn đề 2 (Căn tâm cố định Modal "Studio Toán học")**: Thay vì tính tọa độ theo `MediaQuery.of(context).size` (gây lệch phải và tụt xuống đè vào thanh "Ghi chú Trang 1/1"), sử dụng `LayoutBuilder` / `Center` trực tiếp trong vùng Stack của bảng với kích thước cố định chuẩn (ví dụ `980 × 560px`) để luôn nằm chính giữa vùng bảng và cách đều cả 4 phía.
- **Vấn đề 3 (Chữ & nhãn cực trị trên JSXGraph)**: Đặt nhãn Cực đại ($CĐ$) nằm hẳn phía trên đỉnh lồi (`offset: [0, 16]`, `anchorX: 'middle'`) và Cực tiểu ($CT$) nằm hẳn phía dưới đáy lõm (`offset: [0, -18]`, `anchorX: 'middle'`), kết hợp viền halo trắng (`text-shadow` / paint-order) để không bao giờ đè lên đường gióng nét đứt hay trục tọa độ.
- **Vấn đề 4 (Xuất SVG Ghim lên bảng đen)**:
  - *Phương án A (Được chọn)*: Khi xuất SVG lên bảng đen, tự động ẩn lưới phụ của JSXGraph để tiệp hoàn toàn vào lưới sẵn có của bảng phấn, ẩn các chấm điều khiển kéo cận (gliders), chuyển đổi cả thuộc tính `fill` lẫn inline `style="fill: ..."` của mọi nhãn chữ ($CĐ, CT, a, b, x, y$) sang màu sáng nổi bật trên nền bảng đen.
  - *Phương án B (Loại bỏ)*: Giữ nguyên khung lưới trắng của JSXGraph đè lên bảng đen.
- **Vấn đề 5 (Khung chọn nét đứt & Thanh công cụ nổi)**: Đảm bảo vùng chọn sticker nhạy trên toàn bộ diện tích (`HitTestBehavior.opaque`), hiển thị khung nét đứt đỏ đô (`#8B1D24`) và thanh công cụ nổi chuẩn NoteRenderer.

## User's Direction
- **1. Phương án A cho ảnh Ghim lên bảng đen**: Tự động ẩn lưới phụ của JSXGraph và các nút kéo điều khiển (gliders) khi ghim lên bảng, chỉ giữ hệ trục $Ox, Oy$, đường cong, miền tích phân và toàn bộ nhãn chữ ($CĐ, CT, a, b$) đổi sang màu sáng sắc nét trên nền trong suốt.
- **2. Kích thước Hộp thoại Cố định**: Sử dụng kích thước cố định vừa vặn (không tràn vào thanh Ghi chú Trang 1/1), căn chính tâm tuyệt đối trong vùng làm việc của bảng đen và đứng cứng không di chuyển.

## Open Questions
- Không còn câu hỏi mở (đã chốt toàn bộ).

## Risks
- **Rủi ro 1**: JSXGraph ghi màu chữ và đường kẻ vào thuộc tính `style` inline thay vì XML attribute `fill`/`stroke`. Cần парse và cập nhật cả inline `style` trong `board_exporter.js` để không sót bất kỳ nhãn chữ nào.
- **Rủi ro 2**: Dữ liệu cache cũ trong `%LOCALAPPDATA%\HocLuc\plugins\` có thể giữ file cũ nếu chỉ kiểm tra chuỗi `version`. Cần cập nhật cơ chế đồng bộ local bundle trong `PluginManager` và đồng bộ trực tiếp vào thư mục `%LOCALAPPDATA%`.

