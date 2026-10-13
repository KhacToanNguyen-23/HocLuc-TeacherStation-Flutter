# Teacher-only V-ACT / HSA platform

Generated: 2026-10-13. Baseline: `44bb745`, branch `feat/ui-edu-clean-layout`.

## 1. Baseline codebase assessment (before this implementation)

- Client: Flutter/Dart (`frontend/lib`), Manrope/Literata typography, web and Windows targets. Existing screens serve login, classroom/Meet and whiteboard workflows, not exam management.
- Server: Java 17, Spring Boot 3.2.5, controllers/services under `vn.teaching`. Gson/JSON files store classroom and companion data. No JDBC dependency or database access exists yet.
- `backend/db/init.sql` and Docker compose provision PostgreSQL 15 but the API does not use it. Do not alter an existing initialization script as if it were a migration.
- Existing auth is a development prototype: in-memory plaintext passwords, OTP bypass, user IDs regenerated on login, token strings without expiry validation. The bootstrap companion token is publicly obtainable and cannot authorize private teacher data.
- Existing PDF viewer, sample quiz and Meet sessions are not question ingestion, paper generation, or student results. New exam modules must not reuse online classroom sessions as examination records.
- Missing: source versioning/jobs/review, bank, configurable matrices, generation/editor/export, roster/results/import preview, scoring and evidence-based analytics.
- Local generated plugin modifications, legacy app/service folders and AI-training artifacts predate this task and must be retained.

## 2. Architecture

Extend the existing Spring server with `vn.teaching.exam` as a modular monolith and implement native Flutter screens under `frontend/lib/screens/exams`. The existing dashboard opens **Đề thi & năng lực** and reuses the original login UI, Google entry point, session and theme. Same-origin REST remains `/api/exams`; the previous standalone HTML workspace is removed and its URLs redirect to the main app. Password login/signup delegates to a shared persistent session service. The Google button retains develop's WebView flow; the loopback-only bridge creates a separate TEACHER exam-storage session from that local profile without requiring OAuth credentials. Optional server-verified OAuth endpoints remain available for a future configured integration and are not called by the restored dialog. The user confirmed this integration scope.

Modules: identity → sources/review → question bank → matrices → papers/export → rosters/results → analytics. Use Spring JDBC and Flyway; PostgreSQL profile for deployment, embedded H2 file database for immediate local operation, isolated H2 memory database for tests. SQL uses a separate `exam_platform` schema; legacy companion storage is unchanged. PostgreSQL verification must be reported separately from H2 tests.

Identity: persistent teacher/admin accounts, BCrypt passwords, random expiring bearer sessions stored by token digest. Registration grants only TEACHER. Admin provisioning is an explicit environment configuration, no default password. Authorization derives teacher ID from the session, never a request field. Every private read/write checks ownership. APP_WEBVIEW profiles have stable, separate teacher IDs and never inherit same-email password/OAuth accounts or admin grants. The local bridge checks server/client/Host loopback, origin and companion handshake; it trusts the local app profile rather than proving Google identity, and is disabled by default in the PostgreSQL profile. Student records have no account relationship.

Sources: admin-only folder/file picker (`webkitdirectory`), per-file multipart upload and per-file outcome; original relative path is metadata, never a filesystem path. Content-addressed storage/checksum, logical path + exam type/version source revisions, disable and explicit reprocessing. Pipeline retains original PDF and page renders. Text parser emits NEEDS_REVIEW candidates; scanned/unrecognized pages remain visible for manual review. Do not claim OCR/semantic extraction before a configured provider is integrated. Approval requires classification, valid answer, reviewed visual crops, and context linkage. Page/crop images preserve formulas, diagrams and tables without flattening them to plain text.

Matrices: versioned JSON configuration persisted immutably. V-ACT reference: 120 questions/150 minutes, quotas 30/30/30/12/18. HSA: 150/195, quantitative 35 MCQ + 15 short-answer /75 minutes; language 50 MCQ /60; optional branch /60. HSA Science selects three of five topics and needs verified detailed allocation before activation. Reference configurations identify provenance and verification limitations. Scoring is explicitly practice/raw scoring, not official V-ACT IRT conversion.

Generation: approved, active-source questions only; source filters; quotas by section/type/topic/skill/difficulty; atomic context groups; fingerprint deduplication; constrained selection; per-slot shortage diagnostics and separate group-feasibility failures. No invented filler. Each paper stores immutable question/answer/matrix snapshots and stable position-to-question mapping. Editor validates the same rules; published papers are immutable and a new variant is a new draft.

Results: external test session = class + published paper + date, not an online exam. Level A stores every answer and scores against that paper's immutable key. Level B stores only supplied score/count and never creates skill evidence. CSV/XLSX preview is validated, stored with owner/expiry, and committed transactionally exactly once. Reject duplicate, unknown student/paper, bad answer and missing required columns. Blank answer explicitly means unanswered, distinct from a missing column.

Analytics: compute from stored evidence; display attempted/correct counts, percentage, evidence level and assessment date. Separate exam types, report raw/practice score and progress, no official-score prediction or inferred time/behavior. Small samples remain limited evidence. Recommendations reference actual weak skills and eligible existing questions.

## 3. Database schema

Executable schema: `backend/api/src/main/resources/db/migration/V1__exam_platform.sql`.

| Domain | Tables / relationships |
|---|---|
| Identity | accounts (TEACHER/ADMIN only), auth_sessions → accounts, external_identities → accounts (V2 migration) |
| Sources | pdf_sources (checksum, relative path, revision, active), processing_jobs → sources, question_assets → sources, question_groups → sources, questions → source/group, question_reviews → question/account |
| Matrices | matrix_versions (immutable validated config, provenance, state) |
| Papers | papers → teacher + matrix; paper_items → paper, immutable question snapshot and position; export_records → paper |
| Rosters | classes → teacher, students → teacher, class_memberships → class/student |
| Results | exam_sessions → teacher/class/paper, student_results → session/student, answer_records → result + paper position; import_jobs → teacher/session |
| Analytics | derived from answer_records + immutable snapshots initially; materialized snapshots only after measured need |

UUIDs are stable identifiers. Unique keys: account email, PDF checksum, source path/type/version/revision, matrix ID, paper position, teacher student code, membership, session/student result. Foreign keys retain source and assessment lineage. Dates are UTC instants; UI displays local dates.

## 4. API contracts

JSON errors: `{code, message, details}`; HTTP 400 validation, 401 session, 403 admin-only, 404 missing/private resource, 409 conflict/insufficient bank. Bearer auth required on every exam route. Login/registration and Google flow use the existing `/api/auth` namespace. Multipart is only for source and import endpoints.

| Method / `/api/exams` path | Purpose |
|---|---|
| GET `/auth/me`; POST `/auth/logout` | shared application identity/session |
| GET `/dashboard` | owned summary, actual bank counts |
| GET `/sources`; GET `/sources/{id}/pdf` | source metadata/provenance |
| POST `/admin/sources` (file, relativePath, examType, examVersion) | folder upload's individual PDF |
| POST `/admin/sources/{id}/process`; PUT `/admin/sources/{id}/active` | process/reprocess/disable |
| GET `/admin/jobs`; GET `/admin/questions` | processing and review queues |
| POST `/admin/questions`; PUT `/admin/questions/{id}`; POST `/admin/questions/{id}/approve` | review/correct/manual extraction |
| POST `/admin/groups`; POST `/admin/assets/crop` | shared context, reviewed source crop |
| GET `/assets/{id}` | protected image |
| GET `/questions` | approved bank, text/type/section/topic/skill/difficulty/source filters |
| GET `/matrices`; POST `/admin/matrices` | versioned configuration |
| POST `/papers/generate`; GET `/papers`; GET/PUT `/papers/{id}` | generation/list/edit |
| POST `/papers/{id}/publish`; GET `/papers/{id}/export?format=pdf|docx&kind=paper|answers|solutions|matrix` | validated publication/export |
| GET/POST `/classes`; GET/POST `/students`; POST `/classes/{id}/members` | owned roster |
| POST `/students/import/preview`; POST `/students/import/{id}/commit` | roster CSV/XLSX preview |
| GET/POST `/sessions`; GET/POST `/sessions/{id}/results` | external assessments/manual entry |
| POST `/sessions/{id}/import/preview`; POST `/imports/{id}/commit` | CSV/XLSX results preview/commit |
| GET `/analytics?classId=&studentId=&examType=` | evidence/score trends/recommendations |
| GET `/analytics/export?...` | CSV report |

Generator request: `{matrixId, title, sourceIds:[], variants:1, seed, difficulty, skill}`. Editor: `{title,instructions,durationMinutes,questionIds:[]}`. Detailed result: `{studentId, answers:{"1":"A","2":"12.5"}}`; aggregate: `{studentId, score, correctCount}`. Result import: `student_code,exam_id,question_1,...`; aggregate uses `score,correct_count`. Exam ID must match the chosen session's exact paper variant.

## 5. Pages

Teacher: dashboard, bank/detail/source, generator with availability/shortage, editor with matrix validation and export, library, class/student records, results/manual/import preview, analytics/evidence/report. Admin: folder upload/progress/source revisions, jobs, candidate correction/visual crop/group assignment/approval and matrix configuration. All screens have empty/loading/error states and no seeded production questions/results.

## 6. Roadmap / runnable increments

1. Identity + JDBC migrations + source upload/review: login, upload folder, inspect retained page, crop and approve question. Critical tests: role boundary, private ownership, checksum duplicate, corrupt/scan handling, unpublished candidate gate.
2. Matrices + bank + generator/editor + PDF/DOCX: generate from a reviewed bank; missing quotas and indivisible context cannot silently pass; export exact published snapshots. Tests: quota, type, duplicate, group feasibility, disabled source, variant mapping, editable draft/published immutability, raster assets in both formats.
3. Roster + external sessions + manual/import results: create class/student, preview CSV/XLSX, commit and score. Tests: atomic import, duplicates, position mapping, immutable key, aggregate limits and cross-teacher reads/writes.
4. Analytics + recommendations + browser verification: counts/trends/evidence, score-only restriction, targeted question suggestions, responsive pages. Tests: small sample, exam type isolation, empty bank, stale preview, mobile overflow and form interactions.
5. Provider and dataset acceptance: actual source PDFs, configured OCR, verified detailed HSA Science matrix, AI classification with review, semantic duplicate model, production PostgreSQL backups/TLS/rate limits and deployment. These are separate acceptance tasks; runtime fixtures are test data only.

## Risks / rollback

No real PDF corpus supplied yet; user requested admin folder upload. Parser success does not prove real-corpus accuracy. Raster crops preserve appearance but editable mathematical DOCX is a later renderer capability. Validate answer-free crop boundaries before approval. H2 checks do not prove PostgreSQL. Exam APIs require a backend bearer session; bootstrap, demo and legacy WebView marker tokens cannot directly authorize them. The separate local-profile handshake supports develop-style Google login on a loopback workstation and must not be described as production Google authentication. Google OAuth credentials were not found and real-provider acceptance remains pending; native Google account selection also needs a manual check. Never activate unknown official quota rules or report raw V-ACT counts as official 1200-scale scores. Rollback the exam module and new configuration while preserving stored exam database/source files for recovery.

## Reference sources checked 2026-10-13

- https://cetqa.vnuhcm.edu.vn/tin-tuc/cau-truc-de-thi-dgnl-nam-2026-nhu-the-nao-p-43.html
- https://www.hsa.edu.vn/huong-dan/dang-thuc-bai-thi
- https://pdfbox.apache.org/3.0/migration.html
- https://docs.spring.io/spring-boot/docs/3.2.5/reference/html/data.html

Implementation progress and verified limits are recorded in `docs/exam-platform.md` after each delivered increment.
