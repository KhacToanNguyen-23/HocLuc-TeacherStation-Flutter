# Plan review — 2026-10-20

Status: PASS for planning coherence; DRAFT pending user review. Not implementation acceptance.

Independent reviewer checked current implementation evidence, plan/spec, phase gates and acceptance cases.

- ACCEPTED: PDF notes need document identity, fingerprint/version and page locator, not board page index. Spec and A04/A05 updated, including two PDFs on page 3 and replacement behavior.
- ACCEPTED: Define simultaneous activity/page notes, same PDF in different activities, pin/reset and actual-output vs editor-selection. Spec and A15 updated.
- CORRECTED: EEF 7% statistic refers to lessons in an average week, not percentage of teachers.
- CONFIRMED: Bad state guard masks save failure; exact reported sequence/root cause remains to reproduce. Studio return lacks explicit preparation reconcile; this alone does not prove the cause or data loss.
- CONFIRMED: Java PDF export and existing audience privacy guards are reused; no requirement for an AI provider to complete core preparation.

Repository checks during planning: plugin validator passed (2 plugins), architecture gate passed (12 invariants), Flutter analyzer reported no issues. These checks do not validate the proposed redesign or reproduce/fix the reported bug. All A01-A24 remain NOT RUN.

Updated feature tracker: six redesign P1 stories added as not_started; existing entries/status/evidence retained. No application source changes in this planning task.

## Implementation review — 2026-10-21

After the user's implementation request, source was changed and reviewed. Accepted findings were fixed: shared scoped writes/revisions, derived projection idempotence and teacher-context forwarding, generated activity targets, activity/page cue resolution and pinning, draft identity/load races, recovery queue revision handling, global-cue merge/undo, real reuse picker, and summary vs actual PDF preview. Latest Flutter regression run: 483 passed; backend package run: 239 tests, zero failures/errors/skips. Analyzer and release build evidence is recorded in plan.md after completion.

Six redesign tracker stories are active because end-to-end receiver/Classroom/usability acceptance remains separate. No commit or push was requested. The original planning review above is historical, not a claim that current source remains unchanged.
