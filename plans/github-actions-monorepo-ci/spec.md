# Spec: GitHub Actions Monorepo CI Pipeline for Teacher Station

**Date:** 2026-10-16
**Status:** Ready

---

## Problem Statement
The team currently lacks automated pull request validation in their monorepo. This allows broken code, failing tests, and architecture violations (such as direct imports between frontend and plugins) to merge unchecked into the main branch.

---

## User Stories

- **[P1]** As a Developer, I want an automated GitHub Action workflow to test Spring Boot (`backend/api`) on PRs modifying backend files so that broken APIs and regressions are caught before review.
  Accepted when: `ci-backend.yml` executes `mvn clean test` on `ubuntu-latest` with JDK 17 whenever files under `backend/api/**` are changed in a PR.

- **[P1]** As a Developer, I want an automated GitHub Action workflow to analyze and test Flutter (`frontend`) on PRs modifying frontend or plugin files so that syntax errors, linting issues, and broken widget/architecture tests are caught before review.
  Accepted when: `ci-frontend.yml` executes `flutter pub get`, `flutter analyze --no-fatal-infos`, and `flutter test` on `ubuntu-latest` whenever files under `frontend/**` or `plugins/**` are changed in a PR.

- **[P1]** As a Team Lead / Maintainer, I want step-by-step guidance on how to commit these workflows and enable GitHub branch protection so that I can lead the team with confidence.
  Accepted when: Complete documentation is provided detailing the workflow syntax, how Git triggers them, and how to configure GitHub settings.

- **[P2]** As a Developer, I want Maven dependency caching and Flutter pub caching configured in CI so that pipeline runs complete quickly (under 3 minutes) without re-downloading standard dependencies.
  Accepted when: Actions use `actions/cache` or native `setup-java` / `subosito/flutter-action` cache options.

- **[P3]** _(out of scope — noted for future)_
  Automated Docker image publishing to registry on release tags, CD deployment to staging/production server, and automated Windows release installer `.msix` builds.

---

## Functional Requirements

1. FR-01: Create `.github/workflows/ci-backend.yml` triggered on `pull_request` and `push` to `[main, develop]` with path filter restricted to `backend/api/**`.
2. FR-02: `ci-backend.yml` must set up Java 17 (Temurin distribution), enable Maven dependency caching, and run `mvn test` from `backend/api`.
3. FR-03: Create `.github/workflows/ci-frontend.yml` triggered on `pull_request` and `push` to `[main, develop]` with path filter covering `frontend/**` and `plugins/**`.
4. FR-04: `ci-frontend.yml` must set up Flutter (matching SDK `>=3.10.0`), enable pub dependency caching, run `flutter pub get`, `flutter analyze`, and `flutter test`.
5. FR-05: Ensure architectural tests (`flutter test test/architecture_test.dart`) execute and validate plugin boundary invariants defined in `AGENTS.md`.

---

## Non-Functional Requirements

- Performance: Each workflow should complete execution in under 4 minutes with warm cache on GitHub-hosted runners.
- Cost: Use `ubuntu-latest` runners to minimize GitHub Actions quota consumption.
- Reliability: Workflows must only run when their respective domain files change (no unnecessary runs).

---

## Success Criteria

- [ ] Backend CI passes `mvn clean test` successfully in GitHub Actions.
- [ ] Frontend CI passes `flutter analyze` and `flutter test` successfully in GitHub Actions.
- [ ] PR modifying only `frontend/` triggers ONLY `ci-frontend.yml` and skips backend CI.
- [ ] PR modifying only `backend/` triggers ONLY `ci-backend.yml` and skips frontend CI.

---

## Out of Scope

- Automated CD / deploy pipeline to VPS or Cloud.
- Building native Windows `.exe` / `.msix` desktop installers in CI.
- SonarQube / SAST security scanning integration (can be added in phase 2).

---

## Assumptions

- Tests in `backend/api` can run without a live Postgres server (using embedded H2 or mocked repositories for CI unit tests).
- Flutter unit and widget tests can run in headless Linux mode without physical audio/video devices or Windows WebView binaries.

---
