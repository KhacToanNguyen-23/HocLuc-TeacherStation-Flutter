# Phase 03 — Giáo án và storyboard có bước duyệt

Trạng thái: đề xuất. Story: P1 từ video/script/prompt; P2 song ngữ. Phụ thuộc: 01–02; đường script dùng 01 trực tiếp.

## Công việc

- Tạo `LessonAuthoring` interface riêng với adapter LLM có cấu hình; không dùng model dịch như LLM. Ưu tiên adapter local, benchmark bộ đề giữ lại và giới hạn phần cứng. Cloud mặc định tắt; chỉ gửi nội dung khi giáo viên opt-in rõ ràng với nhà cung cấp và phạm vi dữ liệu. Không bắt cloud là điều kiện của MVP.
- Giáo viên nhập môn/chủ đề tự do, lớp, mục tiêu, thời lượng, script hoặc prompt trong app. Từ transcript, đề xuất mục tiêu, dàn ý, diễn giải, hoạt động và storyboard; câu trích từ nguồn có mốc thời gian, nội dung AI bổ sung được nhận diện rõ.
- Storyboard JSON schema: sceneId, duration, templateId, text/assets, narration, captions, sourceRefs. Chỉ template và tham số trong allowlist; validate trước lưu và render.
- Duyệt/chỉnh theo cảnh; khóa đoạn đã sửa, sinh lại lựa chọn và lưu revision. Kiểm concurrency để job cũ không ghi đè revision mới.
- Dịch Việt→Anh theo năng lực hiện có, preview song song và glossary; không hứa chiều/ngôn ngữ khác nếu chưa có adapter. Giữ ghi chú riêng ngoài nội dung dịch/xuất dành học sinh.

## Nghiệm thu

- Cùng một bài từ video và từ prompt đều tạo draft có mục tiêu, trình tự cảnh và narration chỉnh được; không tự publish.
- JSON lỗi/thiếu template, prompt injection trong transcript và asset ngoài allowlist bị từ chối/đưa về sửa, không thực thi mã.
- Giáo viên sửa/khóa một cảnh, regen cảnh khác không thay đổi nội dung đã khóa; kết quả stale được báo thay vì ghi đè.
- Bộ giữ lại có rubric độ đúng nội dung, bám nguồn, phù hợp tuổi, đủ mục tiêu và thời lượng; giáo viên chấm, báo tỷ lệ đạt theo tiêu chí trước chọn adapter.
- Bài dịch kiểm thuật ngữ, con số, tên riêng và ngữ nghĩa độc lập với STT; không dùng loss để tuyên bố chất lượng bài dạy.

## Đầu ra

Revision giáo án/storyboard được giáo viên duyệt, đủ đầu vào renderer; adapter/model và cấu hình được ghi lại để truy vết. UI có trạng thái chưa cấu hình và lỗi có thể phục hồi ngay trong app.
