# Brainstorm: thiết kế lại Soạn bài — DRAFT

Ngày 2026-10-20. Chỉ nghiên cứu/lập kế hoạch, không sửa source.

## Vấn đề và nhu cầu đã được người dùng xác nhận

UI hiện mô tả công cụ xử lý thay vì công việc giáo viên. Form dài thiếu ý nghĩa; bảng chưa có vòng đời đáng tin; nguồn và tác vụ khó hiểu. Người dùng cần đủ thông tin để giảng, lời nhắc đúng phần/trang chỉ giáo viên thấy; dùng cho bài ngày mai, phần giáo án/thuyết trình, cả phổ thông và đại học. Bug thoát/mở lại bảng Bài chưa lưu cần điều tra, không đoán nguyên nhân.

## Hướng chọn

Một editor dàn ý/trang và nội dung cùng notes ngữ cảnh, progressive optional fields. Bài đầy đủ và PDF chỉ thêm lời nhắc đều là first-class. Soạn → Preview hai phía → Dạy/Xuất. Tác vụ nền là trạng thái, nhập nguồn là hành động tại chỗ; AI/video là hỗ trợ phụ.

Hướng thay thế là giữ năm tab và thêm wizard; rẻ hơn trước mắt nhưng vẫn tách nội dung/notes/tài liệu và không giải được mô hình dữ liệu, privacy hay save lifecycle. Không chọn việc viết lại toàn bộ Studio/backend vì có phần đã làm đúng (Java PDF, audience guards) và rủi ro migration cao.

## Phạm vi và điều chưa biết

Core không phụ thuộc API/model. Giữ dữ liệu và chức năng đã có trong traceability matrix. Root cause save bug và writer concurrency cần trace/test trước sửa. Nghiên cứu EEF/DfE/CMU/Cornell/Oak là định hướng, chưa là validation giáo viên Việt Nam. DOCX optional cần compatibility gate; PPTX conversion và animation AI nâng cao để sau.

Xem [kế hoạch 5 giai đoạn](../lesson-preparation-redesign/plan.md), [spec](../lesson-preparation-redesign/spec.md), [nguồn nghiên cứu](../lesson-preparation-redesign/research.md) và [24 luồng nghiệm thu](../lesson-preparation-redesign/acceptance.md). Mọi mục là DRAFT; chờ review, không auto-cook.
