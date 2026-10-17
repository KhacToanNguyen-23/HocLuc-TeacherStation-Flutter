# Brainstorm: GitHub Actions Monorepo CI Pipeline for Teacher Station

**Date:** 2026-10-16

## Ideas Explored
- **Polyrepo (Splitting Frontend & Backend into 2 Git Repositories)**: Discussed. Dismissed for now to avoid cross-repo PR coordination overhead, duplicate issue trackers, and version mismatch while active feature development is ongoing with plugins.
- **Monorepo with Single Monolithic Pipeline**: Dismissed because changes in Flutter should not wait for Maven builds, and changes in Spring Boot should not wait for Flutter tests.
- **Monorepo with Decoupled Path-Triggered GitHub Actions Workflows**: Chosen. Separate `ci-backend.yml` and `ci-frontend.yml` triggered independently via path filters (`backend/api/**` vs `frontend/**` + `plugins/**`).

## User's Direction
The user confirmed keeping the monorepo architecture and implementing two independent CI workflows for Pull Requests. The user also noted this is their first time deploying CI for the team, requiring step-by-step guidance, and confirmed that separating into two repos later remains trivial if needed due to clean folder isolation.

## Open Questions
- Target branch protection rules: whether PR merge should be hard-blocked by required status checks on `main`/`develop`.
- Caching strategy for Maven (`~/.m2`) and Flutter Pub cache (`~/.pub-cache`) to keep execution time under 3-4 minutes.

## Risks
- Flutter tests that depend on Windows-specific native APIs (like `webview_windows` or `camera_windows`) failing in Linux headless runner if not properly mocked.
- Spring Boot integration tests requiring external database or active ports if H2/in-memory configuration isn't strictly isolated for tests.
