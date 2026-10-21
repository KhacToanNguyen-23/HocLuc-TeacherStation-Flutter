# Spec ứng viên: Thiết kế hoạt động trong Soạn bài

> Sau điều chỉnh phạm vi của người dùng, dùng [Spec SOẠN BÀI trong app](../lesson-preparation-app/spec.md) và [plan hiện hành](../lesson-preparation-app/plan.md). Các ứng viên dưới đây là tham khảo tiện ích bên trong workspace, không phải các phân hệ phải triển khai riêng.

Date: 2026-10-19
Status: Draft — đề xuất sau nghiên cứu, chưa được chọn để triển khai.
Research: [Báo cáo và 12 ý tưởng](../reports/261019-lesson-preparation-expansion-research.md).
Base: [Soạn bài AI](../lesson-preparation-ai/spec.md).

## Problem Statement

Ngoài tạo học liệu/video, giáo viên cần thiết kế mục tiêu, hoạt động và cách kiểm tra hiểu bài, chuẩn bị ví dụ/gợi ý và cải tiến bài sau khi dùng. Bài soạn cơ bản phải tạo được mà không cần điền mọi trường nâng cao hoặc có dữ liệu học sinh.

## User Stories — thứ tự khuyến nghị, chưa phải cam kết roadmap

- **[P1 / I02] Khối hoạt động:** giáo viên sắp xếp việc GV/HS làm, thời lượng, vật liệu và checkpoint trong cùng bài. Accepted when: bài 45 phút với tổng hoạt động/chuyển tiếp 48 phút báo đúng phần vượt; đổi thứ tự giữ nguyên notes/nguồn/liên kết.
- **[P1 / I01] Mục tiêu–hoạt động–minh chứng:** giáo viên nối mục tiêu với hoạt động và cách kiểm tra. Accepted when: fixture có hai liên kết thiếu chỉ đúng hai chỗ, giáo viên sửa và ghi nhận xác nhận; AI không tự gắn nhãn đạt chuẩn.
- **[P1 / I09] Ví dụ giảm dần hỗ trợ:** giáo viên soạn lời giải theo bước, chọn ẩn bước và thiết kế tự giải. Accepted when: thứ tự bước giữ nguyên, bản học sinh không có phần đáp án bị ẩn, thay lời giải phải qua duyệt.
- **[P1 / I05] Hỗ trợ xử lý hiểu sai:** giáo viên chuẩn bị câu phát hiện, phản ví dụ và gợi ý theo activity. Accepted when: teacher-only card không xuất hiện trong audience/export mặc định; chỉ nội dung được chọn mới chuyển sang học liệu học sinh.
- **[P1 / I08] Cải tiến sau buổi:** giáo viên lưu nhận xét vào đúng lần dùng bài và đưa thành checklist/draft sửa. Accepted when: bài gốc và revision đã dạy không đổi khi mới thêm nhận xét; tạo draft và chấp nhận sửa là thao tác riêng.
- **[P2 / I03,I06,I07,I10,I11,I12] Mở rộng:** nhánh hỗ trợ, reuse khối, chuỗi bài/ôn, case/rubric, form cơ sở và Plan B; xem thẻ ý tưởng trong báo cáo trước khi lập phase.
- **[P2 / I04] Pilot có dữ liệu:** nối analytics đã có với draft bài củng cố. Accepted when: chỉ có tổng điểm không suy ra điểm yếu kỹ năng, draft ghi scope dữ liệu và nguồn; giữ kiểm quyền teacher/class của module gốc.

## Functional Requirements

1. FR-01: Tái sử dụng PlanningService/LocalService, Studio và kho câu hỏi hiện hữu; không tạo hệ lưu bài hoặc bank thứ hai.
2. FR-02: Entity có ID/revision ổn định để ánh xạ objective/activity/checkpoint/source và feedback qua các lần dùng.
3. FR-03: Hoạt động có studentPrompt và teacherGuidance riêng; export/publication allowlist không chứa notes/đáp án riêng.
4. FR-04: Editor local dùng được không AI; viết nháp/gợi ý dùng authoring adapter riêng, không dùng VinAI như chatbot.
5. FR-05: Giáo viên duyệt thay đổi; draft/nhận xét không ghi đè bài gốc hoặc bản đã dạy. Các bản sinh AI có nhãn nháp tới khi duyệt.
6. FR-06: Học sinh tham gia qua lời nói, giấy, Meet/Classroom bình thường; không có app/login/submission mới.
7. FR-07: Tổng phút là phép tính kế hoạch với thời gian chuyển tiếp do giáo viên chọn; không gọi đó là đo thời gian thực hoặc đảm bảo tiết dạy đủ thời lượng.
8. FR-08: Có thể bắt đầu từ tiêu đề và một mục tiêu/một activity; CLO/PLO, rubric và các nhánh là tùy chọn.
9. FR-09: Nếu nối exam, xác thực và ownership theo contract thật; chỉ dùng bằng chứng đúng exam type/taxonomy, không chuyển điểm luyện thành dự đoán thành tích chính thức.
10. FR-10: Tuân thủ feature-first, plugin Microkernel/SDK và lazy disk assets như AGENTS.md; không hardcode môn/plugin trong core. Năng lực ngành học là extension khi phù hợp.
11. FR-11: Mở bài cũ để bổ sung mục tiêu/activity dần dần; không bắt tái phân loại toàn bộ PDF/board mới được lưu/dạy. Một bài qua nhiều buổi hoặc một buổi dùng nhiều bài; LessonUse ghi revision và activity thực dùng.
12. FR-12: Phân biệt kiểm thiếu liên kết bằng rule với đề xuất sư phạm của AI. Pilot ví dụ theo bước trên một dạng bài; giữ typed assets cho công thức, bảng, code, hình/caption/citation qua chỉnh sửa và xuất.

## Non-Functional Requirements

- Giữ bài cũ đọc/lưu/clone được qua migration có version; không coi JSON linh hoạt là đủ bảo đảm compatibility.
- Không gửi nội dung hoặc dữ liệu lớp tới cloud khi giáo viên chưa chọn; model weights/cache ngoài Git.
- Không làm editor chờ STT/LLM/render cho thao tác cấu trúc cơ bản. Long jobs dùng pipeline kế hoạch trước.
- Kiểm khả năng điều hướng bàn phím, nội dung dài, lỗi lưu, mất kết nối và bản học sinh riêng khi thiết kế UI.

## Success Criteria — target cần đo, không phải kết quả

- [ ] Pilot đề xuất 6 người thuộc hai nhóm đối tượng; ít nhất 5/6 hoàn tất thao tác cốt lõi không trợ giúp.
- [ ] Trung vị thời gian soạn giảm mục tiêu 20% so baseline, tính cả sửa/duyệt; công bố sample và số đo thật.
- [ ] Không tăng lỗi nội dung trọng yếu theo rubric do người chấm chuyên môn xác định trước.
- [ ] Sentinel teacher notes/đáp án không có trong student output, PDF/video/caption hoặc Classroom payload của mọi fixture nghiệm thu.
- [ ] Bài cũ và revision đã dạy không thay sau khi thêm reflection hay tạo draft.
- [ ] Không cần tài khoản/app học sinh hoặc thêm dịch vụ video online để hoàn tất editor cơ bản.

Pilot chỉ là feasibility ban đầu trên lát cắt nhỏ, không cả 12 mục. Baseline theo workflow hiện tại, mức hỗ trợ AI tương đương, ghi riêng thời gian học công cụ; báo kết quả từng người/nhóm, không suy rộng median của 6 người thành hiệu quả toàn bộ giáo viên/giảng viên.

## Out of Scope

- Triển khai trong phiên nghiên cứu này; chưa có phase/estimate/commit hay phê duyệt feature list.
- Teacher co-edit realtime, marketplace mới, portal thi/nộp bài, chấm tự động, emotion/attention inference.
- Cam kết nội dung đúng hoàn toàn, tự chứng nhận chuẩn chương trình, tự gán trình độ học sinh hoặc cải thiện điểm số.
- Khẳng định tích hợp nhà cung cấp bên ngoài chỉ vì đã đọc trang giới thiệu sản phẩm.

## Assumptions và quyết định còn mở

- Ưu tiên local-first, teacher-only và English narration như trao đổi trước.
- Thứ tự P1 có thể đổi sau pilot; nếu nhóm giảng viên là đối tượng chính, I10 case/rubric cần được đánh giá sớm hơn.
- Chọn mẫu trường và dữ liệu exam chỉ khi có nguồn phù hợp; không là điều kiện chặn editor chung.
- Chưa chọn checkpoint/model authoring hoặc cloud provider; kiểm chứng riêng theo kế hoạch nền, không suy khả năng sinh bài từ ba speech model.
