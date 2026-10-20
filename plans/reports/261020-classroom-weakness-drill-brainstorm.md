# Brainstorm: Agent trợ giảng ôn thi ĐGNL qua Google Classroom (tự tạo đề theo dạng lớp sai nhiều)

**Date:** 2026-10-20

## Ideas Explored
- Phòng thảo luận đa agent kiểu OpenMAIC (AI Teacher + AI Classmates): hay về sư phạm nhưng cần giao diện học sinh riêng, bị loại vì không build nền tảng mới.
- Agent nằm trong Google Classroom: không khả thi, Classroom chỉ là SaaS có API.
- Agent trong Teacher Station, Classroom/Forms là kênh giao nhận: **chọn**.
- Gia sư Socratic 24/7 cho học sinh: cần kênh riêng, để sau.
- Giao phân hóa theo nhóm học sinh: để giai đoạn sau.
- Sinh biến thể thay vì chỉ chọn câu từ ngân hàng: hướng được chọn.

## User's Direction
- "Làm nhiều quen tay": lớp sai nhiều dạng nào thì tự tạo đề dạng đó.
- Không build nền tảng mới. Học sinh chỉ dùng dịch vụ Google.
- Agent nằm ở Teacher Station (desktop), giáo viên duyệt trước khi giao.
- Dữ liệu bài làm: Google Forms (quiz), đồng bộ phản hồi qua Forms API.
- Nguồn câu hỏi: agent sinh biến thể hoàn toàn mới. Câu sinh ra là candidate, agent tự giải lại để kiểm tra, giáo viên duyệt cả đề trên màn xem trước, câu được duyệt mới vào ngân hàng.
- MVP: đồng bộ kết quả, bản đồ điểm yếu, đề xuất của agent, duyệt, giao cả lớp. Giao theo nhóm để sau.

## Hiện trạng repo
- Có sẵn: `classroom_meet/` (Classroom, Meet, roster), `exams/` (ngân hàng, ma trận, sinh đề, editor, lớp, kết quả, analytics), `plugin_engine/`.
- Thiếu: Forms API và `courseWork.create`, scope OAuth tương ứng, đồng bộ phản hồi tự động, analytics theo dạng bài cho việc ra đề, chế độ đề phụ đạo, màn hình duyệt đề do agent soạn, ánh xạ `student_code` sang email Classroom.

## Open Questions
- Ánh xạ học sinh (`student_code`) sang email Classroom: nhập thủ công, import CSV hay lấy từ roster?
- Agent chạy ở đâu: plugin sidecar (đúng invariant plugin) hay service backend `backend/api`? Key LLM lưu ở đâu?
- Phân loại "dạng bài" dựa trên trường nào (topic, skill, hay taxonomy mới)? Cần kiểm tra metadata của câu hỏi hiện có.
- Ngưỡng "sai nhiều" (ví dụ >40% lớp) có cấu hình được không?
- Cách xử lý ràng buộc hiện tại "không dùng nội dung sinh tự động" và "câu đã duyệt bất biến" khi thêm câu agent sinh.

## Risks
1. Câu ĐGNL do LLM sinh có thể sai đáp án hoặc nhiều đáp án đúng. Cần bước agent tự giải lại và giáo viên duyệt bắt buộc.
2. OAuth scope Forms/Classroom mới cần Google verification và giáo viên cấp lại quyền. Quota API và xác minh ứng dụng có thể chậm.
3. Học sinh nộp Forms không có `student_code`. Nếu không thu email hoặc mã trong Form thì không khớp được kết quả.
