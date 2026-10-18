# Phase 01: Purge Dead Code, Duplicate Models, Facade Subfolders & RAM `files` Map

## Context
- **Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-deep-architecture-cleanup/plan.md)
- **Spec Reference:** User Story 1 (`FR-001`, `FR-002`, `SC-002`, `SC-003`)

## Tasks
- [x] Delete 10 orphaned/duplicate `.dart` files (`studio_stage_mixin.dart`, `studio_canvas_mixin.dart`, `studio_timer_mixin.dart`, `studio_pip_mixin.dart`, `board_stroke.dart`, `imported_document.dart`, `studio_lessons_drawer.dart`, `in_board_extension_bar.dart`, `platform_utils.dart`, `lobby_screen.dart`) and empty `lib/models/mixins/` directory.
- [x] Flatten exports directly into `lib/services/services.dart` and remove the 7 empty 1-file facade subdirectories (`audio/`, `core/`, `exam/`, `google/`, `media/`, `meet/`, `plugins/`).
- [x] Remove `final Map<String, Uint8List> files` from `InstalledPlugin` in `lib/services/plugin_manager.dart`.

