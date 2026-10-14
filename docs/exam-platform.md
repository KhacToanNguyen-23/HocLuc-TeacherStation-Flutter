# Mộc · Teacher-only V-ACT / HSA workspace

This module extends the existing Flutter application and Java 17 / Spring Boot server. Open the visible **Đề thi & năng lực** card on the existing home dashboard. Its six teacher shortcuts open the corresponding tool directly; verified ADMIN sessions also expose source upload/review and matrices. The dashboard header has a labeled entry, and the teaching toolbar has **Đề thi** to open the same workspace while retaining the current board. It uses the same login form, Google button, teacher session and Manrope/theme as the rest of Mộc. The former standalone HTML workspace has been removed; `/exams/**` redirects to the Flutter application at `/`. No student account, student examination page, submission service or live invigilation was added.

## Start on this Windows machine

From `D:\Projects\HocLuc-Teacher`:

```powershell
.\scripts\Start-ExamPlatform.ps1
```

Open `http://127.0.0.1:47831/`. The first run builds the JAR and Flutter web preview, creates a local admin with a random password, and stores that credential encrypted with Windows DPAPI at `.run/exam-admin.credential.xml`. A separate PowerShell terminal can display the local admin login:

```powershell
.\scripts\Start-ExamPlatform.ps1 -ShowAdminCredential
```

Default local admin email: `admin@hocluc.local`. This is a technical account, not a default shared password. Supply `-AdminEmail` and `-AdminPassword (Read-Host -AsSecureString)` to choose a different credential. An existing ADMIN account's password is updated only when the configured bootstrap password changes; existing teacher emails are never promoted. Changing the password revokes existing sessions. Treat the encrypted credential as private local runtime data, not an artifact to distribute. The environment-based bootstrap must be removed or managed through secrets when deploying.

Use `-Port 47832` if the companion server already occupies 47831. The Flutter build receives that backend URL. Use `-SkipBuild` only after a successful build for the same port. Use the existing Mộc login/signup form. Only TEACHER can be self-registered. The module has no second login form. Google login follows the `develop` WebView flow; when opening exams, the app automatically creates or renews a local teacher workspace session, including for a stored older Google profile. Demo sessions cannot access exams.

## Upload a directory of PDFs

1. Log in as admin; open **Nguồn PDF & duyệt**.
2. Choose V-ACT or HSA and the exam year/version.
3. Choose the entire folder. The browser sends PDFs inside nested directories; non-PDF files are skipped. A second picker accepts multiple PDFs if directory selection is unavailable. Windows uses the native directory picker; Flutter web uses `webkitdirectory`.
4. Confirm the selected folder and exam type/year. Each file reports uploaded, checksum duplicate, or its own error. Upload errors do not discard successful files.
5. Use **Tải lại** to refresh when needed, then **Xử lý** per source. Limits are 30 MB and 300 pages per PDF. Original directory names are metadata only; files are stored by SHA-256 under `backend/api/data/exam-sources`.
6. Click **Duyệt câu**. Text PDF parsing detects `Câu N.` / `Question N.` and A–D candidates. The original PDF and rendered pages remain available. Scans/unrecognized pages require manual creation from the image; `NEEDS_OCR` explicitly indicates OCR has not run.
7. Drag a rectangle on a page or enter crop pixel coordinates. Select question/context or separate solution image. Crop all pages needed for the question. Exclude original question numbering where possible and exclude answers/solutions from the paper image. Separate image crops preserve mathematics, tables and diagrams in exports.
8. Correct stem/options/answer, section ID matching the matrix, topic, skill, cognitive level and difficulty. Use **Dùng ảnh cắt làm ngữ cảnh chung** to attach passage/table crops to a group; assign the same group ID to all its questions. Group creation is immutable, and a group only enters generation when all members are reviewed and eligible.
9. Confirm visual/context review and answer-free paper crops; save/approve. Candidates with missing data never enter the teacher bank. An approved question is immutable: clone it for corrections. Duplicate fingerprints are excluded during generation.

Source replacement uses the same relative path + exam type/year with different bytes to create a new revision. Identical checksum returns the original source, even if uploaded under a different name: it is not silently reclassified. Disable superseded sources explicitly. Reprocessing retains previously reviewed records and never approves new candidates automatically.

## Generate, edit and export

The configuration file `backend/api/src/main/resources/exam-matrices.json` supplies versioned reference matrices. Algorithms consume their quotas; counts are not embedded in selection code. Admin adds immutable matrix revisions through **Cấu hình ma trận**. Rules can filter section, MCQ/SHORT, topic, skill and difficulty; overlapping quotas are rejected.

- V-ACT 2026 reference: 120 questions, 150 minutes, quotas 30/30/30/12/18.
- HSA 2026 English reference: 150 questions, 195 minutes, quantitative 35 MCQ + 15 SHORT, language 50 MCQ, English 50 MCQ. This is a reference at section/type level; detailed topic/skill allocations require reviewed configuration.
- HSA Science reference remains DRAFT. Activation requires verified quotas for exactly three of physics/chemistry/biology/history/geography. Fine-grained subject allocation is not guessed.

Choose matrix, source subset, variants and optional filters. Shortages report each quota's required/available/missing count. Indivisible contexts can produce a distinct group/quota conflict even if raw counts look sufficient. A bounded search reports SEARCH_LIMIT rather than claiming infeasibility when its budget is exhausted. No generated filler is used.

Draft title/instructions are editable. Reordering moves an entire shared-context block. Single questions can be replaced with reviewed questions, followed by the same matrix validation; the Flutter editor also replaces a complete group with a reviewed group of matching size and types. Changing time away from the matrix is rejected until corrected or a separate practice matrix is used. Publish freezes the paper, matrix, ordered question and answer snapshots; exact paper UUID is the variant ID for results.

Published papers export PDF/DOCX separately as paper, answer key, solutions or matrix. Paper exports include only question/context crops, not the stored solution crops. Mathematics/figures remain raster images, including in DOCX; they are preserved visually rather than editable Word equations. Unicode titles and textual solutions use the bundled Manrope font. Published snapshots remain exportable after a source is disabled, so historical results remain reproducible. ZIP export supports 1–20 selected published papers owned by the current teacher.

## Classes, results and analytics

Create a class, add students or import UTF-8 CSV/XLSX with `student_code,full_name,notes`. Preview before committing. Stable student codes are unique per teacher; student records never become login accounts. Membership transfers retain existing results under their original assessment class.

Create an external assessment from a class + published paper + assessment date. Enter:

- Detailed answers: all question positions must be present; blank cells mean unanswered. MCQ accepts A–D, case-insensitive. Numeric short answers normalize comma/dot decimal notation without inventing a tolerance. Additional short-answer equivalents must be explicitly reviewed. Scoring uses the immutable paper key.
- Aggregate results: total practice score and/or correct count. Both fields, if provided, must agree with the configured practice scoring policy. No answer records or skill evidence are created.

Results CSV/XLSX must contain `student_code,exam_id,question_1,...`, with exact paper UUID. Aggregate import uses `student_code,exam_id,score,correct_count`. The results page downloads a template for that paper and not-yet-recorded students. Missing columns differ from blank answers. Unknown students, wrong variants, bad choices, duplicate students/results and formula Excel cells are rejected. Preview is owner-bound, expires after 30 minutes, revalidates at commit, and commits all rows in one transaction exactly once.

Analytics shows score history, percentages and actual evidence counts by skill/topic/section/difficulty. Statistics and averages are separated by exam type. Under 10 questions is labeled LIMITED; trend requires at least 10 ordered observations. Weak-skill recommendations require enough detailed evidence and list existing approved questions. **Tạo bộ ôn kỹ năng này** creates an explicitly marked PRACTICE matrix and draft from the reviewed bank, retaining groups and duplicate checks. These practice sets can be exported, assessed externally and imported again for progress comparison. CSV report export escapes spreadsheet formulas.

V-ACT raw correct count is never presented as its official 1200-scale score. No calibrated official-score prediction, response-time or behavior inference is implemented.

## Storage and API

`vn.teaching.exam` contains identity, sources/review, matrices, papers/export, results and analytics services. `ExamController` exposes the implemented contracts. `ExamRepository` uses Spring JDBC, normalized ownership/relationship columns and immutable JSON snapshots. Flyway migration `V1__exam_platform.sql` creates only a separate `exam_platform` schema; `backend/db/init.sql` was not rewritten.

Local data defaults to H2 file database `backend/api/data/exam-platform.mv.db`; tests use memory databases. Environment variables:

| Variable | Purpose |
|---|---|
| EXAM_DB_URL, EXAM_DB_USER, EXAM_DB_PASSWORD | JDBC database connection |
| EXAM_STORAGE | PDF/page/crop storage path |
| EXAM_ADMIN_EMAIL, EXAM_ADMIN_PASSWORD | Explicit technical admin bootstrap |
| GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET | Backend Google OAuth web application credentials |
| GOOGLE_REDIRECT_URI | Exact authorized callback; local default `http://127.0.0.1:47831/api/auth/google/callback` |
| APP_ADMIN_EMAILS | Comma-separated verified Google emails authorized as administrators |

For existing PostgreSQL infrastructure use the `postgres` profile and set database credentials, for example `--spring.profiles.active=postgres`. Flyway creates the separate schema without adopting legacy public tables. Do not confuse a successful H2 run with a PostgreSQL acceptance run. Back up both database and source storage together.

REST authentication reuses the existing app login through `/api/auth/login` and `/api/auth/register`. A shared persistent session service backs these endpoints and `/api/exams`. The companion token alone is not an exam bearer token. The local WebView bridge uses it together with loopback server/client/host and local-origin checks to create a TEACHER storage session. This trusts the app's local profile, not a Google identity verified by the server. Self-registration is teacher-only. Passwords use BCrypt; sessions contain 32 random bytes, are stored by digest, expire after eight hours, and can be revoked. Admin source/review/matrix endpoints enforce ADMIN independently. API routes and payloads are listed in [the implementation plan](../plans/teacher-only-exam-platform-plan.md).

## Verification

```powershell
cd D:\Projects\HocLuc-Teacher\backend\api
mvn test
mvn -DskipTests package
```

`ExamPlatformTest` covers identity stability/role/expiry, teacher isolation, checksum/revision, corrupt/scan sources, review gates, exact quotas, context feasibility, duplicate questions, immutable snapshots, PDF/DOCX images and Unicode, separate solution crops, practice sets, ZIP ownership, detailed/aggregate scoring, evidence limits, transactional CSV/XLSX imports, stale/expired previews and membership history. Existing companion tests are also retained.

Flutter integration verification:

```powershell
cd D:\Projects\HocLuc-Teacher\frontend
flutter test test/exam_integration_test.dart test/auth_modal_test.dart test/classroom_dashboard_test.dart
flutter build web --no-pub --no-wasm-dry-run
```

The integration suite checks that the existing dashboard opens the native module with the same bearer session, Google provider/app tokens remain separate, offline login fails, demo access is refused, teacher accounts lack admin navigation, and all nine admin tabs render at 375/414/768/1024/1440 widths. The previous standalone HTML browser script is archived under ignored `.run/`; its earlier results do not validate this Flutter UI.

## Google login compatibility with develop

The Google dialog has been restored from `develop`: Windows opens the existing Edge WebView2 account chooser and retains its Google cookies; other platforms use the existing email-confirmation fallback. Login does not call the OAuth start endpoint and does not require Google Client ID/Secret. As in `develop`, the WebView marker describes an app-owned local profile, not a Google API access token or server-verifiable identity.

`ExamApi` lazily calls `/api/auth/google/webview-session` using the local companion handshake, then stores the returned exam bearer token with the current app profile. Concurrent calls share the handshake. A rejected/expired local exam session is renewed once and the request is retried; an unavailable backend leaves the Google app login intact. A response arriving after logout/account switching is discarded. The marker itself is never sent as an exam bearer token.

Compatibility is limited to a server explicitly bound to loopback, a loopback client/Host and a native request or loopback web origin. `APP_WEBVIEW_LOCAL_ENABLED=false` disables it; the PostgreSQL profile defaults it off. `APP_WEBVIEW` profiles have separate stable teacher account IDs and do not link to same-email password/OAuth accounts or inherit `APP_ADMIN_EMAILS` grants. Existing password/OAuth exam data stays with those original accounts. Local users can assert an email just as in develop's fallback, so this is local workstation functionality, not production Google authentication. The optional authorization-code OAuth endpoints remain available for verified login integrations, but the restored Google dialog no longer uses them.

Legacy OTP delivery/verification remains a development mock. Its ephemeral OTP-only token cannot authorize exam records. Production OTP delivery and verification need a real provider; password registration still uses the pre-existing development OTP path. The integrated module accepts password, verified OAuth and local WebView workspace sessions. Real Google API/Meet access permissions are a separate integration.

## Current local validation

Commit preparation on 2026-10-13 re-ran 50 backend tests and 28 targeted Flutter tests with no failures. Scoped Dart analysis of the changed screens, services, widgets and tests reported no issues. Separate exports of the staged backend source compiled through the identity, source-review and paper-export increments; the staged results/analytics increment passed 45 backend tests before local WebView compatibility was added. The staged Flutter UI increment passed 21 targeted tests before the compatibility and backend-failure fixes were added. These checks use source snapshots and local fixtures, not a real Google provider or production deployment.

The final backend package passed 50 tests with no failures or errors (including 5 loopback WebView compatibility tests). The frontend passed 23 checks: 22 auth/dashboard/exam/teaching-shell tests and one visual-render check. Windows release and Flutter web builds both completed. Startup was checked against the existing file database without replacing it; the main app login and exam API returned the same stable identity. The new local-profile route is present in the running backend.

The dashboard now exposes exam tools directly, and the teaching toolbar opens the same workspace while retaining its board. The admin render under ignored `.run/exam-home-admin.png` is a Flutter UI render with fixture identity, not a screenshot of a real teacher's data. To use the newly built native client, open `frontend/build/windows/x64/runner/Release/teaching_companion.exe`, or use `r` in an existing `flutter run` terminal to reload its UI. Keep exactly one backend instance running on 47831.

## Earlier validation and remaining acceptance work

Verified 2026-10-13: Maven package completed with 45 tests (32 exam module + 6 shared identity/OAuth + 7 existing companion), zero failures/errors. Shared identity tests use a mocked Google provider and verify state/proof, replay rejection, existing-account ownership, server-controlled admin grants and rejection of the previous WebView marker. They are not proof of real Google login. PDFBox/POI tests inspected exported Unicode text and embedded question/solution images. Flutter web builds successfully; the Windows release was also built locally at `frontend/build/windows/x64/runner/Release/teaching_companion.exe`; all 22 Flutter auth/dashboard/exam integration and teaching-shell tests pass and scoped Dart analysis reports no issues. All nine tabs were exercised at 375/414/768/1024/1440 widths. The browser preview also verified the existing password login, dashboard entry, native overview and admin folder-upload screen and individual PDF upload against an isolated memory database. Integration test/analyzer results are recorded under ignored `.run/`. The file-backed runtime retains existing exam data and applies the Google-identity migration. The added UI checks cover direct dashboard navigation to the selected tool, role-limited admin shortcuts, legacy/expired session return to the existing login form, and opening exam tools from the teaching toolbar without changing the board. Main app password login was checked against `/api/exams/auth/me` and dashboard with matching stable identity.

No actual PDF corpus has been supplied. Real-corpus extraction accuracy and scan OCR automation remain unverified. Automatic formula detection/OCR, semantic classification, near-duplicate embeddings, sophisticated reports, verified detailed HSA Science/topic allocations and production deployment are subsequent increments. Current extraction is deliberately review-first and scan support is manual from retained images.

Docker engine was unavailable during the implementation session, so PostgreSQL execution was not verified. Local memory/file H2 checks, document inspection and browser evidence are reported separately. Legacy OTP remains development code as described above. The source is organized into topic commits on `feat/vact-hsa-exam-platform`; no push or deployment is included.

## Develop WebView compatibility validation (2026-10-13)

The backend reports contain 50 passing tests and the final Flutter auth/exam run contains 17 passing tests. Scoped Dart analysis reports no issues. The local bridge tests cover stable profile ownership, teacher-only permissions, isolation from same-email password accounts/admin grants, missing companion proof, foreign origins, remote clients and disabled/non-loopback servers. A real HTTP test starts an isolated Spring Boot server on a random loopback port and exercises bootstrap, WebView workspace creation, exam dashboard access and admin rejection without OAuth credentials. Flutter tests cover the saved develop profile, concurrent requests, session renewal, backend failure/retry, a late response after logout, file upload and the restored Google dialog at 375/414/768/1024/1440 widths. Google account selection inside the native Windows WebView remains a manual acceptance check; these tests do not validate Google's pages or a real Google provider login.

## Independent integration with develop

The exam branch starts from develop and does not depend on the speech translation or UI redesign branches. In Studio, open Tài liệu, then Đề thi & năng lực to use the exam popup. ExamSessionService follows the shared login and keeps exam session ownership separate from Meet OAuth. ExamOAuthClient and the examGoogleOAuthService bean use exam-specific names to coexist with the Meet integration. Existing database migrations are unchanged.
