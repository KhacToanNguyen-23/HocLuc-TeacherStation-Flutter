# Board save acknowledgement — 2026-10-21

Reported: saving in Chuẩn bị bảng trình chiếu shows a revision conflict without another editor.

Confirmed cause: PlanningService commits the board and increments boardRevision. PlanningController returned a Gson JsonObject directly to Spring/Jackson. HTTP serialization then failed with HttpMessageNotWritableException (Could not write JSON: JsonObject), so the app did not receive the acknowledged revision. Retrying or saving again with the previous revision correctly produced409, but the initial cause was a broken response after a successful write.

Fix: return explicit application/json UTF-8 text, matching the existing GET contract. Revision checks and scoped persistence remain intact; no unconditional overwrite or revision reset.

Regression: PreparationControllerTest.boardSaveAcknowledgementIsJsonAndSupportsConsecutiveSaves exercises actual MockMvc serialization with real persistence: PUT expected0 ->JSON revision1; GET validates notes/revision; PUT expected1 ->JSON revision2; genuinely stale different content remains409 and does not replace notes.

Red evidence: before fix, test failed expecting200 but received500. Green: regression and scoped-write tests passed. Independent review found no blocker. Full package/runtime smoke results are recorded after deployment.

Lost-ACK recovery: an identical board retry at the immediately previous revision receives the current acknowledgement without rewriting or incrementing revisions. Requested metadata must match persisted metadata; cue updates also require matching committed cues and preparation revision. Different stale content remains409. This is deliberately conservative: legacy snapshots needing generated page IDs may still conflict.

Verification: full Maven package passed, 240 tests with zero failures/errors. Plugin validator passed (2 plugins); Flutter architecture12 passed and analyzer reported no issues. Independent review found no blockers after metadata and cue retry coverage.

Deployed backend and exercised the real HTTP endpoint:20 consecutive saves plus20 identical retries passed; immediate divergent stale save returned409; final persisted revision/content verified. Temporary QA plans were deleted. Frontend process4112 was preserved throughout, with no restart or user content changes.

The already-open app can retry saving against the corrected backend. If its content differs from the committed snapshot, retain unsaved edits and investigate the genuine conflict rather than bypassing revision checks.
