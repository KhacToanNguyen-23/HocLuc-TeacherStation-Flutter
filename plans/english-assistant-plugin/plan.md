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
| **02** | `phase-02-plugin-manifest-loader.md` | Plugin Package (.hlep) Loader & Storage Manager | Mô hình manifest.json, service giải nén `.hlep` (zip), quản lý danh sách plugin trong bộ nhớ / thư mục | P1 | P1 |
| **03** | `phase-03-plugin-host-ui.md` | Hybrid Plugin Host UI (Drawer Panel 420px & Pop-out Floating Window) | Dựng khung hiển thị plugin trong ngăn kéo (420px), nút Pop-out thành Floating Window, tích hợp cầu nối `FlatHost` nhận tin nhắn `INSERT_ANNOTATION` | P1, P2 | P1 |
| **04** | `phase-04-python-sidecar-desktop.md` | Python Sidecar Lifecycle Manager (Desktop) & Web Fallback | Quản lý vòng đời `service.exe` trên Windows (start, health-check, terminate on dispose), fallback trạng thái trên Web | P2 | P2 |
| **05** | `phase-05-english-assistant-bundle.md` | English Assistant Sample Bundle (`.hlep`) & End-to-End Tests | Tạo file mẫu `english_assistant.hlep` (manifest, UI HTML/JS, Python engine script), tích hợp vào drawer tài liệu và test suite hoàn chỉnh | P1, P2 | P1 |

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-10 15:40  
**Phase in progress:** phase-01-board-sticker  
**Status:** Completed Phase 01 — BoardSticker Canvas Model, Rendering & Persistence (All 34 tests passing)

### Decisions made this session
- Làm tròn tọa độ chuẩn hóa `normalizedRect` trong `BoardSticker.toJson()` đến 4 chữ số thập phân (`toStringAsFixed(4)`) để tránh sai số IEEE-754 và tối ưu kích thước lưu file `.hls`.
- Render `BoardStickerCard` bên trong `Stack` của `InteractiveViewer` sử dụng `LayoutBuilder` và `ListenableBuilder` để đồng bộ hoàn hảo với zoom/pan của bảng phấn.

### Next immediate action
- Chờ xác nhận từ người dùng tại checkpoint của `--hard` mode để tiếp tục triển khai Phase 02: `phase-02-plugin-manifest-loader`.

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
