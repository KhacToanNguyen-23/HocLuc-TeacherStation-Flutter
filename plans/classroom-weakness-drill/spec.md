# Spec: Đề ôn tập theo điểm yếu của lớp qua Google Classroom/Forms

**Date:** 2026-10-20
**Status:** Draft

---

## Problem Statement
Giáo viên ôn thi ĐGNL không có thời gian xem lớp yếu dạng nào rồi soạn đề luyện đúng dạng đó. Teacher Station cần tự phát hiện dạng sai nhiều, soạn đề, và giao qua Google Classroom để học sinh không phải dùng nền tảng mới.

---

## User Stories

- **[P1]** As a giáo viên, I want đồng bộ kết quả Google Forms của lớp về Teacher Station so that không phải nhập tay.
  Accepted when: bấm đồng bộ lấy được phản hồi của ≥95% học sinh đã nộp và khớp được với học sinh trong lớp.

- **[P1]** As a giáo viên, I want xem bản đồ điểm yếu của lớp theo dạng bài so that biết nên ôn gì.
  Accepted when: hiển thị tỉ lệ sai theo dạng bài và đánh dấu dạng vượt ngưỡng cấu hình.

- **[P1]** As a giáo viên, I want agent đề xuất và soạn đề phụ đạo theo các dạng sai nhiều so that tiết kiệm thời gian ra đề.
  Accepted when: agent trả về đề có số câu cấu hình, mỗi câu gắn dạng bài, đáp án, lời giải, và trạng thái đã tự giải khớp đáp án.

- **[P1]** As a giáo viên, I want xem trước và duyệt cả đề trước khi giao so that không giao đề sai.
  Accepted when: không thể giao nếu giáo viên chưa duyệt. Câu được duyệt mới vào ngân hàng, câu bị loại không lưu.

- **[P1]** As a giáo viên, I want giao đề đã duyệt cho cả lớp trên Classroom dưới dạng Google Forms quiz so that học sinh làm bài trên công cụ quen thuộc.
  Accepted when: bài xuất hiện trong Classroom với hạn nộp, đính kèm Form có tự chấm theo đáp án.

- **[P2]** As a giáo viên, I want xem tiến bộ sau khi giao so that biết dạng nào đã cải thiện.
  Accepted when: so sánh tỉ lệ sai theo dạng bài giữa hai lần giao.

- **[P3]** _(out of scope — noted for future)_ Giao phân hóa theo nhóm học sinh, gia sư Socratic, thảo luận đa agent kiểu OpenMAIC.

---

## Functional Requirements

1. FR-01: Thêm kết nối OAuth cho Forms và Classroom coursework, giáo viên cấp quyền một lần.
2. FR-02: Đồng bộ phản hồi Form về kết quả của một lớp, khớp học sinh qua email hoặc mã học sinh thu trong Form.
3. FR-03: Phân tích tỉ lệ sai theo dạng bài (trường dạng bài cần chốt, xem Open Questions) và ngưỡng cấu hình được.
4. FR-04: Agent sinh câu biến thể cùng dạng, tự giải lại để kiểm tra, loại câu không khớp hoặc thiếu dữ kiện.
5. FR-05: Màn hình xem trước đề do agent soạn dùng lại editor đề hiện có, có trạng thái chờ duyệt.
6. FR-06: Giao bài: tạo Google Form quiz có đáp án và điểm, tạo coursework trên Classroom cho cả lớp với hạn nộp.
7. FR-07: Câu agent sinh chỉ vào ngân hàng sau khi giáo viên duyệt, tuân thủ quy tắc câu đã duyệt là bất biến.

Màn hình đề xuất: (1) Kết nối và đồng bộ, (2) Bản đồ điểm yếu, (3) Đề xuất của agent, (4) Xem trước và duyệt đề, (5) Giao bài, (6) Theo dõi sau giao (P2).

---

## Non-Functional Requirements

- Performance: đồng bộ 40 học sinh dưới 30 giây. Sinh đề 15 câu dưới 3 phút.
- Security: token OAuth lưu an toàn phía thiết bị hoặc backend, không ghi log. Key LLM không nằm trong source.
- Availability: nếu API Google lỗi, giữ đề đã duyệt và cho giao lại, không mất dữ liệu.

---

## Success Criteria

- [ ] Tỉ lệ câu agent sinh được giáo viên duyệt không sửa: ≥70% trong thử nghiệm 5 đề.
- [ ] Tỉ lệ câu có đáp án sai lọt qua bước agent tự giải: 0 trong mẫu duyệt tay 50 câu.
- [ ] Thời gian từ bấm đồng bộ đến giao bài: dưới 10 phút khi giáo viên chỉ xem trước.
- [ ] Khớp học sinh khi đồng bộ: ≥95%.

---

## Out of Scope

- Giao phân hóa theo nhóm học sinh.
- Giao diện hoặc ứng dụng riêng cho học sinh.
- Gia sư Socratic và phòng thảo luận đa agent.

---

## Assumptions

- Giáo viên có tài khoản Google đã kết nối Classroom. Nếu sai, cần luồng đăng nhập khác.
- Học sinh có email Google làm bài Form. Nếu sai, cần thu mã học sinh trong Form.
- Dữ liệu câu hỏi hiện có đủ metadata dạng bài để phân tích. Nếu sai, cần gán lại nhãn.

---

## Decisions (resolved)

- Agent chạy ở `backend/api`: backend gọi LLM và Google API, key LLM do backend giữ. Desktop chỉ là UI. Hiện backend chưa có code gọi LLM nên cần thêm.
- "Dạng bài" = topic + skill hiện có trong ngân hàng (đã có trong `AnalyticsService`, `ExamModels`). Câu agent sinh kế thừa nhãn từ câu gốc.
- Khớp học sinh: Form bắt buộc thu email Google, khớp với email trong roster Classroom. Giáo viên gán `student_code` một lần.
