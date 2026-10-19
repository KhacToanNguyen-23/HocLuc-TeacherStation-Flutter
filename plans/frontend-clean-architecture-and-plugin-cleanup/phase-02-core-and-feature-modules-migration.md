# Phase 02: Core & Feature Modules Migration

**Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-clean-architecture-and-plugin-cleanup/plan.md)  
**Status:** Completed  
**Target Directories:** `frontend/lib/services/`, `frontend/lib/widgets/` $\rightarrow$ `frontend/lib/features/` & `frontend/lib/core/`

---

## 1. Mục Tiêu & Yêu Cầu

Di chuyển có trật tự các file services và widgets về đúng module tính năng và cập nhật 100% đường dẫn import:

### Ánh xạ cụ thể:

1. **`lib/features/plugin_engine/`:**
   - Services: `plugin_manager.dart`, `plugin_storage_manager.dart`, `plugin_marketplace_service.dart`, `plugin_web_server.dart`, `process_supervisor.dart`, `host_bridge.dart`.
   - Widgets: `floating_plugin_window.dart`, `plugin_host_drawer.dart`, `flat_host*.dart`.
2. **`lib/features/auth/`:**
   - Services: `google_connection_flow.dart`.
   - Widgets: chuyển thư mục `widgets/auth/` vào `features/auth/presentation/`.
3. **`lib/features/classroom_meet/`:**
   - Services: `google_meet_auth_service.dart`, `google_workspace_api.dart`, `meet_*.dart`, `audio_translation_service.dart`, `system_microphone_service.dart`, `teacher_media_service*.dart`, `media_device_service.dart`, `teaching_launcher.dart`, `webview_environment_service.dart`.
   - Widgets: `google_meet_view.dart`, `meet_admission_*.dart`, `meet_webview.dart`, `system_microphone_controls.dart`, `floating_pip.dart`, `create_classroom_dialog.dart`, và các thư mục `widgets/dashboard/`, `widgets/lobby/`, `widgets/workspace/`.
4. **`lib/features/studio_board/`:**
   - Services: `stroke_clusterer.dart`, `smart_pen_answer_classifier.dart`, `smart_pen_answer_index.dart`, `pdf_annotation_exporter.dart`, `pdf_annotation_handout_exporter.dart`, `dgnl_service.dart`, `english_analyzer.dart`.
   - Widgets: `board_sticker_card.dart`, `floating_pdf_window.dart`, `floating_timer.dart`, `grid_painter.dart`, `interactive_chalkboard.dart`, `pdf_stage.dart`, `pdf_stage_viewer.dart`, `presentation_surface.dart`, `stage_container.dart`, `stroke_canvas.dart`, `subject_tool_palette.dart`, `pdf_dgnl_*.dart`, `region_snipping_*.dart`, `smart_chalk_overlay.dart`, và thư mục `widgets/studio/`.
5. **`lib/features/exams/`:**
   - Services: `exam_api.dart`, `exam_file*.dart`, `exam_oauth_client.dart`, `exam_session_service.dart`.
   - Widgets: chuyển thư mục `widgets/exams/` vào `features/exams/presentation/`.
6. **`lib/core/`:**
   - Platform utils: `desktop_lifecycle*.dart`, `url_opener*.dart`, `local_service.dart`.
   - Common widgets: `google_brand_icon.dart`.

---

## 2. Tiêu Chí Nghiệm Thu

- Không còn file nào trôi nổi ngoài root `lib/services/` và `lib/widgets/`.
- `flutter analyze` báo `0 errors`, `0 warnings`.
- `flutter test` chạy toàn bộ test suite và đạt **100% PASS**.

