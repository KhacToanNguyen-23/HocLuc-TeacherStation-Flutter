# Spec: Hệ Thống Plugin Marketplace & Kiến Trúc Clean Microkernel (Chuẩn VS Code / Chrome Extension)

**Date:** 2026-10-17
**Status:** Ready

---

## Problem Statement
Hệ thống plugin hiện tại trong **Học Lực Teacher Station** đang bị quản lý phân tán và hardcode sâu vào mã nguồn lõi `frontend/lib/` (gọi cứng `'com.hocluc.plugin.english'` trong `english_analyzer.dart`, vẽ cứng thanh công cụ S-V-O/ĐGNL trong `subject_tool_palette.dart`, trùng lặp biến `activePlugin` giữa `PluginManager` và `StudioState` khiến chỉ mở được 1 plugin duy nhất và sinh ra cửa sổ nổi rỗng, đồng thời hoàn toàn chưa có API Marketplace trên Backend). Điều này khiến giáo viên không thể tải plugin theo nhu cầu từ Backend, còn lập trình viên gặp nhiều rào cản khi muốn thêm plugin mới hoặc tích hợp các công cụ Open-Source (như máy tính Casio) vào hệ thống.

---

## User Stories

- **[P1]** Là một **Giáo viên**, tôi muốn duyệt danh sách **Kho Tiện Ích (Plugin Marketplace)** trực tiếp từ Backend, bấm tải về / cập nhật / gỡ cài đặt bất kỳ plugin nào (như Máy tính Casio hay Trợ giảng bộ môn) chỉ với 1 cú nhấp chuột để phần mềm luôn gọn nhẹ và đúng với môn học tôi giảng dạy.
  Accepted when: Khi mở bảng Hoạt động & Tiện ích, ứng dụng gọi `GET /api/marketplace/plugins` lấy danh sách từ Backend; khi bấm "Tải về", ứng dụng tải gói `.hlep` từ `GET /api/marketplace/plugins/{id}/download`, kiểm tra mã băm `sha256`, giải nén vào `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/` và mở dùng ngay mà không cần khởi động lại ứng dụng.

- **[P1]** Là một **Giáo viên**, tôi muốn vừa mở các tiện ích dạng **Cửa sổ nổi (`floating_window`)** như **Máy tính Casio** để tính toán, vừa sử dụng đồng thời các tiện ích **Gắn sâu vào bài giảng (`drawer_panel` / `board_embed` / thanh công cụ bảng)** để kết hợp nhiều công cụ hỗ trợ trong cùng một tiết dạy.
  Accepted when: Giáo viên có thể mở cùng lúc ít nhất 1 plugin cửa sổ nổi (Casio) và 1 plugin gắn với bài giảng/ngăn kéo mà không bị tắt lẫn nhau, không xuất hiện khung cửa sổ trắng dư thừa trên `StudioScreen`, và hiển thị đúng ảnh `icon.png` của từng plugin.

- **[P1]** Là một **Lập trình viên (Developer)**, tôi muốn tạo mới một plugin hoặc bọc một dự án **Open-Source có sẵn** (HTML/JS/WASM/React) chỉ bằng cách đặt thư mục giao diện vào `plugins/<id>/ui/` và khai báo tệp `manifest.json` (với `contributes` cho các nút công cụ/vị trí hiển thị và `"inject_sdk": true`), tuyệt đối **không phải sửa bất kỳ dòng code nào trong `frontend/lib/`**.
  Accepted when:
  1. Bài kiểm thử kiến trúc `flutter test test/architecture_test.dart` vượt qua 100% với các quy tắc siết chặt (cấm mọi chuỗi định danh `english_assistant`, `com.hocluc.plugin.*`, `casio` trong `frontend/lib/`).
  2. `SubjectToolPalette` tự động vẽ các nút công cụ dựa trên cấu hình `manifest.json -> contributes.tools` thay vì hardcode các nút S-V-O của môn Tiếng Anh.
  3. Một dự án web open-source bật `"inject_sdk": true` trong `manifest.json` sẽ được `PluginWebServer` tự động tiêm cầu nối `hocluc-plugin-sdk.js` lúc chạy mà không cần sửa file HTML/JS gốc của dự án đó.

- **[P2]** Là một **Lập trình viên / Quản trị viên**, tôi muốn có công cụ đóng gói nhanh thư mục `plugins/<id>/` thành tệp `<id>-<version>.hlep` và API `POST /api/marketplace/plugins/publish` trên Backend để phát hành hoặc cập nhật plugin mới lên kho chung chỉ bằng một lệnh.
  Accepted when: Công cụ đóng gói kiểm tra tính hợp lệ của `manifest.json` theo Schema v2.1, nén thành file `.hlep` chuẩn, và Backend tự động nhận diện, cập nhật danh mục ngay khi có gói `.hlep` mới.

- **[P3]** _(Ngoài phạm vi MVP — định hướng tương lai)_ Cổng phát triển công khai cho bên thứ 3 tự đăng ký tài khoản, ký số gói cài đặt (Ed25519) và thanh toán plugin trả phí.

---

## Functional Requirements

1. **FR-01 (Chuẩn hóa `manifest.json` Schema v2.1 — Kiểu VS Code & Chrome Extension):**
   Mở rộng mô hình `PluginManifest` tương thích ngược với cấu trúc hiện tại và bổ sung:
   - Thông tin định danh: `id`, `name`, `version`, `author`, `description`, `category`, `icon` (đường dẫn tới `icon.png`/`icon.svg`), `main` (`ui/index.html`).
   - `placement` / `surfaces`: Hỗ trợ `"floating_window"` (kèm `default_width`, `default_height`, `resizable`), `"drawer_panel"` (ngăn kéo bên), và `"board_embed"` (khung tương tác gắn trực tiếp lên trang bài giảng).
   - `inject_sdk` (`bool`, mặc định `true`): Khi bật, `PluginWebServer` tự động chèn thẻ `<script src="/__hocluc_sdk__/hocluc-plugin-sdk.js"></script>` (và thanh nút tiện ích nhanh như "Ghim lên bảng" nếu là web open-source nguyên bản) vào trang HTML của plugin.
   - `contributes`:
     - `tools`: Danh sách các công cụ gắn vào thanh công cụ bài giảng (`{ "id": "...", "label": "...", "icon": "...", "tooltip": "...", "action": "snip_region | toggle_mode | rpc_event", "target": "..." }`) để `SubjectToolPalette` tự động render.
   - `permissions`: Danh sách quyền truy cập tường minh (`board:insert_annotation`, `board:read_text`, `board:snip_region`, `pdf:highlight_spans`, `storage:local`).

2. **FR-02 (Xóa bỏ 100% Hardcode trong `frontend/lib/` — Clean Microkernel):**
   - Gỡ bỏ chuỗi `'com.hocluc.plugin.english'` khỏi `frontend/lib/services/english_analyzer.dart`; tra cứu cổng sidecar động thông qua plugin đang cung cấp tính năng hoặc qua `HostBridge`.
   - Tái cấu trúc `SubjectToolPalette` (`frontend/lib/widgets/subject_tool_palette.dart`) để hiển thị động các nút công cụ từ `manifest.contributes.tools` thay vì vẽ cứng các nút S-V-O / ĐGNL.
   - Chuẩn hóa `HostBridge` (`frontend/lib/services/host_bridge.dart`) với các phương thức JSON-RPC tổng quát, dùng chung cho mọi môn học:
     - `context:get`, `storage:get`, `storage:set`
     - `board:insert_annotation` / `board:insert_sticker` (hỗ trợ chèn công thức `latex`, ảnh chụp `image`, văn bản `text`, thẻ cấu trúc `structured_card`, hoặc khối nhúng `embed`)
     - `board:start_snip` (chụp vùng màn hình/đề thi và trả kết quả về cho plugin gọi lệnh qua sự kiện `host:on_snip_captured`)
     - `pdf:highlight_spans` / `pdf:apply_highlights` / `pdf:save_highlighted`
   - Xóa bỏ khối vẽ cửa sổ nổi trùng lặp trong `frontend/lib/screens/studio_screen.dart` (dòng 901–978) và hợp nhất việc quản lý giao diện plugin về `StageContainer` + `PluginManager`.

3. **FR-03 (Quản lý Đa phiên Plugin — Mở đồng thời Cửa sổ nổi & Tiện ích bài giảng):**
   - Nâng cấp `PluginManager` và `StudioState` để tách biệt:
     - Danh sách các plugin cửa sổ nổi đang chạy (`floatingPlugins`, ví dụ: Máy tính Casio) có thể kéo thả, thu phóng và đóng/mở độc lập.
     - Plugin gắn với ngăn kéo / thanh công cụ bài giảng (`activeLessonPlugin`) và các khối sticker/widget gắn trên từng trang bảng (`pageStickers` được lưu vào JSON bài giảng).
   - Hiển thị đúng tệp ảnh `icon.png` của từng plugin trên thanh công cụ, cửa sổ nổi và danh sách Marketplace (chỉ dùng icon mặc định theo `category` khi plugin không có tệp `icon.png`).

4. **FR-04 (Backend Marketplace API trong `backend/api`):**
   - Xây dựng `MarketplaceController` và `MarketplacePluginService` trên Spring Boot (`backend/api`):
     - Tự động quét các gói `.hlep` trong thư mục lưu trữ của Backend (và tự động đóng gói các thư mục trong `plugins/` thành `.hlep` khi khởi chạy ở môi trường dev/server nếu chưa có file nén).
     - Đọc `manifest.json` bên trong từng gói `.hlep`, tính dung lượng file (`sizeBytes`) và mã băm `sha256`.
     - `GET /api/marketplace/plugins`: Trả về danh mục đầy đủ các plugin trên kho (`id`, `name`, `version`, `author`, `description`, `category`, `placement`, `sizeBytes`, `sha256`, `iconUrl`, `downloadUrl`).
     - `GET /api/marketplace/plugins/{id}/icon`: Trả về ảnh `icon.png` của plugin để hiển thị trên kho ngay cả khi giáo viên chưa tải plugin về máy.
     - `GET /api/marketplace/plugins/{id}/download`: Tải xuống luồng dữ liệu nhị phân (`.hlep`) của plugin.
     - `POST /api/marketplace/plugins/publish`: Cho phép tải lên gói `.hlep` mới, kiểm tra tính hợp lệ của `manifest.json` và cập nhật ngay vào danh mục kho.

5. **FR-05 (Giao diện Kho Tiện Ích & Luồng Tải / Cập nhật / Dev Sideload trên Frontend):**
   - Nâng cấp `PluginManager` và `StudioPluginsMarketplacePanel` để đồng bộ danh mục từ `GET /api/marketplace/plugins` với danh sách các plugin đã cài đặt trong `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`.
   - Hiển thị rõ các trạng thái: **Tải về** (chưa cài), **Đang tải...**, **Cập nhật** (khi `remote.version > local.version`), **Mở / Đang mở / Gỡ cài đặt** (đã cài).
   - Thêm nút **"Nạp gói .hlep / Thư mục (Dev)"** trên thanh tiêu đề của bảng Tiện ích để lập trình viên có thể nạp thử nghiệm bất kỳ gói plugin hoặc thư mục open-source nào ngay lập tức.

6. **FR-06 (Chuẩn hóa Plugin Máy tính Casio & Plugin hiện có sang Schema v2.1):**
   - Rà soát và nâng cấp gói plugin **Máy tính Casio** (và plugin Tiếng Anh) trong thư mục `plugins/` theo chuẩn `manifest.json` v2.1:
     - Đảm bảo Casio chạy mượt dưới dạng `floating_window`, có khả năng gửi kết quả phép tính / biểu thức LaTeX ghim thẳng lên bảng phấn qua `hocluc-plugin-sdk.js`, và có thể tải/gỡ cài đặt trọn vẹn từ Backend Marketplace.

---

## Non-Functional Requirements

- **Hiệu năng (Performance):**
  - Thời gian phản hồi API danh mục `GET /api/marketplace/plugins` đạt `p95 < 100ms`.
  - Mức tiêu thụ RAM của các plugin chưa cài hoặc đang đóng = `0 MB` (giải nén hoàn toàn ra ổ đĩa `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`, không lưu `filesMap` trong bộ nhớ RAM).
  - Thời gian mở giao diện plugin HTML/JS/WASM đã cài đặt (như Casio) qua máy chủ cục bộ `PluginWebServer` `< 500ms`.
- **Bảo mật & Cô lập (Security & Isolation):**
  - Mọi lệnh gọi qua `HostBridge` đều phải kiểm tra quyền trong `manifest.permissions` trước khi thao tác lên bảng phấn hoặc tài liệu PDF.
  - Kiểm tra tính toàn vẹn của gói `.hlep` tải từ Backend bằng mã băm `sha256` và chặn triệt để lỗi leo thang thư mục (`..` Zip Slip) khi giải nén trong `PluginStorageManager`.
- **Tuân thủ Kiến trúc (Architecture Compliance):**
  - `0` chuỗi định danh plugin cố định (`english_assistant`, `com.hocluc.plugin.*`, `casio`) và `0` cổng mạng cố định (`18888`) tồn tại trong `frontend/lib/`.

---

## Success Criteria

- [ ] **Kiểm thử Kiến trúc (Architecture Gate):** `flutter test test/architecture_test.dart` vượt qua 100% với bộ quy tắc mở rộng cấm mọi chuỗi `'com.hocluc.plugin.'`, `'casio'`, `'english_assistant'` trong `frontend/lib/`.
- [ ] **Luồng Marketplace Đầu-Cuối:** Giáo viên mở Kho Tiện Ích, thấy danh sách plugin từ Backend (`GET /api/marketplace/plugins`), bấm tải Máy tính Casio về máy (`%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`) và mở sử dụng thành công trong `< 2` thao tác bấm.
- [ ] **Chạy Đa nhiệm Plugin:** Giáo viên mở đồng thời cửa sổ nổi Máy tính Casio (`floating_window`) và một tiện ích môn học gắn trong bài giảng (`drawer_panel` + `SubjectToolPalette` động) mà không xung đột hay hiện cửa sổ thừa.
- [ ] **Tốc độ Tích hợp Open-Source cho Dev:** Lập trình viên có thể biến một công cụ web Open-Source độc lập thành plugin chạy được trên hệ thống chỉ bằng cách thêm tệp `manifest.json` (`< 30` dòng JSON, `"inject_sdk": true`) với `0` dòng code phải sửa trong `frontend/lib/`.

---

## Out of Scope

- Cổng thanh toán trực tuyến và quản lý bản quyền thương mại cho các plugin trả phí.
- Chạy các tiến trình Python Sidecar trên đám mây (Sidecar vẫn chạy cục bộ qua `ProcessSupervisor` hoặc chuyển sang WebAssembly/JS chạy trong WebView).
- Đồng bộ tương tác plugin thời gian thực hai chiều xuống thiết bị riêng của từng học sinh (kết quả của plugin được giáo viên trình chiếu và ghim trực tiếp lên mặt bảng chung của lớp học).

---

## Assumptions

- Dịch vụ Backend (`backend/api` - Spring Boot) có quyền đọc/ghi vào thư mục chứa các gói `.hlep` (và có khả năng tự động đóng gói các thư mục plugin có sẵn trong `plugins/` của repo để phục vụ ngay khi chạy local/server).
- Ứng dụng Desktop sử dụng Edge WebView2 (Windows) / WKWebView (macOS) kết hợp với `PluginWebServer` chạy trên cổng loopback động (`http://127.0.0.1:<port>/plugins/<id>/...`) để hỗ trợ đầy đủ ES Modules và WASM không bị lỗi CORS.
