# Brainstorm: Codebase Architecture & Code Smell Refactoring

**Date:** 2026-10-16

## Ideas Explored
- **Option 1: Backend-First Refactoring**: Restructure Spring Boot packages (`vn.teaching`), break down 37KB `GoogleClassService.java`, and consolidate scattered auth logic. Dismissed as first priority because Frontend has immediate cognitive and UI rendering overhead.
- **Option 2: Frontend-First: Services Grouping First**: Move 41 flat files into domain subfolders first. Dismissed by user in favor of tackling the biggest God Components first.
- **Option 3: Frontend-First: God Components First, then Services, then Backend (Chosen)**:
  1. Deconstruct massive Frontend God Components (`google_workspace_screen.dart` 49KB and `drawer_questions.dart` 43.4KB) into modular, testable sub-widgets.
  2. Organize 41 flat service files in `frontend/lib/services/` into domain modules (`audio/`, `meet/`, `exam/`, `google/`, `media/`, `plugins/`, `core/`).
  3. Clean up Spring Boot Backend: Decompose `GoogleClassService.java` (37KB) and organize package structure.

## User's Direction
The user decided on the sequence:
1. Category 2 (God Components in Frontend) first.
2. Category 1 (Services domain-driven folder structure) second.
3. Backend Spring Boot architectural refactoring third.
Strict requirement: Pure refactoring with 100% preservation of UI/UX, business logic, and test suite green status (`flutter test` and architecture invariants).

## Open Questions
- Target file size threshold for components (recommended: keep individual widget files under 300 lines).
- State management pattern consistency across extracted widgets (keep StatefulWidget or pass callbacks/ValueNotifiers).

## Risks
- Breaking widget tree hierarchy or losing state across re-renders when extracting stateful sub-widgets.
- Test regressions on existing 50+ Flutter tests that query specific widget keys or types.
