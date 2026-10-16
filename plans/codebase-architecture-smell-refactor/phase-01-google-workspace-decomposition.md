# Phase 1: Google Workspace Screen Decomposition

**File:** `plans/codebase-architecture-smell-refactor/phase-01-google-workspace-decomposition.md`
**Target:** `frontend/lib/screens/google_workspace_screen.dart` (1,248 lines)

---

## 1. Goal
Decompose the 1,248-line monolithic screen into modular sub-widgets under `frontend/lib/widgets/workspace/`, reducing the main screen orchestrator to under 250 lines while preserving 100% of the UI, state flow, and behavior.

---

## 2. Extraction Breakdown

### Component 1: `WorkspaceInviteDialog`
- Location: `frontend/lib/widgets/workspace/workspace_invite_dialog.dart`
- Responsibility: Form dialog for creating a classroom and inviting students by parsing multi-line email inputs.
- Extracted lines: ~150 lines from `_showInviteDialog`.

### Component 2: `WorkspaceScheduleDialog`
- Location: `frontend/lib/widgets/workspace/workspace_schedule_dialog.dart`
- Responsibility: Dialog for scheduling Meet calendar session with date/time pickers and duration.
- Extracted lines: ~150 lines from `_schedule`.

### Component 3: `WorkspaceShareLessonDialog`
- Location: `frontend/lib/widgets/workspace/workspace_share_lesson_dialog.dart`
- Responsibility: Dialog for posting lesson coursework announcement to Google Classroom.
- Extracted lines: ~100 lines from `_shareLesson`.

### Component 4: `WorkspaceCourseCard` & `WorkspaceRosterCard`
- Location: `frontend/lib/widgets/workspace/workspace_course_card.dart`
- Responsibility: Rendering individual course items, meeting links, copy buttons, and action buttons.

---

## 3. Verification Plan
- `flutter analyze --no-fatal-infos`
- `flutter test test/google_workspace_test.dart`
- `flutter test test/architecture_test.dart`
