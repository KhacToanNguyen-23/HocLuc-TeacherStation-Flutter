# Spec: Video-to-Interactive-Classroom-Recap (Trợ Giảng AI Bóc Tách Video Buổi Chữa Đề ĐGNL Thành Bộ Ôn Tập Google Classroom)

**Date:** 2026-10-20  
**Status:** Ready  
**Slug:** `video-to-interactive-classroom-recap`

---

## Problem Statement
Trong các buổi luyện thi Đánh Giá Năng Lực (HSA / V-SAT / TSA), giáo viên chữa liên tục 20–40 câu trắc nghiệm đa lĩnh vực (Toán logic, Đọc hiểu, Khoa học tự nhiên) với tốc độ cao. Video 90–120 phút quá dài khiến học sinh khó tìm lại câu mình làm sai, trong khi giáo viên không có đủ thời gian soạn lại tóm tắt mẹo giải và bài tập rèn luyện. Tính năng này cung cấp một công cụ công nghệ thuần túy (không quản trị): Nền tảng tự quay màn hình Studio Board + Plugin Casio + Mic siêu nhẹ, 1-click tải lên Drive của lớp, Backend dùng Master Gemini API Key bóc tách video thành mục lục theo từng mã câu hỏi ĐGNL, tự tạo Sổ tay PDF mẹo giải và Google Form trắc nghiệm tự chấm, cho phép giáo viên kiểm duyệt nhanh trước khi xuất bản trực tiếp lên Google Classroom của học sinh.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a Teacher, I want Teacher Station to automatically record my Studio Board canvas (including interactive Casio FX-580 plugin) and mic audio during a teaching session into a lightweight MP4 file (≤ 120MB per 60 mins), so that I don't need a paid Google Meet subscription to produce high-resolution lesson videos.
  *Accepted when:* Starting a lesson begins capturing canvas + mic at 12–15 FPS H.264/AAC, and ending the lesson saves a valid MP4 file in local application storage.

- **[P1]** As a Teacher, I want to 1-click upload the session video to the course folder on my Google Drive using my existing OAuth credentials, so that I don't have to manually browse folders or resolve Drive file permission errors.
  *Accepted when:* Clicking "Upload to Drive & Analyze" calls Google Drive API via Resumable Upload, assigns reader permission to course students, and retrieves `fileId` immediately.

- **[P1]** As a Teacher, I want Backend AI (Gemini Multimodal via Master Developer API Key) to analyze the video and extract question-level timestamps (e.g. `Câu 12: Bấm Casio`), formula cheatsheets, and 3–5 parallel drill questions within 60 seconds, so that I have a structured ĐGNL review package ready.
  *Accepted when:* Backend streams the Drive video to Gemini File API and returns structured JSON containing question chapters (`MM:SS`), LaTeX shortcuts/formulas, and multiple-choice questions with answer keys.

- **[P1]** As a Teacher, I want to review, edit, or regenerate quiz questions and timestamps in an interactive Review Gate dialog on Teacher Station before publishing, so that I maintain 100% pedagogical authority and prevent AI hallucinations.
  *Accepted when:* Review dialog allows editing timestamp text, modifying quiz question/options/answer, deleting unwanted items, and approving the package.

- **[P1]** As a Teacher, I want the approved package to be published directly to Google Classroom with the Drive video link, generated PDF cheatsheet, and self-grading Google Form Quiz, so that students can access everything natively without installing any new apps.
  *Accepted when:* Google Classroom API creates a new Material/Coursework containing formatted question timestamp description, the Drive video attachment, a generated PDF attachment, and a Google Form Quiz attachment.

- **[P2]** As a Teacher, I want an optional setting to provide my own Gemini API Key (BYOK) if I want to bypass system monthly quotas, so that I have unlimited usage flexibility.
  *Accepted when:* An optional input field in settings stores personal Gemini API Key and routes requests through it if present.

- **[P2]** As a Student, I want the Google Classroom post description to list question-level timestamps (e.g. `09:20 - Câu 12: Bấm máy tính Casio FX-580`) so that I can click and immediately seek to the exact question I got wrong.
  *Accepted when:* Post description includes formatted `MM:SS - Câu XX: [Nội dung]` lines that correlate to key question milestones in the video.

- **[P3]** _(out of scope — noted for future)_ Automatic video clipping of individual questions into short vertical clips for TikTok/YouTube Shorts.

---

## Functional Requirements

1. **FR-01 (Local Canvas, Casio & Mic Recorder):** 
   Teacher Station must provide a background screen recorder capturing the Studio Board canvas (including any active floating plugins such as Casio FX-580VN X) and active microphone audio at 12–15 FPS, H.264 video codec, AAC mono 64 kbps audio. Total file size for a 60-minute session must not exceed 120MB.

2. **FR-02 (OAuth Resumable Drive Upload):** 
   Teacher Station must implement Google Drive API v3 Resumable Upload using chunks of 5MB–10MB, targeting the class's `teacherFolderId` (Google Classroom course folder) and applying `role: reader` for students.

3. **FR-03 (Backend Recap Job Ingestion & Master API Key):** 
   Backend Spring Boot must expose `POST /api/recap/jobs` accepting `courseId`, `driveFileId`, `title`, `subject`. The backend utilizes a centralized master `gemini.api-key` configured in `application.properties` (with optional per-request override), returning `202 Accepted` with a unique `jobId`.

4. **FR-04 (4-Agent Multimodal Analysis Engine):** 
   Backend worker must stream the video from Google Drive to Gemini File API and orchestrate 4 functional agent steps inspired by OpenMAIC:
   - *Agent 1 (Milestone & Chaptering):* Detects question transitions (`Câu XX`) and timestamps (`MM:SS`).
   - *Agent 2 (Pedagogical Synthesis):* Extracts LaTeX formulas, Casio shortcuts, and exam pitfalls into structured markdown.
   - *Agent 3 (Socratic Quiz Generator):* Synthesizes 3–5 parallel multiple-choice drill questions with 4 options, answer index, and explanation.
   - *Agent 4 (Google Workspace Packager):* Formats artifacts for Drive, Forms, and Classroom APIs.

5. **FR-05 (PDF Cheatsheet Generator):** 
   Backend must compile the extracted formulas, shortcuts, and pitfalls into a clean PDF document (`So_Tay_Meo_Giai_[LessonTitle].pdf`) and upload it to the course's Drive folder.

6. **FR-06 (Google Forms Auto-Generator):** 
   Backend must invoke Google Forms API v1 (`forms.create` and `batchUpdate`) to generate an auto-graded quiz with questions, options, answer keys, and point values.

7. **FR-07 (Interactive Review Gate in Flutter):** 
   Frontend Teacher Station must provide a modal review view displaying:
   - Question timestamps editor (editable text, seek test, delete)
   - PDF preview card
   - Quiz cards with radio buttons showing correct answers, edit text, and delete/regenerate button
   - Action buttons: "Publish to Classroom" and "Save as Draft on Classroom".

8. **FR-08 (Classroom Native Publishing):** 
   Backend must invoke Google Classroom API (`courses.courseWork.create` or `courses.announcements.create`) to post the review bundle with:
   - Formatted title and question-level timestamp description
   - Material link to Google Drive video
   - Material link to Google Drive PDF
   - Material link to Google Form Quiz

---

## Non-Functional Requirements

- **Performance:** 
  - Local recording CPU usage must stay below 6% on an Intel Core i5 8th Gen or equivalent.
  - Video upload of 80MB on a 20 Mbps upload connection must complete within 45 seconds.
  - Gemini AI analysis and JSON extraction must complete within 60 seconds for videos ≤ 60 minutes.
- **Reliability:** 
  - Drive upload must automatically resume from the last successful chunk if network drops temporarily.
  - Recording must write to disk continuously so a crash preserves the video recorded up to that point.
- **Security & Privacy:** 
  - Video and student data must strictly remain within the teacher's own Google Drive and Google Classroom course boundaries. No public URLs.
- **Architecture Invariants:** 
  - Frontend code must strictly follow Feature-First Clean Architecture (`lib/features/recap/` or `lib/features/classroom_meet/`).
  - No file in `lib/` exceeding 900 LOC.
  - Backend code must reside strictly in `vn.teaching.modules.recap` (Modular Monolith pattern).

---

## Success Criteria

- [ ] **Recording Size & Quality:** A 60-minute recorded board session produces an MP4 file ≤ 120MB with clear 1080p canvas resolution, visible Casio screen, and audible speech.
- [ ] **1-Click Upload:** Video uploads to the course Google Drive folder with correct viewer permissions in a single teacher confirmation.
- [ ] **AI Extraction Accuracy:** AI successfully extracts ≥ 5 question timestamps matching actual questions solved in the video and ≥ 3 relevant multiple-choice drill questions.
- [ ] **Zero-Install Student Delivery:** A published post appears on Google Classroom containing the Drive video, the summary PDF, and the self-grading Google Form, viewable on standard Google Classroom mobile and web apps.
- [ ] **Architecture Gate:** 12/12 architecture invariants pass (`architecture_test.dart`) and 0 analyzer errors.

---

## Out of Scope

- School ERP, student attendance tracking, or administrative report generation.
- Hosting a standalone web player or student authentication portal.
- Uploading to YouTube or managing public YouTube channels.
- Real-time facial recognition or student emotion tracking via webcams.

---

## Assumptions

- Teacher has granted Google Drive and Google Classroom OAuth scopes (`https://www.googleapis.com/auth/drive.file`, `https://www.googleapis.com/auth/classroom.coursework.students`, `https://www.googleapis.com/auth/forms.body`).
- Developer has configured a master `gemini.api-key` in backend `application.properties`.
- Teacher has available storage quota on their Google Drive account (minimum 200MB free per session).
