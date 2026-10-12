# Brainstorm: English Assistant Plugin (.hlep) & Microkernel Runtime

**Date:** 2026-10-10

## Ideas Explored
- **Nền tảng mục tiêu (Runtime Platform):**
  - *Chỉ Windows Native:* Chạy trực tiếp `service.exe` qua `dart:io Process.start`, kết nối WebView2 bridge. Nhược điểm: Không chạy được trên Web.
  - *Chỉ Web:* Nhẹ nhàng qua iframe, nhưng không tự bật được sidecar binary cục bộ mà phải dựa vào server từ xa.
  - *Đa nền tảng (Được chọn):* Hỗ trợ cả Windows Desktop (tự động quản lý lifecycle của sidecar process) và Web (kết nối local server hoặc endpoint từ xa, giao tiếp qua window postMessage).
- **Cách ghim kết quả phân tích lên bảng vẽ (Canvas Pinning):**
  - *Vẽ trực tiếp nét chữ/màu vào lớp Stroke:* Khó chỉnh sửa hoặc xóa riêng lẻ, không thể di chuyển sau khi ghim.
  - *Thẻ Sticker / Widget ghi chú nổi (Được chọn):* Render dưới dạng `BoardSticker` có thể kéo thả, phóng to/thu nhỏ, zoom đồng bộ theo bảng và lưu trữ tọa độ chuẩn hóa (`0.0..1.0`).
- **Vị trí hiển thị Plugin UI:**
  - *Panel ngăn kéo (Drawer Panel 420px):* Tạo không gian vững chãi, tiện soạn thảo văn bản dài và đối chiếu, tự đóng khi ghim để trả 100% diện tích bảng.
  - *Cửa sổ nổi (Floating Window):* Linh hoạt di chuyển nhưng dễ che khuất bảng vẽ.
  - *Mô hình Hybrid (Được chọn):* Mặc định mở ở Drawer Panel 420px kèm nút [🗗 Tách cửa sổ / Pop-out] để biến thành Floating Window khi cần.
- **Kịch bản lưu trữ dữ liệu bài giảng:**
  - *Không lưu vào file .hls:* Mất dữ liệu khi đóng app, giáo viên phải phân tích lại.
  - *Bắt buộc lưu vào file .hls (Được chọn):* Serialize `BoardSticker` vào `StudioPage.annotations` với tọa độ chuẩn hóa (`normalized_rect`), đảm bảo tính liền mạch của giáo án khi mở lại trên bất kỳ độ phân giải nào.

## User's Direction
- Giáo viên muốn một gói plugin Trợ giảng Tiếng Anh (`english_assistant.hlep`) tích hợp spaCy (bóc tách Chủ ngữ - Vị ngữ S-V-O) và LanguageTool (bắt lỗi thì/ngữ pháp).
- Hỗ trợ đa nền tảng (Windows Desktop & Flutter Web).
- Vị trí UI: Panel ngăn kéo 420px trượt ra, có nút Pop-out thành cửa sổ nổi tự do.
- Ghim lên bảng dưới dạng Thẻ Sticker ghi chú tương tác (interactive floating card), di chuyển và zoom theo bảng phấn.
- Bắt buộc lưu trữ trạng thái thẻ ghi chú vào file bài giảng `.hls` để hỗ trợ soạn giáo án trước giờ dạy.

## Open Questions
- Cơ chế tự động tìm cổng port khả dụng nếu port 18888 mặc định bị trùng.
- Công cụ đóng gói 1-click (CLI hoặc script `package.mjs`) để nén thư mục plugin thành file `.hlep`.

## Risks
- **Trình duyệt Web sandbox:** Web không thể tự chạy file nhị phân `service.exe`; cần hiển thị hướng dẫn kết nối local server rõ ràng khi chạy trên nền tảng Web.
- **Tải model spaCy ban đầu:** Quá trình khởi động `service.exe` có thể mất 1-3 giây để nạp model `en_core_web_sm` vào RAM. Cần có trạng thái loading/health-check mượt mà.
