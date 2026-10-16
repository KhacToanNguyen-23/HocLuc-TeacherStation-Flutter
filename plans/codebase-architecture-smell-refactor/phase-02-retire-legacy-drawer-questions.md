# Phase 2: Retire Dead Legacy Component (drawer_questions.dart)

**File:** `plans/codebase-architecture-smell-refactor/phase-02-retire-legacy-drawer-questions.md`
**Target:** `frontend/lib/widgets/drawer_questions.dart` (1,222 lines)

---

## 1. Goal
Safely remove 1,222 lines of dead debt from `frontend/lib/widgets/drawer_questions.dart` which has been superseded by `frontend/lib/widgets/studio/studio_document_drawer.dart`.

---

## 2. Execution Steps
1. Update `frontend/test/floating_accessories_test.dart` to assert directly on `StudioDocumentDrawer` instead of the legacy `DrawerQuestions`.
2. Verify zero other imports in `frontend/lib/` or `frontend/test/`.
3. Safely delete `frontend/lib/widgets/drawer_questions.dart`.
4. Run `flutter test test/floating_accessories_test.dart` and `flutter test test/architecture_test.dart`.
