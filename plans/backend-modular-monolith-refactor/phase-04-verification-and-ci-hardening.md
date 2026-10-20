# Phase 04: Verification & CI Hardening

## Goal
Verify all backend and frontend test suites, architecture invariants, and plugin schemas to ensure zero regression across the entire system.

---

## Detailed Tasks
1. Run backend unit & integration tests (`mvn test -f backend/api/pom.xml`).
2. Run frontend architecture invariants (`flutter test test/architecture_test.dart`).
   - Invariant 6: Java files <= 600 LOC.
3. Run frontend test suite (`flutter test`).
4. Run plugin validator (`node scripts/validate_plugins.mjs`).
5. Run analyzer (`flutter analyze --no-fatal-infos`).

---

## Verification Commands
```powershell
mvn test -f backend/api/pom.xml
flutter test test/architecture_test.dart
flutter test
node scripts/validate_plugins.mjs
flutter analyze --no-fatal-infos
```

