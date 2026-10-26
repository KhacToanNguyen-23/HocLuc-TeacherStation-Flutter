# Phase 2: Backend Artifact Generators & Google Publisher

**Status:** Not Started  
**Spec Coverage:** P1 (Story 5), FR-05, FR-06, FR-08  
**Package:** `backend/api/src/main/java/vn/teaching/modules/recap/service/`

---

## 🎯 Goal
Hiện thực hóa các dịch vụ tạo học liệu phụ trợ (PDF tóm tắt công thức, Google Form trắc nghiệm tự chấm) và xuất bản toàn bộ gói ôn tập lên Google Classroom của lớp học thông qua Google Workspace APIs.

---

## 🛠️ Tasks

1. **PDF Summary Generator (`PdfSummaryGenerator`):**
   - Tạo tài liệu PDF tóm tắt bài học chuẩn sư phạm ĐGNL:
     - Header: Tiêu đề buổi học, môn học, ngày học.
     - Section 1: Mục lục mốc thời gian chữa bài.
     - Section 2: Khung công thức then chốt (LaTeX formulas) & mẹo bấm máy tính Casio.
     - Section 3: Các lưu ý "bẫy nhận thức" học sinh hay sai.
   - Xuất ra `byte[]` và sử dụng `GoogleGateway` upload lên thư mục lớp học trên Google Drive (`teacherFolderId`).

2. **Google Forms Generator (`GoogleFormsGenerator`):**
   - Gọi Google Forms API v1:
     - `POST https://forms.googleapis.com/v1/forms` tạo form mới: `[Kiểm tra nhanh] [Tên buổi học]`.
     - `POST https://forms.googleapis.com/v1/forms/{formId}:batchUpdate`:
       - Cài đặt `updateSettings` với `quizSettings.isQuiz: true`.
       - Thêm các câu hỏi trắc nghiệm (`createItem` với `choiceQuestion` Type RADIO).
       - Cài đặt đáp án đúng (`correctAnswers`) và điểm số (`pointValue: 1`).
       - Thêm giải thích chi tiết (`generalFeedback`).
   - Lấy URL form làm bài (`responderUri`) để đính kèm.

3. **Classroom Publisher (`ClassroomPublisher`):**
   - Gọi Google Classroom API v1 (`courses.courseWork.create` hoặc `courses.announcements.create`):
     - `title`: `[Ôn tập ĐGNL] [Tên buổi học]`
     - `description`: Danh sách các mốc thời gian `MM:SS - Câu XX` rõ ràng, có thể click/đọc.
     - `materials`:
       1. `{ driveFile: { id: driveFileId, title: "Video buổi học" } }`
       2. `{ driveFile: { id: pdfDriveFileId, title: "Sổ tay mẹo giải nhanh ĐGNL (PDF)" } }`
       3. `{ link: { url: formResponderUri, title: "Bài tập rèn luyện phản xạ (Google Form)" } }`
   - Cập nhật trạng thái job thành `PUBLISHED`.

---

## 🧪 Verification
- Unit test `PdfSummaryGeneratorTest`: Kiểm tra sinh PDF hợp lệ, không lỗi font tiếng Việt.
- Unit test `GoogleFormsGeneratorTest`: Mock Google Forms API payload và cấu trúc batchUpdate.
- Unit test `ClassroomPublisherTest`: Mock Google Classroom API, kiểm tra 3 materials đính kèm chính xác.
- Đảm bảo tuân thủ kiến trúc Modular Monolith và giới hạn $\le 600$ LOC.

