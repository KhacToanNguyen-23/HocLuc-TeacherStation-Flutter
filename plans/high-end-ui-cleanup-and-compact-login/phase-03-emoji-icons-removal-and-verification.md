# Phase 3: Emoji Icons Removal & Verification

## Objectives
1. Replace hand-raise emoji `✋` in:
   - `frontend/lib/widgets/studio/studio_student_strip.dart` -> `Icon(Icons.pan_tool_outlined)`
   - `frontend/lib/widgets/studio/studio_students_drawer.dart` -> `Icon(Icons.pan_tool_outlined)`
   - `frontend/lib/widgets/studio/studio_meet_cockpit_tab.dart` -> `Icon(Icons.pan_tool_outlined)`
   - `frontend/lib/widgets/studio/studio_inspector_panel.dart` -> `Icon(Icons.pan_tool_outlined)`
2. Clean up emojis in overlays:
   - `frontend/lib/widgets/pdf_dgnl_passage_overlay.dart`: Replace `💡`, `📌` with clean text/icons.
   - `frontend/lib/widgets/floating_pip.dart`: Replace `'✓ '` check with standard Icon or clean text.
3. Run verification test suite and `flutter analyze` to ensure zero compilation or regression errors.

## Verification
- Run `flutter test` or `flutter analyze` on affected files.
