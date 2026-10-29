# Meet AI tutor MVP

Confirmed 2026-10-24: teacher-only HocLuc; students use ordinary Meet. Automatic grounded replies are authorized as product behavior. No live messages are authorized during development.

## P1 stories
- Teacher selects an OpenAI-compatible endpoint, API key and model, tests connection and can switch them without changing lesson data. Secrets remain in process memory for this MVP; never preferences, logs or source.
- Tutor reads the opened PDF's text, current page and visible whiteboard text; excludes teacher notes, narration and answer metadata. No continuous audio or image processing.
- New student questions enter one bounded sequential queue. Grounded high-confidence replies retain exact supporting quotations. User confirmed 2026-10-26: low-confidence tentative explanations also auto-send with mandatory uncertainty label, with or without available lesson evidence; no teacher approval. Validate any claimed citations. API/validation/delivery errors remain journal entries, not approvals.
- Teacher can pause immediately; in-flight work cannot send after pause, room/context/config change or disposal. No historical replay on enabling. Ignore self/AI messages, deduplicate, throttle, and require Meet confirmation.
- User follow-up: every new student message while active gets a reply branch, including off-topic canonical rejection, AI failure/invalid response templates, context-changed notice and coalesced overload notice. Preserve pause/room/dispose cancellation; never blindly retry uncertain deliveries. Separate identical messages by ID, not content.

## Acceptance
- Deterministic tests reject fabricated citations, malformed confidence/status combinations, API failures, stale work and unconfirmed sends. Missing context is allowed only for explicit low-confidence inferred answers and must not claim lesson verification.
- Provider request is bounded and times out; credentials are never returned/logged; no implicit provider fallback.
- Existing develop navigation and mounted Meet WebView persist. AI controls are accessible in settings with pause/status and review queue.
- Plugin validator, architecture gate and analyzer run; targeted backend/frontend/bridge tests run. Real provider quality and real Meet send/receive acceptance must be reported separately from fixtures.

## Boundaries
PDF with embedded text supported; scanned pages and raw handwriting lacking existing OCR text are explicitly unavailable. No automatic OCR promise. OpenAI-compatible chat-completions adapter first; distinct provider protocols require future adapters.
