# Meet AI tutor: live API test, 2026-10-26

## Boundary

- Real running Java backend and real Gemini API, credentials taken from ignored delivery `.env`.
- Native Windows app built and opened as HocLucStation; window/process presence verified.
- Lesson sources are synthetic API fixtures. No native whiteboard drawing or actual teacher/student Meet chat was performed.
- Computer Use initialization failed repeatedly with `failed to write kernel assets: The system cannot find the path specified. (os error 3)`, including after a kernel reset. Live UI E2E is pending tool recovery.

## Configuration and fixes

- The initially suggested `gemini-2.5-flash-lite` returned HTTP 404: unavailable to newly provisioned users. Delivery `.env` now selects `gemini-3.5-flash-lite`.
- A direct real-key minimal-reasoning probe returned OK in 16.8 seconds, exceeding the previous 12-second backend deadline.
- Backend deadline now defaults to 45 seconds, configurable from 5 to 90 seconds in `.env`; optional reasoning effort and strict JSON schema are backend-only. No API controls were added to UI.
- Outside-scope response is exactly `Không nằm trong nội dung bài học`.
- Preserve strict citation validation. Structured output and prompt clarification fix quote/text field confusion and distinguish calculations from verbatim evidence.
- Pause/dispose abort tutor transport without closing the shared companion HTTP client. Re-enabling can process a fresh question without waiting for an unresolved obsolete future. Aborting local transport does not establish that an upstream provider has stopped already-dispatched work.

## First-pass live results

Initial unstructured round: 4/6. After the fixes: 6/9 on the first structured round. These are small smoke-test samples, not a general accuracy benchmark.

| Case | First pass | Result | Seconds |
|---|---|---|---|
| in-scope-random | PASS | Tam giác có các cạnh 3 cm, 4 cm và 5 cm có chu vi 12 cm. | 29.8 |
| in-scope-area | PASS | Hình chữ nhật dài 8 cm, rộng 5 cm có diện tích 40 cm². | 33.4 |
| in-scope-inference | PASS | Áp dụng công thức tính chu vi tam giác với các cạnh 5 cm, 6 cm và 7 cm, ta có tổng độ dài ba cạnh là 5 + 6 + 7 = 18 cm. Vậy chu vi tam giác là 18 cm. | 39.4 |
| out-of-scope-dinner | FAIL | provider_unavailable | 8.1 |
| out-of-scope-story | PASS | Không nằm trong nội dung bài học | 17.7 |
| untrusted-instruction | FAIL | provider_unavailable | 45.0 |
| heldout-perimeter | PASS | Chu vi tam giác là 25 cm (tính bằng tổng độ dài ba cạnh: 9 cm + 10 cm + 6 cm = 25 cm). | 19.9 |
| heldout-area | PASS | Để tính diện tích hình chữ nhật, ta nhân chiều dài với chiều rộng (16 * 9). Dựa vào công thức diện tích hình chữ nhật bằng chiều dài nhân chiều rộng, với chiều dài 16 cm và rộng 9 cm, diện tích là 144 cm². | 34.8 |
| heldout-definition | FAIL | provider_unavailable | 41.4 |

Fresh held-out measurements were generated after the prompt was finalized; their values were not placed in the prompt. Perimeter 9 + 10 + 6 = 25 and rectangle 16 x 9 = 144 were answered correctly with low confidence.

## Separate retries

First-pass failures remain failures in the table above. One separate retry of failed cases:

| Case | Retry | Result | Seconds |
|---|---|---|---|
| out-of-scope-dinner | FAIL | provider_unavailable | 2.7 |
| untrusted-instruction | PASS | Không nằm trong nội dung bài học | 21.1 |
| heldout-definition | PASS | Một tam giác có ba cạnh. | 22.7 |

A separate direct-provider diagnostic for the definition returned HTTP 200, finish=stop, and the exact valid quotation. A direct-provider diagnostic for the dinner question also returned valid out_of_scope JSON. Provider unavailability/timeouts during the backend batch remain an unresolved reliability limit; successful direct diagnostics do not erase those failures.

## Automated regression checks

A further backend retry of the dinner case still returned `provider_unavailable` after 45.1 seconds. Separate Java HTTP/1.1 and HTTP/2 direct-provider probes both returned HTTP 200 with `out_of_scope` and finish=stop (23 and 20 seconds). These diagnostics do not establish HTTP version as the cause, so no protocol override was added. End-to-end provider reliability remains unresolved.

- Flutter tutor/controller/gateway/header/context/settings, Meet delivery/inspector and architecture tests: 77 passed.
- Backend TutorControllerTest + GoogleDesktopEnvironmentTest: 35 passed, including the configured 5-second provider-body deadline and fabricated-evidence rejection.
- Meet DOM bridge Node suite: 14 passed.
- Flutter analyzer: no issues. Plugin validator: 3 packages synchronized.
- Windows debug build passed; backend /api/bootstrap HTTP 200.

## Remaining manual acceptance

- Draw/create lesson content in the actual native whiteboard.
- Join a real Meet as teacher plus a distinct student/guest and verify observed student messages and actual chat echoes.
- Verify scope, low confidence, pause/re-enable, history/self-message filtering and provider failure feedback on real Meet.
- Do not claim live Meet delivery, whiteboard extraction or complete E2E acceptance from the API or DOM fixtures alone.
