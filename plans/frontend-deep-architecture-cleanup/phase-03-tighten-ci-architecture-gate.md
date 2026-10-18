# Phase 03: Tighten CI Architecture Gate (`<= 900 lines` + Invariant #7)

## Context
- **Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/frontend-deep-architecture-cleanup/plan.md)
- **Spec Reference:** User Story 3 (`FR-004`, `SC-004`)

## Tasks
- [x] Lower `maxDartLines` in `frontend/test/architecture_test.dart` (Bất biến 6) from `1200` to `900`.
- [x] Add Bất biến 7 in `frontend/test/architecture_test.dart` verifying 0 orphaned `.dart` files in `lib/` and no in-memory `Map<String, Uint8List> files` field in `InstalledPlugin`.
- [x] Run `flutter analyze --no-fatal-infos` and `flutter test test/architecture_test.dart test/studio_test.dart test/exam_integration_test.dart`.

