# Phase 01 — Bài soạn có revision và ghi chú riêng

Trạng thái: đề xuất. Story: P1 ghi chú riêng; nền tảng P1 nhập/tạo/xuất bài. Phụ thuộc: [spec.md](spec.md).

## Công việc

- Audit và tái sử dụng PlanningService/LocalService, bài soạn cũ và pageNotes. Thiết kế schema có phiên bản, revision, source/artifact reference và `teacherOnlyNotes`; migration idempotent, có backup và đường đọc dữ liệu cũ.
- Tách view model giáo viên và projection học sinh. Output projector, PDF/video và gói publish chỉ đọc allowlist; không lấy nguyên lesson JSON chứa notes/đáp án. Handout exporter hiện có pageNotes: giữ bản giáo viên nếu cần, thêm bản học sinh loại notes và cấm dùng bản giáo viên trong publish học sinh.
- Hoàn thiện notes theo trang trong app, mở bằng phím tắt và điều khiển nhỏ, tự theo trang khi dạy, hỗ trợ màn hình hẹp. Không xây lại một thanh notes đã tồn tại.
- Làm clean presentation output riêng, không chứa controls/notes. Xác minh cách chia sẻ output đó qua luồng Meet thực tế; getDisplayMedia picker không cho app bảo đảm người dùng chọn đúng nguồn. Chặn tự hiện notes khi nguồn chia sẻ chưa xác minh; cung cấp trạng thái rõ ràng trong app và xác nhận output bằng bước kiểm tra thực.
- Dữ liệu mới ở `features/lesson_preparation/`, test dưới `test/features/lesson_preparation/`; không thêm thư mục phẳng vào lib hoặc test root.
- Vô hiệu trạng thái output an toàn mỗi lần bắt đầu stream mới, mở picker, đổi nguồn hoặc không còn xác định nguồn. Ẩn cả notes đã mở trước khi gọi picker/chia sẻ; xác nhận thủ công một lần không đủ bảo đảm các lần chia sẻ sau. Nếu platform không phát hiện được đổi nguồn thì giữ trạng thái chưa xác minh, không hiển thị notes trong cửa sổ có thể đang được capture.
- Audit các lời gọi connect/start AI trong đường mở lớp; tách khỏi mode 2. Sau nghiệm thu Soạn bài, chuyển control STT/dịch/TTS sang Soạn bài và bỏ phụ thuộc tự khởi động AI khỏi live flow; giữ điều khiển micro/camera Meet thông thường.

## Nghiệm thu

- Mở/sửa/lưu lại corpus bài soạn cũ không mất trang, annotation hoặc pageNotes; migration chạy hai lần không nhân bản.
- Notes được lưu sau đóng/mở app và bám đúng trang; không cần đổi tab để đọc.
- Chụp output, PDF, MP4, payload Classroom và xác nhận không có chuỗi sentinel trong notes/đáp án.
- Trên máy giáo viên và tài khoản học sinh tham gia Meet: thao tác notes/đổi trang, thiết bị học sinh chỉ thấy nội dung dạy. Thử chọn nhầm toàn màn hình và mất/chuyển nguồn capture; không tuyên bố riêng tư khi chưa xác minh.
- Xác minh web/Windows riêng; nếu clean output chưa hỗ trợ một nền tảng, ghi rõ giới hạn thay vì coi pass chung.
- Dừng AI worker, giả lập thiếu model: vẫn mở/join Meet, quản lý lớp và Calendar bình thường; không tạo worker AI khi vào dạy. Test cả lần đầu mở app và quay lại từ Soạn bài.

## Kiểm thử và rủi ro

Unit migration/projection; widget notes và navigation; integration capture thực. Gate kiến trúc/analyzer theo plan. Lưu fixture tổng hợp, không đưa ghi chú giáo viên thật vào Git. Phase này là cổng trước mọi artifact dành cho học sinh.
