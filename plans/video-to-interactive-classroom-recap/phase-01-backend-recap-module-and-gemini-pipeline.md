# Phase 1: Backend Recap Module & 4-Agent Gemini Pipeline

**Status:** Not Started  
**Spec Coverage:** P1 (Story 3), FR-03, FR-04  
**Package:** `backend/api/src/main/java/vn/teaching/modules/recap/`

---

## 🎯 Goal
Xây dựng module `modules/recap` trong Spring Boot Modular Monolith để tiếp nhận yêu cầu phân tích video buổi chữa đề ĐGNL từ Teacher Station, quản lý Master Gemini API Key (cấu hình 1 lần ở server), kết nối Google Drive API để lấy luồng video và điều phối 3 Agent phân tích đa phương thức bóc tách: Mốc thời gian theo mã câu hỏi (`Câu 01: ...`, `Câu 12: Bấm Casio ...`), Sổ tay công thức & mẹo bấm máy tính, và Bộ câu hỏi trắc nghiệm phản xạ tương tự.

---

## 🛠️ Tasks

1. **DTOs & Models (`vn.teaching.modules.recap.dto`):**
   - `RecapJobRequest`: `{ String courseId, String driveFileId, String lessonTitle, String subject }`
   - `RecapJobResponse`: `{ String jobId, String status, Instant createdAt }`
   - `RecapAnalysisResult`:
     - `List<RecapChapter>`: `{ String timestamp, String questionCode, String topic }` (ví dụ: `"09:20"`, `"Câu 12"`, `"Bấm Casio FX-580 giải hệ"`)
     - `List<RecapKeynote>`: `{ String heading, String contentLatex, String casioTip }`
     - `List<RecapQuiz>`: `{ String question, List<String> options, int answerIndex, String explanation }`
   - `RecapJobStatus`: `PENDING`, `ANALYZING`, `READY_FOR_REVIEW`, `APPROVED`, `PUBLISHED`, `FAILED`.

2. **Master API Key & Gemini Client (`vn.teaching.modules.recap.service.GeminiVideoAnalyzer`):**
   - Cấu hình Master API Key trong `application.properties`:
     `gemini.api-key=${GEMINI_API_KEY:AIzaSy_DEV_MASTER_KEY}`
   - Cơ chế lấy video: Dùng `driveFileId` đọc stream từ Google Drive API $\rightarrow$ gửi sang Gemini File API (`POST /upload/v1beta/files`).
   - Tích hợp 3 Agent Prompts chuyên sâu cho đề thi Đánh Giá Năng Lực (HSA / V-SAT / TSA):
     - *Agent 1 (Milestone & Chaptering):* Phát hiện chuyển câu, gán nhãn câu hỏi ĐGNL.
     - *Agent 2 (Pedagogical Synthesis):* Lọc bỏ tạp âm, trích xuất công thức LaTeX & mẹo bấm phím Casio.
     - *Agent 3 (Socratic Quiz Generator):* Sinh 3–5 câu trắc nghiệm cùng bản chất tư duy nhưng đổi số liệu để rèn phản xạ.
   - Ép kiểu JSON Schema bằng Gemini `responseSchema`.

3. **Recap Job Service & Thread-safe Queue (`vn.teaching.modules.recap.service.RecapJobService`):**
   - Quản lý hàng đợi tác vụ bất đồng bộ `@Async("recapExecutor")`.
   - Tích hợp với `GoogleConnectionService` để lấy OAuth token của giáo viên đọc file từ Google Drive API (`drive.files.get(alt=media)`).
   - Lưu trữ trạng thái Job vào File-backed repository hoặc in-memory concurrent map.

4. **REST Controller (`vn.teaching.modules.recap.controller.RecapController`):**
   - `POST /api/recap/jobs`: Nhận yêu cầu tạo bài ôn tập ĐGNL, trả về `202 Accepted` kèm `jobId`.
   - `GET /api/recap/jobs/{jobId}`: Polling kiểm tra tiến độ phân tích (`status`, `result`).
   - `PUT /api/recap/jobs/{jobId}/review`: Cập nhật bản nháp sau khi giáo viên chỉnh sửa mốc câu hỏi / quiz.

---

## 🧪 Verification
- Unit test `RecapControllerTest`: Kiểm tra validation đầu vào, mã phản hồi 202, polling status.
- Unit test `GeminiVideoAnalyzerTest`: Mock HTTP client kiểm tra parse JSON schema chính xác với Master API Key.
- Đảm bảo tuân thủ giới hạn dòng file Backend $\le 600$ LOC.
