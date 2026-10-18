# Brainstorm: Hệ Thống Plugin Marketplace & Kiến Trúc Clean Microkernel (Chuẩn VS Code / Chrome Extension)

**Date:** 2026-10-17

## Ideas Explored
1. **Quét thư mục cục bộ kết hợp xử lý nghiệp vụ trong Core (Hiện tại - Đã loại bỏ):**
   - `PluginManager` chỉ quét thư mục `plugins/` trên ổ cứng cục bộ, hoàn toàn chưa có API tải từ Backend Marketplace.
   - Nghiêm trọng hơn, code nghiệp vụ của plugin cụ thể đang bị hardcode thẳng vào `frontend/lib/` (như `'com.hocluc.plugin.english'` trong `english_analyzer.dart`, thanh công cụ `S-V-O` / `Quét đoạn văn` cứng trong `subject_tool_palette.dart`, và chỉ mở được 1 `activePlugin` duy nhất tại một thời điểm).
2. **Nạp động mã nguồn trực tiếp vào cây giao diện chính (Dynamic Code / Shared DOM Injection - Đã loại bỏ):**
   - Nhúng thẳng code của plugin vào runtime chính của ứng dụng mà không qua lớp cách ly WebView/Sandbox.
   - Nhược điểm: Flutter Desktop biên dịch AOT nên không hỗ trợ nạp động code Dart; các dự án Open-Source bên ngoài (như máy tính Casio JS/WASM, GeoGebra, PhET) sẽ bị xung đột CSS/JS và phải viết lại toàn bộ thay vì tái sử dụng nguyên bản.
3. **Kiến trúc lai VS Code (`Contribution Points`) + Chrome Extension (`Manifest Sandbox & Auto-Inject SDK`) + Backend `.hlep` Registry (Được lựa chọn):**
   - **Đóng gói & Tích hợp Open-Source (Kiểu Chrome Extension):** Mỗi plugin là một gói độc lập `.hlep` (file nén chuẩn chứa `manifest.json` Schema v2.1, `icon.png`, thư mục `ui/` và tùy chọn `engine/`). Với các dự án Open-Source có sẵn (như Casio emulator), dev chỉ cần chép bản build web tĩnh vào `ui/` và bật `"inject_sdk": true`; `PluginWebServer` sẽ tự động tiêm `hocluc-plugin-sdk.js` lúc chạy mà không cần sửa code gốc.
   - **Gắn kết sâu vào bài giảng & đa cửa sổ (Kiểu VS Code `contributes`):** Plugin tự khai báo các nút công cụ (`contributes.tools`) và các bề mặt hiển thị (`floating_window`, `drawer_panel`, `board_embed`) ngay trong `manifest.json`. Core Flutter tự động đọc manifest để vẽ thanh công cụ và cho phép mở **đa nhiệm** (vừa bật cửa sổ nổi Casio vừa dùng plugin gắn trong bài giảng), xóa bỏ 100% hardcode trong `frontend/lib/`.
   - **Kho tải Backend Marketplace gọn nhẹ (`backend/api`):** Spring Boot tự động đọc/đóng gói các gói `.hlep` trên server, trích xuất `manifest.json`, tính mã kiểm tra `sha256` và cung cấp API danh mục + tải gói 1-click về giải nén tại `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`.

## User's Direction
- "Quản lí plugin theo kiểu dễ thêm 1 cái plugin mới cho dev, dễ install để sử dụng cho giáo viên, tái cấu trúc lại hệ thống plugin hiện tại theo chuẩn chuyên nghiệp, giống các plugin của VS Code hoặc extension của Google Chrome."
- "Không phải hardcode là plugin gì là code tới đó quản lí bừa bãi."
- "Có thể là cửa sổ nổi hoặc gắn sâu vào bài giảng."
- "Hướng nào nhẹ nhàng, tối ưu cho dự án này, chuẩn chuyên nghiệp."

## Open Questions
- **Tách hoàn toàn logic Tiếng Anh cũ ra khỏi `StudioState` và `SubjectToolPalette`:** Khi lập kế hoạch (`$bb-plan`), cần chuyển toàn bộ các nút công cụ `S-V-O` / `Quét đoạn văn` sang cấu hình `contributes.tools` trong `manifest.json` của plugin Tiếng Anh, và chuyển giao tiếp sang chuẩn JSON-RPC tổng quát qua `HostBridge`.
- **Cơ chế xác thực khi tải gói `.hlep` lên Backend:** Ở giai đoạn MVP, Backend kiểm tra cấu trúc `manifest.json` hợp lệ và sinh mã băm `sha256` để đảm bảo toàn vẹn gói tải về; chữ ký số nhà phát triển bên thứ 3 sẽ để mở rộng ở giai đoạn sau.

## Risks
- **Rủi ro hồi quy (Regression) khi gỡ hardcode khỏi `StudioState`:** Việc xóa bỏ các đoạn gọi cứng `'com.hocluc.plugin.english'` và thanh công cụ S-V-O cứng phải đi kèm với việc nâng cấp `HostBridge` để mọi tính năng cũ (như quét vùng PDF, highlight đề thi, ghim nhãn dán/công thức từ Casio lên bảng) vẫn hoạt động trơn tru qua RPC.
- **Quản lý tài nguyên khi mở nhiều plugin cùng lúc:** Khi cho phép mở song song cửa sổ nổi (Casio) và plugin gắn vào bài giảng, `PluginManager` cần quản lý chặt vòng đời của từng phiên mở và giải phóng ngay WebView / tiến trình phụ khi giáo viên đóng plugin.
