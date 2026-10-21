# Thiết kế lại Soạn bài

Status: IMPLEMENTED / automated checks and release builds verified — nghiệm thu giáo viên và Google receiver còn chờ.
Mode: bb-cook — triển khai theo xác nhận người dùng, có kiểm thử và review.
Risk: high-risk — dữ liệu bài, xác thực, chia sẻ màn hình và Google; không tự nhận đạt nghiệm thu thực tế từ CI.
Date: 2026-10-20

## Session Notes

**Last active:** 2026-10-21.
**Status:** Đã triển khai editor thống nhất, notes theo locator, scoped persistence/migration, recovery và preview. Flutter toàn bộ 483 tests PASS; backend package 239 tests PASS; analyzer No issues found; release Web và Windows build thành công. Plugin validator 2 plugins đạt. Backend mới chạy, bootstrap HTTP 200. Không tự nhận đã nghiệm thu receiver/Classroom/usability.
**Quyết định:** Tái sử dụng Studio và PDF Java; giữ scope riêng giáo án/bảng; ghi chú PDF theo document/fingerprint/page; ghim giữ cả phần và trang; video/API không chặn core. DOCX/PPTX chuyển đổi không bật trong đợt này.
**Nghiệm thu còn cần người dùng:** Đầu nhận Meet và Classroom sandbox, usability giáo viên thật. [Hướng dẫn test bản mới](../../docs/testing/lesson-preparation-redesign-uat.md).

## Kết quả cần đạt

Giáo viên phổ thông hoặc giảng viên chuẩn bị được một tiết, một phần bài, hoặc một bài thuyết trình; khi dạy, nội dung đúng phần/trang tự đưa lời nhắc riêng tới giáo viên, trong khi học sinh chỉ thấy nội dung được chọn trình chiếu. Không bắt nhập lại giáo án khi đã có PDF.

## Thay đổi tư duy sản phẩm

Bỏ mô hình năm tab ngang ngang nhau dựa theo pipeline xử lý. Một không gian chính gồm dàn ý, nội dung phần đang chọn và tài liệu liên quan. Giáo viên bắt đầu từ bài trống, tài liệu có sẵn hoặc bản sao bài đã dùng. Các hành động chính: Soạn bài → Xem trước khi dạy → Dạy hoặc Xuất/chia sẻ. Nhập tài liệu là hành động tại chỗ; tác vụ nền là trạng thái nhỏ; video là công cụ phụ tùy chọn.

Hai cách dùng đều là luồng chính: (1) soạn giáo án có hoạt động; (2) chỉ gắn lời nhắc vào các trang PDF hoặc bài trình bày có sẵn. Không bắt tạo hoạt động giả để dùng cách thứ hai.

## Phạm vi tối thiểu và cách tiếp cận

Chức năng đã có nhưng luồng và trạng thái chưa đạt yêu cầu. Tận dụng PlanningService, Studio planning mode, tài liệu preparation, PDF Java và hàng rào audience hiện có; thay bố cục và hợp đồng dữ liệu, không viết lại toàn bộ ứng dụng. So với cách thêm wizard vào năm tab cũ, không gian thống nhất ít chuyển ngữ cảnh hơn và giữ quan hệ phần/trang/lời nhắc rõ hơn. Wizard chỉ dùng ở điểm bắt đầu, không là đường bắt buộc khi chỉnh sửa.

| Giai đoạn | Kết quả review được | Gate trước bước tiếp |
|---|---|---|
| [01 — Nền tảng](phase-01-foundation.md) | Bài mở/lưu/ra-vào bảng ổn định, giữ dữ liệu cũ | Kiểm thử lỗi và merge đồng thời; vòng lặp bảng 20 lần |
| [02 — Trình soạn](phase-02-lesson-editor.md) | Một editor dùng được cho bài mới và PDF có notes | Ba kịch bản mẫu hoàn tất không AI |
| [03 — Hỗ trợ khi dạy](phase-03-teacher-presenter.md) | Notes theo phần/trang, preview hai phía | Receiver thật xác minh không lộ notes |
| [04 — Học liệu và xuất](phase-04-materials-exports.md) | Xuất đúng đối tượng, tái sử dụng, Classroom có kiểm soát | PDF không cần speech runtime; phân quyền/đáp án đúng |
| [05 — Nghiệm thu](phase-05-validation.md) | Usability và regression có bằng chứng | Không còn lỗi P1, đạt ngưỡng trong acceptance |

Mỗi phase có thể review riêng; không triển khai phase sau để che lỗi nền tảng phase trước. Không đặt lịch công bố trước khi đo effort thực tế và xử lý các gate.

## Tài liệu đi kèm

- [Spec](spec.md): stories, dữ liệu, giữ/làm lại/để sau.
- [Nghiên cứu](research.md): nguồn sơ cấp và giới hạn suy luận.
- [Design brief](design-brief.md): bố cục và luồng cụ thể.
- [Nghiệm thu](acceptance.md): 24 luồng, dữ liệu mẫu, bằng chứng cần thu.

## Điều tra trước triển khai

Luồng mở bảng trong `preparation_workspace_screen.dart` có guard `if(c.dirty)` trước `widget.onOpenBoard` (khoảng dòng 578–581 ở snapshot review). Guard trong `preparation_workspace_actions.dart` với dirty/conflict thuộc luồng giảng dạy, không phải bằng chứng root cause mở bảng. Cần trace load/save/revision trước và sau pop, auth, autosave và board write để xác định vì sao dirty vẫn tồn tại sau return. Không chữa bằng bỏ guard, reset dirty hoặc thay toàn bộ planning JSON.

Backend PDF đã chạy Java riêng qua PreparationJobs → PreparationPdf; phải giữ không phụ thuộc Python/speech/API AI. Studio đã có notes theo trang và audience fail-closed; phải nối/migrate và xác minh đúng, không mô tả như xây từ số không.

## Rủi ro và quyết định còn cần xác nhận

- Trường hợp chia sẻ cả desktop không đảm bảo bí mật notes; chỉ bật luồng notes bảo vệ khi audience target/source đã xác minh. Preview không thay thế receiver test.
- Dữ liệu local tách theo chủ sở hữu xác minh và bài; không chuyển nháp sang tài khoản khác khi logout/login.
- DOCX tương thích cần corpus và gate riêng; PPTX chỉ attachment ở phạm vi này, conversion/preview là phần để sau, không hứa native editing.
- Phỏng vấn/thử với giáo viên Việt Nam chưa có; ba kịch bản hiện là giả thuyết sản phẩm, không được gọi là nhu cầu đã xác thực.
- Người dùng đã xác nhận sửa code theo plan. Các kế hoạch cũ là tài liệu tham khảo; nghiệm thu receiver, Classroom và usability được ghi riêng, không tự coi CI là xác nhận dùng thực tế.
