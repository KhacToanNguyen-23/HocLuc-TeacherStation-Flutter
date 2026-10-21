# Spec: Phân hệ SOẠN BÀI của HocLuc

Date: 2026-10-19
Status: Draft — thay cách trình bày danh sách ý tưởng bằng kế hoạch sản phẩm trong app.
Plan: [plan.md](plan.md).

## Problem Statement

Giáo viên cần một nơi trong HocLuc để chuẩn bị bài từ nguồn có sẵn hoặc script/prompt, chỉnh giáo án/bảng/video, tạo lời đọc tiếng Anh, ghi chú riêng, xuất/đăng học liệu và mang bài sang dạy. Không bắt học sinh dùng app và không bắt mở Meet để soạn.

## P1 User Stories

1. **Quản lý bài:** mở Dashboard → Soạn bài để tìm, mở, nhân bản hoặc tạo bài. Accepted when: bài cũ giữ nguyên nội dung và có thể mở/lưu/dạy không cần AI.
2. **Chọn nguồn:** tạo từ bài trống, PDF/script, MP4/WAV, ghi nguồn hoặc prompt. Accepted when: mỗi lựa chọn mở cùng workspace theo planningId; nguồn/lỗi/job không làm mất bài.
3. **Biên tập:** chuyển Nội dung bài / Bảng & tài liệu / Video trong một workspace; notes và nguồn là panel. Accepted when: lưu/phục hồi đúng mục; không mở thêm phiên dạy khi chỉnh board.
4. **AI soạn bài:** sửa transcript, tạo nháp giáo án/storyboard, dịch chọn phần. Accepted when: giáo viên duyệt trước áp dụng, không ghi đè phần sửa; không gán VinAI vai trò LLM.
5. **Giọng/video:** chọn scene, tạo/ nghe TTS Anh, preview và dựng MP4. Accepted when: video demo 720p25 1–5 phút ≥3 scene đúng script, caption và version; sửa script làm artifact cũ cần tạo lại.
6. **Xuất bản:** Xuất/Đăng → chọn bản học sinh/file → chọn lớp → Đăng. Accepted when: có Google material ID thật, học sinh mở được, retry đối soát không tạo trùng; PDF không phụ thuộc render video.
7. **Mang sang dạy:** Dạy → lưu → chọn lớp → launcher/Studio hiện hữu. Accepted when: không tự bật model AI; notes chỉ giáo viên thấy qua đường output thực đã kiểm chứng, không chỉ RepaintBoundary.

## P2

Reuse khối nội dung, biến thể bài theo lớp, chèn câu hỏi từ kho đã duyệt, phản hồi để sửa bài, mẫu trường/khoa. Đặt trong menu/panel phù hợp ở workspace theo plan, không module riêng. Animation nhân vật/cảnh AI sau MVP.

## Functional Requirements

- Một kho bài/ID; tái sử dụng PlanningService, Studio và connector hiện có.
- Bài không bắt buộc có đủ giáo án/slide/video; các công cụ mục tiêu/activity/CLO/rubric tùy chọn.
- STT Việt, dịch Việt→Anh, TTS Anh theo adapter hiện có; script Anh bỏ STT/dịch. Prompt cần authoring adapter riêng; animation cần renderer.
- Schema có revision, stable section/scene IDs, assets, jobs, artifact freshness và publication theo lớp/revision.
- Nội dung học sinh, script đọc, teacher notes/private answers tách; export/publication dùng allowlist.
- File ngoài app cần preview và giáo viên xác nhận bản học sinh; không hứa preflight tự tìm mọi đáp án/notes đã nhúng trong PDF/MP4 ngoài.
- Media trên disk, job bền vững có tiến trình/hủy/thử lại; xử lý dài không khóa editor.
- Thiết lập runtime/model/FFmpeg, chọn file, ghi nguồn, preview, sửa và xuất bản từ app. OAuth/source picker theo cơ chế nền tảng hợp lệ, không hứa bỏ consent Google.
- Điều chỉnh đã xác nhận: AI sinh giáo án/storyboard dùng API bên thứ ba qua backend, endpoint/model cấu hình được vì chưa chọn provider. STT/dịch/TTS giữ ba model hiện có. Mỗi yêu cầu gửi nội dung ra ngoài có preview/xác nhận; key chỉ ở backend. Chia script thủ công và các công cụ biên tập vẫn local; không portal/submission hay tài khoản học sinh mới.

## Success Criteria

- [ ] Demo thật script → nội dung/scene → TTS → MP4 → đăng Classroom, thao tác từ HocLuc.
- [ ] Demo thật video/ghi nguồn → transcript sửa được → giáo án/bảng → Dạy bằng Studio.
- [ ] Bài cũ và bài mới không mất dữ liệu qua save/reopen, clone hoặc job lỗi.
- [ ] Notes/đáp án riêng không nằm trong artifact/payload học sinh và stream audience nghiệm thu.
- [ ] Thiếu model/lỗi Google/render có đường khôi phục trong app, không bắt chạy terminal.
- [ ] Mode 2 vào dạy khi AI worker dừng/thiếu model; không ảnh hưởng micro/camera Meet bình thường.

## Out of Scope

Triển khai code trong lượt plan lại; xây app con học sinh; thay Google Meet/Classroom; một dashboard mới; editor board/PDF mới; chatbot cho từng tiện ích; bảo đảm prompt/video nâng cao bằng ba speech model; cam kết mọi DOCX/PPTX hay mọi mẫu trường ngay MVP.

## Assumptions

Ưu tiên Windows native và ngôn ngữ narration tiếng Anh đã chọn. Web/portable có gate riêng. Dịch vụ cloud/video chưa được chọn nên không gửi nội dung ra ngoài mặc định. Mô hình authoring và audience output phải được kiểm chứng trước nghiệm thu chức năng phụ thuộc.
