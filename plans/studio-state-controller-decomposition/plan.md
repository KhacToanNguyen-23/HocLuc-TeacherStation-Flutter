# Kế hoạch Phân rã StudioState God Object thành các Domain Controllers

> **Mục tiêu:** Xóa bỏ hoàn toàn 6 file `part of` đối phó CI (`studio_state_*.dart`), phân tách khối God Object `StudioState` (~3.000 dòng code gộp) thành các Controller chuyên biệt theo chuẩn Clean Architecture (Canvas, PDF/SmartPen, Audio, Plugin, Workspace), sử dụng Coordinator làm Mediator điều phối sự kiện chéo và duy trì Facade `StudioState` để đảm bảo 100% test hiện hữu không bị hồi quy.

---

## Thông tin phân loại & Phạm vi
* **Mode:** `--hard` (Central State Architecture Decomposition)
* **Risk:** `high-risk` — Chạm vào luồng trạng thái trung tâm của Studio, bảng vẽ Canvas, đồng bộ Audio WASAPI và cầu nối Plugin Host Bridge.
* **Test:** Chạy `flutter test test/features/studio_board/` và `flutter test test/architecture_test.dart` sau mỗi Phase.

---

## Ma trận các thành phần kiến trúc mới

| Controller / Mediator | Phạm vi trách nhiệm (Single Responsibility) | Trạng thái quản lý | Không được phụ thuộc trực tiếp vào |
| :--- | :--- | :--- | :--- |
| **`CanvasDrawingController`** | Quản lý vẽ nét bảng, undo/redo, stickers, shapes, clear board | `strokes`, `redoStrokes`, `activePage`, `tool`, `penColor` | Không biết về Webview, Plugin hay Audio |
| **`PdfSmartPenController`** | Quản lý PDF document, Smart Pen classifier, gesture recognition, oval snapping | `pdfDocument`, `pdfPages`, `smartPenIndex`, `ovalAnnotations` | Không biết về Audio hay Network |
| **`AudioSyncController`** | Đồng bộ Windows WASAPI mic, input level meter, audio translation runtime | `audio`, `microphones`, `isMicActive`, `translationLanguage` | Không biết về nét vẽ hay PDF |
| **`StudioPluginBridgeController`** | Cầu nối `PluginHostBridge`, iframe/webview message handler, dynamic port RPC | `activePlugins`, `floatingPosition`, `installedPlugins` | Giao tiếp với Canvas qua Coordinator |
| **`StudioWorkspaceCoordinator`** | Quản lý phiên học, title, notes, planning mode, serialization, điều phối chéo | `title`, `subject`, `notes`, `isPlanning`, `dirty`, `saving` | Đóng vai trò Mediator kết nối 4 controllers |
| **`StudioState` (Facade)** | Wrapper mỏng ủy quyền (delegation) xuống Coordinator và Sub-controllers | Wrapper facade giữ nguyên 100% public API cũ | Không chứa logic tính toán nặng |

---

## Danh sách các Phase triển khai

- [x] **Phase 1: Xây dựng 4 Domain Controllers độc lập** ([phase-01-domain-controllers-scaffolding.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/studio-state-controller-decomposition/phase-01-domain-controllers-scaffolding.md))
- [x] **Phase 2: Thiết lập StudioWorkspaceCoordinator & Event Mediator** ([phase-02-coordinator-and-mediator-events.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/studio-state-controller-decomposition/phase-02-coordinator-and-mediator-events.md))
- [x] **Phase 3: Chuyển đổi StudioState thành Facade & Xóa sổ 6 file `part of`** ([phase-03-facade-adaptation-and-part-removal.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/studio-state-controller-decomposition/phase-03-facade-adaptation-and-part-removal.md))
- [x] **Phase 4: Tối ưu Scoped Listenable Rebuild cho các Leaf Widgets** ([phase-04-leaf-widgets-scoped-listenable-binding.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/studio-state-controller-decomposition/phase-04-leaf-widgets-scoped-listenable-binding.md))
- [x] **Phase 5: Kiểm định toàn diện, Profiling & Chốt chặn CI Invariants** ([phase-05-verification-and-ci-gates.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/studio-state-controller-decomposition/phase-05-verification-and-ci-gates.md))

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-20 14:12
**Phase in progress:** COMPLETED
**Status:** All 5 phases completed! 413/413 frontend tests passing, 129/129 backend tests passing, 12/12 architecture invariants passing, 0 analyzer issues, plugins 100% valid.

### Decisions made this session
- Decoupled `studio_board_models.dart` from `part of 'studio_state.dart'` into a standalone model file so all controllers can import models directly without cyclical/part-of coupling.
- Wired `StudioWorkspaceCoordinator` to orchestrate 4 domain controllers, serialize/deserialize lesson data, route plugin card insertions, and cascade dispose cleanly.
- Extracted smart pen session overrides, temporary oval management, and atomic history tracking into `smart_pen_answer_manager.dart`.
- Converted `StudioState` into a backward-compatible Facade (848 LOC <= 900 LOC CI gate) delegating to `coordinator`.
- Removed all legacy `part of` files (`studio_state_*.dart`).
- Implemented `ScopedListenableBuilder` and moved `laserOffset` to isolated `ValueNotifier` to avoid screen rebuilds during pointer movement.
- Fixed `showQuestionsDrawer = false` in `openPlugin` to properly dismiss drawer backdrops on plugin launch.
- Preserved full backward compatibility on `StudioState` Facade including plugin tap-mode smart snap query and lesson save/restore endpoints.
- Phase 4: added selector-based `ScopedListenableBuilder`; laser offset moved to its own `ValueNotifier`; shell/top bar/question view/speaker notes bar decoupled from the aggregate studio notifications.
