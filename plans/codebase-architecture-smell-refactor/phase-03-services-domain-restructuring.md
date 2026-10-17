# Phase 3: Domain-Driven Services Reorganization

**File:** `plans/codebase-architecture-smell-refactor/phase-03-services-domain-restructuring.md`
**Target:** 41 flat files in `frontend/lib/services/`

---

## 1. Domain Grouping Mapping
- `services/audio/`:
  - `audio_translation_service.dart`, `system_microphone_service.dart`
- `services/meet/`:
  - `meet_automation_service.dart`, `meet_bridge_script.dart`, `meet_admission_bridge_script.dart`
- `services/exam/`:
  - `exam_api.dart`, `exam_files.dart`, `exam_files_native.dart`, `exam_files_web.dart`, `exam_oauth_client.dart`, `exam_session_service.dart`
- `services/google/`:
  - `google_workspace_api.dart`, `google_meet_auth_service.dart`, `google_connection_flow.dart`
- `services/media/`:
  - `camera_broadcast_service.dart`, `media_device_service.dart`, `teacher_media_service.dart`, `teacher_media_service_native.dart`, `teacher_media_service_web.dart`, `virtual_media_bridge.dart`
- `services/plugins/`:
  - `plugin_manager.dart`, `plugin_storage_manager.dart`, `process_supervisor.dart`, `sidecar_manager.dart`, `sidecar_manager_native.dart`, `sidecar_manager_web.dart`, `host_bridge.dart`
- `services/core/`:
  - `local_service.dart`, `teaching_launcher.dart`, `webview_environment_service.dart`, `desktop_lifecycle.dart`, `url_opener.dart`, etc.

---

## 2. Backward Compatibility
- Create `services/services.dart` barrel file exporting domain services to preserve stability for existing imports.
