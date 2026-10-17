# Spec: Codebase Architecture & Code Smell Refactoring

**Date:** 2026-10-16
**Status:** Ready

---

## Problem Statement
The codebase contains extreme "God Components" (e.g. `google_workspace_screen.dart` ~1,200 lines, `drawer_questions.dart` ~1,000 lines) and an unorganized flat `services/` directory containing 41 files without domain grouping. This creates cognitive overload, slow developer onboarding, high risk of regression, and poor re-render performance.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a Flutter Developer, I want `google_workspace_screen.dart` (49KB) decomposed into focused sub-widgets under `frontend/lib/widgets/workspace/` so that I can understand and modify workspace features without scrolling through 1,200 lines.
  Accepted when: The main screen file is reduced to under 300 lines of orchestration, sub-components are cleanly encapsulated, and existing tests in `test/google_workspace_test.dart` pass without failure.

- **[P1]** As a Flutter Developer, I want `drawer_questions.dart` (43.4KB) decomposed into dedicated sub-widgets under `frontend/lib/widgets/questions/` so that question inspection, options, and submission logic are modularized.
  Accepted when: `drawer_questions.dart` is decomposed into discrete widgets under 250 lines each and question-related widget tests pass.

- **[P1]** As a Developer, I want the 41 flat files in `frontend/lib/services/` reorganized into clear domain subdirectories (`audio/`, `meet/`, `exam/`, `google/`, `media/`, `plugins/`, `core/`) with export barrels so that finding and maintaining services is intuitive.
  Accepted when: Files are moved to appropriate domain folders, barrel files provide backward compatibility, and all 50+ Flutter tests and `architecture_test.dart` pass.

- **[P2]** As a Backend Developer, I want `GoogleClassService.java` (37KB) in Spring Boot refactored into smaller, cohesive service classes (e.g., Sync, Coursework, Roster) so that Google Classroom integration is maintainable.
  Accepted when: `GoogleClassService.java` is decomposed into single-responsibility services and `mvn test` passes.

- **[P3]** _(out of scope — noted for future)_
  Migrating toàn bộ State Management sang Riverpod/Bloc; Viết lại database migration; Tái cấu trúc package toàn bộ backend Spring Boot.

---

## Functional Requirements

1. FR-01: Extract sub-widgets from `google_workspace_screen.dart` into `lib/widgets/workspace/`:
   - `workspace_header_bar.dart`
   - `workspace_course_sidebar.dart`
   - `workspace_coursework_view.dart`
   - `workspace_student_roster.dart`
2. FR-02: Extract sub-widgets from `drawer_questions.dart` into `lib/widgets/questions/`:
   - `question_card_view.dart`
   - `question_option_selector.dart`
   - `question_answer_explanation.dart`
3. FR-03: Group `lib/services/` into domain subfolders:
   - `services/audio/`
   - `services/meet/`
   - `services/exam/`
   - `services/google/`
   - `services/media/`
   - `services/plugins/`
   - `services/core/`
4. FR-04: Maintain barrel export in `lib/services/services.dart` to minimize breakages in existing imports.
5. FR-05: Maintain 100% UI, visual layout, and behavioral parity (Pure Refactor).

---

## Non-Functional Requirements

- Verification: Run `flutter test test/architecture_test.dart` and `flutter test` after each phase.
- Code Size: No extracted widget file exceeds 350 lines of code.
- Performance: Widget re-renders should be localized without full-screen redraws.

---

## Success Criteria

- [ ] `google_workspace_screen.dart` reduced from ~1,200 lines to < 300 lines.
- [ ] `drawer_questions.dart` reduced from ~1,000 lines to < 300 lines.
- [ ] `lib/services/` flat file count reduced from 41 to organized domain subfolders.
- [ ] All 50+ Flutter tests pass (`flutter test`).
- [ ] Architecture invariants test passes (`flutter test test/architecture_test.dart`).

---

## Out of Scope

- Introducing new third-party state management libraries (e.g., Riverpod, Bloc, MobX).
- Redesigning visual themes, colors, or UI elements.
- Altering Spring Boot REST API schemas.

---

## Assumptions

- Existing test suite covers key interaction flows for Google Workspace and Question drawers.
- Pure code extraction without changing internal state variable names preserves all existing behaviors.

---
