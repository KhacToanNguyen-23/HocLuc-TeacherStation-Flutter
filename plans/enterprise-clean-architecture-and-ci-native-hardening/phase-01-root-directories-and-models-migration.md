# Phase 01: Di dời Data Models & Core Utilities

## Mục tiêu
Loại bỏ hoàn toàn thư mục `lib/models/`, `lib/theme/`, `lib/constants/`, `lib/utils/` tại root và di chuyển toàn bộ file về đúng feature/core.

## Các công việc cụ thể
1. **Di dời Models vào từng Feature:**
   - Tạo thư mục `lib/features/<module>/domain/models/` cho 5 modules.
   - `lib/models/plugin_manifest.dart` ➔ `lib/features/plugin_engine/domain/models/plugin_manifest.dart`
   - `lib/models/subject_plugin.dart` ➔ `lib/features/plugin_engine/domain/models/subject_plugin.dart`
   - `lib/models/meet_events.dart` ➔ `lib/features/classroom_meet/domain/models/meet_events.dart`
   - `lib/models/planning_meta.dart` ➔ `lib/features/classroom_meet/domain/models/planning_meta.dart`
   - `lib/models/teaching_target.dart` ➔ `lib/features/classroom_meet/domain/models/teaching_target.dart`
   - `lib/models/board_sticker.dart` ➔ `lib/features/studio_board/domain/models/board_sticker.dart`
   - `lib/models/smart_chalk_annotation.dart` ➔ `lib/features/studio_board/domain/models/smart_chalk_annotation.dart`
   - `lib/models/smart_pen_answer_selection.dart` ➔ `lib/features/studio_board/domain/models/smart_pen_answer_selection.dart`
   - `lib/models/smart_pen_oval_annotation.dart` ➔ `lib/features/studio_board/domain/models/smart_pen_oval_annotation.dart`
   - `lib/models/studio_board_models.dart` ➔ `lib/features/studio_board/domain/models/studio_board_models.dart`
   - `lib/models/studio_state.dart` (và các part-of: `studio_state_annotations.dart`, `studio_state_pdf.dart`, `studio_state_plugins.dart`, `studio_state_smart_pen.dart`) ➔ `lib/features/studio_board/domain/models/studio_state*.dart`
2. **Hợp nhất Theme & Utils vào Core:**
   - Di chuyển `lib/theme/*.dart` vào `lib/core/theme/`
   - Di chuyển `lib/constants/theme.dart` vào `lib/core/constants/`
   - Di chuyển `lib/utils/*.dart` vào `lib/core/utils/`
3. **Cập nhật Import Statements:**
   - Cập nhật tất cả các file trong `lib/` và `test/` đang import từ `package:teaching_companion/models/...`, `package:teaching_companion/theme/...`, `package:teaching_companion/constants/...`, `package:teaching_companion/utils/...`.
4. **Xóa thư mục cũ:**
   - Xóa bỏ hoàn toàn `lib/models/`, `lib/theme/`, `lib/constants/`, `lib/utils/`.

## Tiêu chí hoàn thành (Verification)
- `lib/models/`, `lib/theme/`, `lib/constants/`, `lib/utils/` không còn tồn tại trên đĩa.
- `flutter analyze --no-fatal-infos` (0 errors, 0 warnings).

