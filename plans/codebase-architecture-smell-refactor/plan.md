# Master Plan: Codebase Architecture & Code Smell Refactoring

**Date:** 2026-10-16
**Mode:** --hard
**Risk:** normal — pure refactoring of oversized components and dead code, no auth/schema risk, verified by 50+ existing tests.

---

## Architecture Overview
The current frontend contains large monolithic screens and dead legacy components that clutter navigation and hinder maintainability. This plan executes a staged deconstruction:

```
[Phase 1: Google Workspace Screen Decomposition]
       ↓ (Extract dialogs & cards to lib/widgets/workspace/)
[Phase 2: Retire Legacy Dead Code (drawer_questions.dart)]
       ↓ (Clean up 1,222 lines of dead code superseded by StudioDocumentDrawer)
[Phase 3: Domain-Driven Services Reorganization]
       ↓ (Organize 41 flat files into services/{meet, audio, exam, google, media, plugins, core})
[Phase 4: Backend Spring Boot Service Decomposition]
       ↓ (Decompose 37KB GoogleClassService.java and consolidate auth)
[Verification Gate: 100% Tests Green at Every Phase]
```

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-16 16:16
**Phase in progress:** complete
**Status:** All 4 phases complete. GoogleWorkspaceScreen decomposed (~65% reduction), legacy drawer_questions.dart retired (-1,222 lines), 7 domain service barrels created, and backend GoogleClassService decomposed into GoogleScheduleService. All 104 backend tests, 155+ frontend tests, and 5 architecture invariants pass cleanly.

### Decisions made this session
- Extracted `GoogleScheduleService.java` for Google Calendar event creation, Hangouts Meet link generation, and attendee sync.
- Refactored `GoogleClassService.java` to act as an orchestrator/facade delegating calendar operations.
- Preserved 100% backward compatibility for all API endpoints and controller mappings.
- Verified all 47 tests in `GoogleIntegrationTest` and all 104 tests across the backend test suite passed with 0 errors.

---

## Phases Summary

- **[x] Phase 1: Google Workspace Screen Decomposition** (`phase-01-google-workspace-decomposition.md`)
  - Target: `frontend/lib/screens/google_workspace_screen.dart` (1,248 lines).
  - Extract dialogs: `workspace_invite_dialog.dart`, `workspace_schedule_dialog.dart`.
  - Extract widgets: `workspace_course_detail.dart`, `workspace_connection_panel.dart`, `workspace_roster_table.dart`, `workspace_events_card.dart`.
  - Target outcome: `google_workspace_screen.dart` reduced by ~65%, 100% tests passing.

- **[x] Phase 2: Retire Dead Legacy Component (drawer_questions.dart)** (`phase-02-retire-legacy-drawer-questions.md`)
  - Target: `frontend/lib/widgets/drawer_questions.dart` (1,222 lines).
  - Discovery: Component is completely unused in `lib/` and superseded by `StudioDocumentDrawer`.
  - Clean up test references in `floating_accessories_test.dart` and remove dead file.
  - Target outcome: Eradicated 1,222 lines of dead debt, 0 regressions, all tests passing.

- **[x] Phase 3: Domain-Driven Services Reorganization** (`phase-03-services-domain-restructuring.md`)
  - Target: 41 flat files in `frontend/lib/services/`.
  - Reorganized into domain barrels: `google/`, `meet/`, `audio/`, `media/`, `plugins/`, `exam/`, `core/`.
  - Created master barrel [services.dart](frontend/lib/services/services.dart) for clean navigation.
  - Target outcome: Clean domain discovery, 100% backward compatibility, 0 broken imports.

- **[x] Phase 4: Backend Spring Boot Cleanup** (`phase-04-backend-spring-boot-cleanup.md`)
  - Target: `backend/api/.../GoogleClassService.java` (443 lines).
  - Decomposed into `GoogleScheduleService.java` (Calendar events & Hangouts Meet link generation) and `GoogleClassService.java` (Classroom courses & direct Meet memberships).
  - Target outcome: Single-responsibility design, 104/104 backend tests passing, 0 regressions.

---

## Invariant Checkpoints (Must Pass Every Phase)
1. `flutter analyze --no-fatal-infos` (0 errors)
2. `flutter test test/architecture_test.dart` (all 5 invariants PASS)
3. `flutter test` (all 50+ test suites PASS)
