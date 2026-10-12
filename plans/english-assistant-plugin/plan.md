# Plan: English Assistant Plugin (.hlep) & Microkernel Runtime

**Mode:** --hard  
**Risk:** normal — multi-file, testable, adds sidecar process management and canvas sticker serialization, fully non-destructive  
**Spec:** `plans/english-assistant-plugin/spec.md`  

---

## Architecture Overview

Hệ thống bổ sung kiến trúc Plugin Microkernel cho Học Lực Studio gồm 4 thành phần chính:

```
[ Gói .hlep (Zip) ] 
       │
       ▼
[ PluginManager & Manifest Loader ] 
       │
       ├── Desktop: [ SidecarProcessManager ] ──> engine/service.exe (Port 18888)
       │   Web:     [ Fallback / Mock Server ] 
       │
       ▼
[ PluginHostDrawer & FloatingPluginWindow ] (FlatHost: WebView2 / Iframe)
       │
       │ bridge: "INSERT_ANNOTATION"
       ▼
[ BoardSticker & InteractiveChalkboard Overlay ] 
       │
       ▼
[ StudioState & Persistence (.hls JSON) ]
```

---

## Phases

| Phase | File | Title | Scope | Stories Covered | Priority |
|---|---|---|---|---|---|
| **[x] 01** | `phase-01-board-sticker.md` | BoardSticker Canvas Model, Rendering & Persistence | Tạo model `BoardSticker`, widget hiển thị thẻ trên `InteractiveChalkboard`, kéo thả di chuyển vị trí, và serialize vào `StudioState` (.hls) | P1 | P1 |
| **[x] 02** | `phase-02-plugin-manifest-loader.md` | Plugin Package (.hlep) Loader & Storage Manager | Mô hình manifest.json, service giải nén `.hlep` (zip), quản lý danh sách plugin trong bộ nhớ / thư mục | P1 | P1 |
| **[x] 03** | `phase-03-plugin-host-ui.md` | Hybrid Plugin Host UI (Drawer Panel 420px & Pop-out Floating Window) | Dựng khung hiển thị plugin trong ngăn kéo (420px), nút Pop-out thành Floating Window, tích hợp cầu nối `FlatHost` nhận tin nhắn `INSERT_ANNOTATION` | P1, P2 | P1 |
| **[x] 04** | `phase-04-python-sidecar-desktop.md` | Python Sidecar Lifecycle Manager (Desktop) & Web Fallback | Quản lý vòng đời `service.exe` trên Windows (start, health-check, terminate on dispose), fallback trạng thái trên Web | P2 | P2 |
| **[x] 05** | `phase-05-english-assistant-bundle.md` | English Assistant Sample Bundle (`.hlep`) & End-to-End Tests | Tạo file mẫu `english_assistant.hlep` (manifest, UI HTML/JS, Python engine script), tích hợp vào drawer tài liệu và test suite hoàn chỉnh | P1, P2 | P1 |

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-10 16:13  
**Phase in progress:** None (Completed 5/5 Phases)  
**Status:** All 5 Phases Completed — English Assistant Plugin Microkernel Fully Operational (All 47 tests passing, analyzer 0 issues)

### Decisions made this session
- Áp dụng conditional export `sidecar_manager_native.dart` (Process.start) và `sidecar_manager_web.dart` (HTTP health-check ping).
- Quản lý an toàn tiến trình `service.exe` ngầm: Tự động poll health-check với timeout 5 giây, lắng nghe `exitCode`, và dọn dẹp tiến trình ngay khi đóng plugin để tránh orphan process.
- Tạo gói plugin mẫu `plugins/english_assistant.hlep` và script đóng gói `scripts/package_plugin.mjs`.
- Hỗ trợ cả 1-click cài đặt plugin mẫu lẫn chọn tệp `.hlep` từ máy tính trong Drawer Tài liệu.
- Tự động thu gọn ngăn kéo khi ghim thẻ S-V-O (`INSERT_ANNOTATION`) để trả lại 100% không gian bảng cho giáo viên.

### Next immediate action
- Tất cả các phase trong kế hoạch đã hoàn thành 100%. Sẵn sàng báo cáo tổng kết và chờ hướng dẫn tiếp theo từ người dùng.

---

## File Ownership Matrix

- **Phase 01:**
  - `frontend/lib/models/board_sticker.dart` (new)
  - `frontend/lib/models/studio_state.dart`
  - `frontend/lib/widgets/interactive_chalkboard.dart`
  - `frontend/lib/widgets/board_sticker_card.dart` (new)
  - `frontend/test/board_sticker_test.dart` (new)

- **Phase 02:**
  - `frontend/lib/models/plugin_manifest.dart` (new)
  - `frontend/lib/services/plugin_manager.dart` (new)
  - `frontend/test/plugin_manifest_test.dart` (new)

- **Phase 03:**
  - `frontend/lib/widgets/plugin_host_drawer.dart` (new)
  - `frontend/lib/widgets/floating_plugin_window.dart` (new)
  - `frontend/lib/widgets/drawer_questions.dart`
  - `frontend/lib/widgets/stage_container.dart`
  - `frontend/test/plugin_ui_test.dart` (new)

- **Phase 04:**
  - `frontend/lib/services/sidecar_manager.dart` (new)
  - `frontend/lib/services/sidecar_manager_stub.dart` (new)
  - `frontend/lib/services/sidecar_manager_native.dart` (new)
  - `frontend/lib/services/sidecar_manager_web.dart` (new)

- **Phase 05:**
  - `plugins/english_assistant/` (source bundle)
  - `plugins/english_assistant.hlep` (packed bundle)
  - `frontend/test/english_assistant_e2e_test.dart` (new)

---

## Risks and Mitigations

1. **Risk:** Lệch tọa độ thẻ sticker khi giáo viên phóng to / thu nhỏ hoặc kéo bảng phấn.
   - *Mitigation:* `BoardSticker` lưu tọa độ chuẩn hóa (`normalized_rect: 0.0..1.0`) và render bên trong `Stack` của `InteractiveViewer`, đảm bảo zoom/pan tự nhiên 100% đồng bộ với canvas nét vẽ.
2. **Risk:** Xung đột cổng Port 18888 trên máy giáo viên.
   - *Mitigation:* Thử cổng 18888 trước, nếu bận sẽ tìm cổng ngẫu nhiên khả dụng trong dải 18889-18899 và truyền port qua query parameter `?port=...` vào `FlatHost`.
3. **Risk:** Trình duyệt Web không chạy được `.exe`.
   - *Mitigation:* `SidecarManagerWeb` trả về trạng thái Web-mode, UI hiển thị huy hiệu và cho phép kết nối API bên ngoài hoặc dùng Mock data mẫu.
