# Meet AI tutor
Mode: autonomous implementation of user-confirmed scope
Risk: high-risk — external model API and automatic Meet chat delivery
Status: implemented locally; automated checks passed; live provider/Meet acceptance pending

User confirmed MVP and automatic grounded delivery, then confirmed implementation. Continue without repeated phase approvals. No commit/push or live classroom messaging.

- [x] Phase 1: provider gateway, bounded evidence contract and backend tests.
- [x] Phase 2: lesson context extraction and sequential tutor queue with stale-work guards.
- [x] Phase 3: confirmed Meet delivery and settings integration.
- [x] Phase 4: regression tests, review, architecture/plugin/analyzer gates and limitations documentation.

## Architecture
Feature-first frontend `features/meet_tutor/{domain/models,services,presentation/widgets}`; backend `modules/tutor`. Generic AI gateway accepts immutable provider configuration per request. No plugin names or plugin integration changes. Use existing authenticated local companion transport. One tutor owner per inspector, preserved across tab changes and disposed with inspector.

## Risks
- Meet DOM integration is UI automation and can change; fail closed on unconfirmed delivery.
- Matching source quotations is a structural grounding gate, not proof of semantic correctness. Evaluate held-out classroom questions before production rollout.
- Key is memory-only and must be re-entered after app restart. No plaintext persistence.
- Preserve pre-existing dirty whiteboard and feature-list changes; do not commit unrelated work.

## Session Notes
Updated 2026-10-26: low-confidence tentative explanations auto-send with mandatory uncertainty and absent-source disclosure, no manual approval. Current targeted/regression verification: frontend 63 passed including architecture 12/12; tutor backend 18 passed; DOM bridge 11 passed; plugin validator passed. Flutter analyzer over lib/test and scoped Dart analyzer reported no issues (initial unrestricted analyzer stalled and was stopped). Static review found no blocking issues. Live provider/Meet acceptance remains pending.

Decisions: user update 2026-10-26 permits low-confidence inferred answers to auto-send with mandatory uncertainty labelling, without teacher approval. High-confidence branch retains exact extraction. One adapter for Chat Completions-compatible endpoints, key memory-only, public text allowlist, bounded sequential queue, baseline-before-enable and current-document eligibility. No audio or new OCR. Source quotations establish membership, not semantic correctness. Empty context may call the provider for a tentative answer; failures remain journal-only.

Next acceptance work requires an actual configured provider and a real Meet room/student receiver. No live messages performed; scoped branch delivery is authorized on 2026-10-26. Prior dirty whiteboard work remains untouched. Usage and limits: docs/architecture/meet-ai-tutor.md.

## Scoped branch delivery 2026-10-26

Branch `feat/AI-agent-auto-answer` is based on fresh `origin/develop` b244459. Preserves develop inspector navigation; keeps Meet mounted with IndexedStack. Includes tutor-only source/tests/docs plus CI triggers for this feature branch. Unrelated whiteboard changes and generated/runtime/training data remain in the original worktree.

Local verification: full Flutter suite 618 passed; full backend 161 passed and executable JAR packaged; Flutter analyzer no issues; architecture 12/12; plugin validator 3 packages synchronized; tutor DOM tests 14 passed. Review fixes recover from expired/confirmed attempts and clean only AI-owned composer drafts. GitHub CI must be checked against the pushed SHA; live provider/Meet acceptance is separate.

## Always-feedback update

User requires a visible reply branch for every new student message while active. Added lessonSubject/scope classification and canonical out-of-scope reply, fixed API/invalid-response templates, changed-context notice, repeated-question handling, and fair coalesced overload notices (20 AI slots plus at most two notices). Detailed Meet delivery distinguishes proven no-dispatch from ambiguous sends; only proven cancellation can safely trigger replacement feedback. Local targeted verification: Flutter 73 tests including architecture 12/12, backend tutor 20, bridge 14, plugin validator passed; review has no remaining blockers. Real delivery still requires connected/sendable Meet and is not guaranteed when paused, disconnected or composer busy.
