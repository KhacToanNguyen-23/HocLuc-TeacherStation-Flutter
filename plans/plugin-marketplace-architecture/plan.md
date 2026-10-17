# Plan: Hệ Thống Plugin Marketplace & Kiến Trúc Clean Microkernel (Chuẩn VS Code / Chrome Extension)

**Date:** 2026-10-17
**Mode:** --hard
**Risk:** normal — Tái cấu trúc đa tệp trên Backend Spring Boot và Frontend Flutter Microkernel Host, lưu trữ gói `.hlep` trên hệ thống file có kiểm tra mã băm SHA-256 và đầy đủ bộ kiểm thử tự động.
**Spec:** `plans/plugin-marketplace-architecture/spec.md`

---

## Scope Challenge & Spec Quality Check

```text
# Scope Challenge:
#   Exists?     → Một phần (Đã có PluginStorageManager, PluginWebServer và HostBridge cơ bản; nhưng thiếu hẳn Backend Marketplace API, chỉ mở được 1 plugin duy nhất, bị lặp cửa sổ nổi rỗng ở StudioScreen, và còn hardcode 'com.hocluc.plugin.english' + thanh công cụ trong frontend/lib/)
#   Minimum?    → 4 Phase: (1) Backend Marketplace Registry & API tải gói/icon/publish, (2) Manifest Schema v2.1 (contributes.tools + inject_sdk cho Open-Source), (3) Quản lý đa phiên (Floating Casio + Lesson Plugin) & Xóa sạch hardcode trong frontend/lib/, (4) Giao diện Marketplace đồng bộ Backend + Sideload cho Dev & Kiểm thử E2E
#   Complexity? → Hard (Liên quan cả Spring Boot Backend, Flutter Host, WebView SDK Injector và các gói plugin trong plugins/)
#
# Mode: --hard
# Test: default
# Tasks: default

# Spec Quality Check:
#   [NEEDS CLARIFICATION] remaining? → 0 mục (Đã làm rõ toàn bộ)
#   Success criteria measurable?     → PASS (< 100ms API, < 500ms mở plugin, 0 chuỗi hardcode ID plugin trong frontend/lib/, 100% test pass)
#   User stories P1/P2/P3?           → PASS (3 P1 stories, 1 P2 story, 1 P3 out-of-scope)
#   Acceptance criteria testable?    → PASS (Xác định rõ endpoint, đường dẫn thư mục giải nén và lệnh test)
#
# Verdict: PASS
```

---

## Tóm Tắt Nghiên Cứu (Step 1 — Research)

- **Researcher A (Primary — Kiến trúc lai VS Code `Contribution Points` + Chrome `Manifest Sandbox` + File-backed Spring Boot Registry):**
  - *Cách tiếp cận:* Mở rộng `manifest.json` lên Schema v2.1 bổ sung `contributes.tools` (để plugin tự định nghĩa các nút công cụ gắn vào bài giảng) và `inject_sdk: true` (để `PluginWebServer` tự tiêm `hocluc-plugin-sdk.js` vào các dự án Open-Source HTML/JS/WASM mà không cần sửa code gốc). Trên Backend Spring Boot, xây dựng `PluginMarketplaceService` tự động đọc các gói `.hlep` (và tự động đóng gói các thư mục trong `plugins/` nếu chưa có file `.hlep`), trích xuất `manifest.json`, `icon.png`, tính mã kiểm tra `sha256` và phục vụ qua REST API.
  - *Đánh giá:* **Được chọn (Optimal)** — Rất nhẹ, không cần migration cơ sở dữ liệu phức tạp cho file nhị phân lớn, xóa sạch 100% hardcode trong `frontend/lib/` và giữ tương thích ngược hoàn toàn với bộ unit test hiện có.

- **Researcher B (Alternative — Lưu trữ Blob trong Database + Xóa bỏ hoàn toàn khay công cụ trên bảng):**
  - *Cách tiếp cận:* Lưu toàn bộ file `.hlep` (lên tới 17MB/gói) vào bảng H2/PostgreSQL và xóa hẳn `SubjectToolPalette` khỏi bảng phấn.
  - *Đánh giá:* **Loại bỏ** — Lưu blob nhị phân lớn vào H2 làm phình bộ nhớ DB không cần thiết, và việc xóa trắng `SubjectToolPalette` thay vì chuyển sang cơ chế đọc động từ `manifest.contributes.tools` sẽ làm mất khả năng gắn sâu công cụ của plugin vào bài giảng cũng như làm gãy các bài kiểm thử hiện có (`subject_tool_palette_test.dart`, `in_board_svo_e2e_test.dart`).

---

## Cấu Trúc Các Phase Triển Khai (Step 2 — Plan Breakdown)

| Phase | Tên Phase | User Stories | Tệp Tạo Mới / Chỉnh Sửa Chính |
| :--- | :--- | :--- | :--- |
| **Phase 01** | **Backend Marketplace Registry & API Phân Phối `.hlep`** (`phase-01-backend-marketplace-registry.md`) | P1 (Giáo viên tải plugin), P2 (Dev/Admin publish `.hlep`) | `backend/api/src/main/java/vn/teaching/marketplace/PluginCatalogItemDto.java`, `PluginMarketplaceService.java`, `PluginMarketplaceController.java`, `PluginMarketplaceControllerTest.java` |
| **Phase 02** | **Manifest Schema v2.1 (`contributes`) & Open-Source Auto-SDK Injector** (`phase-02-manifest-v21-and-sdk-injector.md`) | P1 (Dev thêm plugin / bọc Open-Source), P2 (CLI đóng gói) | `frontend/lib/models/plugin_manifest.dart`, `frontend/lib/services/plugin_web_server.dart`, `plugins/casio_calculator/manifest.json`, `plugins/english_assistant/manifest.json`, `scripts/package_plugin.mjs` |
| **Phase 03** | **Quản Lý Đa Phiên (Floating + Lesson) & Xóa Sạch Hardcode trong Core** (`phase-03-multi-plugin-host-and-zero-hardcode.md`) | P1 (Mở song song cửa sổ nổi Casio & bài giảng), P1 (Zero hardcode trong `frontend/lib/`) | `frontend/lib/services/english_analyzer.dart`, `frontend/lib/services/plugin_manager.dart`, `frontend/lib/models/studio_state.dart`, `frontend/lib/widgets/subject_tool_palette.dart`, `frontend/lib/widgets/studio/studio_document_drawer.dart`, `frontend/lib/screens/studio_screen.dart` |
| **Phase 04** | **Giao Diện Kho Tiện Ích Đồng Bộ Backend, Dev Sideload & Kiểm Thử Kiến Trúc** (`phase-04-marketplace-ui-and-e2e-verification.md`) | P1, P2 (Toàn bộ tiêu chí nghiệm thu) | `frontend/lib/services/plugin_marketplace_service.dart`, `frontend/lib/widgets/studio/studio_plugins_marketplace_panel.dart`, `frontend/test/architecture_test.dart`, `frontend/test/plugin_marketplace_test.dart` |

---

## Red-Team Review & Điều Chỉnh Rủi Ro (Step 3 — Red-Team Adjudication)

1. **[ACCEPTED] Rủi ro tương thích ngược với các bài test `subject_tool_palette_test.dart` và `in_board_svo_e2e_test.dart` khi gỡ hardcode khỏi `SubjectToolPalette`:**
   - *Phát hiện:* Các bài test hiện tại khởi tạo `PluginManifest(id: ..., name: ...)` không truyền `contributes` và kỳ vọng tìm thấy các nút công cụ theo `Key('svo_tool_button')`, `Key('eye_toggle_button')`, `Key('close_palette_button')`.
   - *Đã xử lý vào Phase 02 & Phase 03:* Thiết kế `PluginManifest` đọc danh sách `contributes.tools` từ `manifest.json`; nếu plugin là `drawer_panel` và không khai báo `contributes.tools` tường minh, cung cấp cấu hình tool đóng góp mặc định (dựa trên action tổng quát `snip_region`, `board_annotation_mode`, `quick_text_input`) để 100% bài test cũ vượt qua đồng thời các plugin mới có thể tùy biến hoàn toàn thanh công cụ qua `manifest.json`.
2. **[ACCEPTED] Rủi ro lỗ hổng Zip Slip và gói tải về bị lỗi khi mạng chập chờn:**
   - *Phát hiện:* `PluginStorageManager.installFromZip` hiện tại nối chuỗi đường dẫn giải nén mà chưa chặn ký tự `..` (leo thang thư mục) và chưa kiểm tra mã băm `sha256` trước khi giải nén.
   - *Đã xử lý vào Phase 02 & Phase 04:* Bổ sung kiểm tra chống Zip Slip (`normPath.contains('..')`) trong `PluginStorageManager` và đối chiếu `sha256` trong `PluginMarketplaceService` trước khi giải nén vào `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`.
3. **[ACCEPTED] Lỗi hiển thị 2 cửa sổ nổi đè nhau khi mở plugin từ Kho Tiện Ích:**
   - *Phát hiện:* Hiện tại `studio_screen.dart` (dòng 901–978) vẽ một khung nổi thứ hai dựa trên `PluginManager().activePlugin` trong khi `StageContainer` đã vẽ `FloatingPluginWindow` và `PluginHostDrawer`.
   - *Đã xử lý vào Phase 03:* Xóa bỏ khối overlay dư thừa ở `studio_screen.dart` (dòng 901–978), thống nhất hiển thị qua `StageContainer` và cho phép mở đồng thời cửa sổ nổi (`floatingPlugin`) cùng với plugin gắn bài giảng (`activePlugin`).
4. **[NOTED] Rủi ro xung đột cổng mạng khi nhiều plugin có Sidecar chạy song song:**
   - *Ghi nhận:* `ProcessSupervisor` hiện đã phân bổ cổng động theo từng `pluginId` (`_ports[pluginId]`). Ở Phase 03, `english_analyzer.dart` sẽ bỏ chuỗi cứng `'com.hocluc.plugin.english'` và lấy cổng thông qua `ProcessSupervisor.instance.getActiveSidecarPort()` theo plugin đang hoạt động.

---

## Session Notes (2026-10-17)

- **Hoàn thành trọn vẹn 4 Phase (Phase 01 $\rightarrow$ Phase 04):**
  - **Phase 01 (Backend Marketplace Registry):** Tạo `PluginCatalogItemDto`, `PluginMarketplaceService`, `PluginMarketplaceController` và mở quyền truy cập công khai trong `SecurityTokenInterceptor`. Vượt qua `mvn test -Dtest=PluginMarketplaceControllerTest` (4/4 passed).
  - **Phase 02 (Manifest Schema v2.1 & Auto-SDK Injector):** Nâng cấp `PluginManifest` hỗ trợ `contributes.tools`, `inject_sdk`, `resizable`, `uiDefaultHeight`; nâng cấp `PluginWebServer` tự động tiêm `/__hocluc_sdk__/hocluc-plugin-sdk.js` cho các dự án Open-Source; bổ sung bảo vệ chống Zip Slip (`..`) trong `PluginStorageManager`; đóng gói lại `casio_calculator.hlep` và `english_assistant.hlep` kèm mã kiểm tra SHA-256.
  - **Phase 03 (Multi-Instance Host & Zero-Hardcode Core):** Tách biệt trạng thái `floatingPlugin` (cửa sổ nổi như Casio) và `activePlugin` (gắn bài giảng `drawer_panel`) trong `StudioState`; xóa bỏ khối vẽ cửa sổ nổi bị trùng lặp trong `studio_screen.dart`; chuyển `SubjectToolPalette` sang đọc động từ `manifest.contributesTools`; xóa sạch 100% chuỗi hardcode ID plugin (`english_assistant`, `com.hocluc.plugin.*`, `casio_calculator`) trong `frontend/lib/`.
  - **Phase 04 (Frontend Marketplace Service, UI & Kiểm thử E2E):** Tạo `PluginMarketplaceService`, tích hợp đồng bộ danh mục/tải gói `.hlep` trong `PluginManager`, nâng cấp `StudioPluginsMarketplacePanel` (hỗ trợ hiển thị `icon.png`, nhãn phiên bản, nút Đồng bộ Marketplace, nút Dev Sideload `.hlep`) và vượt qua toàn bộ bộ kiểm thử tự động + `flutter analyze` (0 lỗi).

