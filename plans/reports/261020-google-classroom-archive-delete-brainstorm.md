# Brainstorm: Google Classroom archive and delete flow

**Date:** 2026-10-20

## Ideas Explored

- Direct permanent deletion from the active list: already exists, but Google requires archiving first and the operation can be rejected.
- One-click archive then permanent delete: automates the Google prerequisite, but combines a reversible lifecycle step with irreversible deletion and does not give teachers an archived management area.
- Archive into a separate area, then allow restore or permanent deletion there: follows Classroom's visible lifecycle and was selected by the user.
- Local-only archival for HocLuc records without a Classroom course ID: needed as a separate implementation decision because Google cannot archive a course that has not been created remotely.

## User's Direction

The user wants a dedicated area containing archived classes. Permanent deletion should be available only there, following Google Classroom's teacher-controlled workflow. The app should perform these actions against Google Classroom directly.

## Decisions and Remaining Notes

- A HocLuc course without a Google Classroom `courseId` remains eligible for local-only deletion from the active list. The confirmation must make clear that it only removes the HocLuc record.
- Google Classroom's documented permission model allows teachers and co-teachers to archive, while only the primary teacher can delete. The app should rely on Google's response; the screen is currently in a teacher workspace.

## Risks

- The app currently calls Google deletion directly and then removes its local course record; lifecycle actions must preserve local data when Google rejects a request.
- A course may be archived or restored outside HocLuc, so the app needs state reconciliation before displaying or acting on lifecycle actions.
- Permanent deletion cannot be undone and removes access to posts and comments. Google says class Drive files remain available, so the confirmation copy must accurately describe the effect.

