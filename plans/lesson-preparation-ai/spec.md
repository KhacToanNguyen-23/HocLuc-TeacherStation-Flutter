# Spec: AI trong Soạn bài

Date: 2026-10-19
Status: Draft for implementation; chưa phải chức năng đã triển khai.

## Problem Statement

Giáo viên tạo và duyệt học liệu ngay trong HocLuc từ video/ghi âm, script hoặc prompt; xuất giáo án, bài giảng và video animation có lời đọc; đăng học liệu lên Google Classroom. STT, translation và TTS phục vụ soạn bài theo lô, không là điều kiện để vào dạy trực tiếp (mode 2).

## Quyết định của người dùng

- Hỗ trợ cả animation đơn giản và cảnh/nhân vật sinh bởi AI; ưu tiên animation đơn giản trước.
- MVP ưu tiên lời đọc tiếng Anh bằng model hiện có.
- Mọi thao tác nghiệp vụ thực hiện trong HocLuc: nhập nguồn, ghi âm/ghi hình, sửa transcript, soạn nội dung, nghe thử, chỉnh scene, render, chọn lớp và đăng tài liệu.
- Quyền sử dụng dịch vụ AI online chưa được chọn: mặc định local-first, không tự gửi nguồn/nội dung tới dịch vụ cloud; adapter cloud tắt tới khi giáo viên chọn sử dụng.

## User Stories

- **[P1] Nguồn media:** Giáo viên nhập MP4/WAV hoặc ghi bài trong app, chọn đoạn và sửa transcript có timestamp. Accepted when: nguồn 10 phút được xử lý qua job theo từng đoạn, xem tiến trình, hủy được, mở lại app giữ kết quả các bước đã hoàn thành.
- **[P1] Soạn từ nội dung:** Giáo viên tạo giáo án và storyboard từ transcript/script/prompt, sửa mục tiêu, hoạt động, script và scene. Accepted when: đầu ra đúng schema, mỗi phần có nguồn tham chiếu khi có nguồn; không tự ghi đè chỉnh sửa của giáo viên.
- **[P1] Video tiếng Anh:** Giáo viên dịch script Việt sang Anh, nghe TTS, dựng animation template. Accepted when: render MP4 1280x720, 25 fps, dài 1–5 phút với ít nhất 3 scene, âm thanh tiếng Anh, phụ đề SRT; không cần tài khoản dịch vụ video online.
- **[P1] Đăng Classroom:** Giáo viên chọn lớp và bản học sinh trong app. Accepted when: nhận material ID/link thật, học sinh của lớp mở được tài liệu; mô phỏng mất mạng không được blind-retry tạo bài trùng; ghi chú riêng không nằm trong payload/artifact.
- **[P1] Hỗ trợ giảng dạy riêng:** Giáo viên đọc ghi chú theo trang bên cạnh điều khiển bài. Accepted when: ghi chú/đáp án chỉ ở teacher view; audience output và bản xuất học sinh không có nội dung riêng; kiểm tra stream thực từ tài khoản học sinh. Khi không xác định được nguồn chia sẻ an toàn, app không khẳng định riêng tư và không tiếp tục hiển thị ghi chú nhạy cảm trong cửa sổ đang chia sẻ.
- **[P2] Tái sử dụng và kiểm soát chất lượng:** lịch sử phiên bản, glossary, sửa phát âm, tái tạo riêng scene, diễn tập thời lượng và kiểm tra trước xuất bản. Accepted when: tái tạo một scene không thay scene khác, phục hồi được revision trước, mọi cảnh báo nguồn/âm thanh được chỉ đúng scene.
- **[P3] Cảnh/nhân vật sinh bởi AI:** provider adapter riêng, vẫn thao tác trong app. Accepted when: provider được chọn sau đánh giá chất lượng, chi phí, dữ liệu và khả năng tích hợp; không dùng ba model speech để giả làm model video.

## Functional Requirements

1. FR-01: Tách thao tác STT, dịch và TTS; không ép chạy cả ba với đầu vào script tiếng Anh.
2. FR-02: Dùng PhoWhisper cho nhận dạng tiếng Việt, VinAI cho Việt → Anh, Kokoro cho lời đọc tiếng Anh theo adapter hiện tại; không suy rộng thành hỗ trợ đa ngôn ngữ.
3. FR-03: Thêm LessonAuthoring interface sinh nội dung có cấu trúc; chọn/checkpoint và đánh giá riêng. Model dịch hiện tại không thay thế LLM soạn bài. Cho phép nhập/chỉnh script thủ công khi bộ sinh nội dung chưa sẵn sàng.
4. FR-04: Animation MVP từ scene schema và template (text, ảnh, sơ đồ, highlight, pan/zoom, transition), không chạy mã tùy ý do model sinh. Renderer dựng timeline theo độ dài audio từng scene.
5. FR-05: Import file, thu micro hoặc ghi nguồn cửa sổ/màn hình được giáo viên chọn trong app; có start/pause/stop, preview, lưu nguồn và chọn khoảng thời gian. Không mặc định thu buổi Meet/học sinh.
6. FR-06: Giữ media/ảnh/audio/render trên disk, API trả asset IDs thay base64 toàn video; xác thực quyền sở hữu tại backend, kiểm tra MIME/kích thước và disk quota. Job có checkpoint, tiến trình thật, cancel và retry từng bước.
7. FR-07: Phân biệt teacherNotes, narrationScript và studentContent. Export/publication dùng allowlist bản học sinh; không upload toàn bộ lesson JSON hoặc handout chứa notes.
8. FR-08: Classroom publishing dùng Drive upload và CourseWorkMaterials API, tái sử dụng OAuth hiện hữu và cấp quyền bổ sung theo khả năng. Lưu mapping project/revision/artifact/course/Drive file/material và trạng thái reconciliation.
9. FR-09: Giao diện app điều phối mọi nghiệp vụ. Đăng nhập/consent Google và bộ chọn nguồn chia sẻ vẫn theo cơ chế hệ thống hợp lệ; không hứa ép Google OAuth vào embedded WebView. App tiếp tục tác vụ sau callback.
10. FR-10: Tái sử dụng CRUD planning, board/PDF, notes theo trang và connector hiện có; không tạo portal hay login riêng cho học sinh.
11. FR-11: App có kiểm tra/cài thành phần hoặc bundled installer cho runtime, model và FFmpeg; chọn model local, xác minh version/hash và tiến trình tải ngay trong app. Không buộc giáo viên dùng terminal để hoàn tất workflow.

## Non-Functional Requirements

- Mỗi máy chạy tối đa 1 job inference/render nặng trong MVP; nạp model theo bước, không yêu cầu đủ ba model nằm GPU cùng lúc.
- API job trả job ID trước khi xử lý dài; không giữ một HTTP request chờ render toàn video. UI có thể hủy và tiếp tục dùng app.
- Model weights nằm ngoài Git; không sửa dataset/env/cache cá nhân. Sidecar port động, tiến trình được quản lý và giải phóng sau job.
- Timing acceptance: chênh lệch audio/video tổng ≤ 250 ms; từng scene không cắt cụt lời đọc. Đo thời gian render và peak RAM/VRAM trên máy thật; chưa cam kết realtime.
- STT đánh giá WER/CER; dịch đánh giá độ đúng nghĩa trên held-out (số, phủ định, thuật ngữ); TTS đánh giá nghe/độ rõ phát âm. Không dùng loss hoặc vài ví dụ làm chứng minh chất lượng.

## Success Criteria

- [ ] Một video nguồn 10 phút → transcript sửa được → giáo án/storyboard → video demo 1–5 phút qua app.
- [ ] Một prompt và một script tiếng Anh tạo được storyboard sửa được và video, không cần STT/dịch khi không phù hợp.
- [ ] Sửa một scene rồi render lại giữ nguyên các scene còn lại và revision nguồn.
- [ ] Đăng bản học sinh thành công vào một lớp thử; học sinh mở đúng artifact; ghi chú riêng vắng mặt ở MP4, PDF, subtitles, metadata và Classroom description.
- [ ] Ghi chú hiển thị cho giáo viên trong lúc trình chiếu, vắng mặt trên stream thật của học sinh.
- [ ] Mode 2 không cần khởi động AI runtime để vào dạy; chuyển chức năng live cũ chỉ sau khi đường Soạn bài được nghiệm thu.

## Out of Scope / Giới hạn

- Không bắt học sinh cài HocLuc hoặc tạo luồng nộp bài/thi trực tuyến.
- Không coi văn bản trong ảnh/video đã được STT đọc hiểu; trích xuất hình/OCR là adapter bổ sung, phải có nguồn/timestamp.
- Không cam kết voice cloning, TTS tiếng Việt, video điện ảnh hoặc xử lý realtime bằng ba adapter hiện có.
- Chưa chọn provider video/cloud hoặc model authoring/checkpoint; đây là quyết định kỹ thuật cần benchmark, không ngăn thiết kế template/render và script thủ công.

## Assumptions

- Ưu tiên Flutter Windows native; khả năng Web/portable được kiểm chứng riêng.
- MVP publish học liệu (material), không mở rộng sang assignment/submission.
- Giáo viên duyệt nội dung trước render/publish; không tự đăng bản model sinh.
