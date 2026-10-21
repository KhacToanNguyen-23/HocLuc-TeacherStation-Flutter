# Phase 02 — Video/ghi hình thành bản chép lời có nguồn

Trạng thái: đề xuất. Story: P1 video thành bài. Phụ thuộc: 01.

## Công việc

- Trang kiểm tra thành phần trong app cho phép chọn model đã có trên máy, kiểm tra checksum/version/dung lượng, cài runtime và FFmpeg qua installer được đóng gói hoặc tải có tiến trình khi người dùng chọn. Model weights ngoài Git. Không yêu cầu giáo viên chạy CLI hay tự cấu hình web/app ngoài; offline dùng bộ cài có sẵn và báo rõ asset còn thiếu.

- App cho chọn video/audio, ghi mic hoặc ghi nguồn màn hình do người dùng chọn; preview, dừng, lưu và xóa trước xử lý. Không tự tải video từ URL nền tảng chưa có hợp đồng/quyền.
- Asset store trên đĩa, upload theo luồng, kiểm MIME/chữ ký/kích thước, metadata độ dài; đường dẫn do server sinh. Quản lý quota và xóa file tạm khi hủy/lỗi.
- Worker tách audio bằng FFmpeg argument arrays; chia đoạn có overlap, timestamp toàn cục, ghép transcript không lặp. Không mở rộng endpoint WAV ngắn thành video dài bằng cách giữ toàn bộ file RAM.
- Job có checkpoint bền vững, cancel/retry stage, phục hồi sau khởi động lại. Chỉ một stage model dùng tài nguyên lớn chạy trên máy cấu hình thấp mặc định.
- App biên tập transcript, click câu nhảy tới mốc nguồn, đánh dấu đoạn không chắc hoặc không có lời. Lưu sửa tay thành revision, không ghi đè bởi job cũ.

## Nghiệm thu

- Bộ tổng hợp 1 phút, 15 phút và 60 phút: hoàn tất hoặc trả lỗi có lý do/giới hạn đã công bố; đo thời gian thực, RAM/VRAM đỉnh và dung lượng tạm trên máy mục tiêu.
- Thử im lặng, hai người nói, mất đoạn tiếng, file hỏng, thiếu dung lượng, đóng app giữa stage và hủy. Không có job treo hoặc artifact thành công giả.
- Transcript có sourceAssetId và timestamp hợp lệ; seek tới nội dung đối chiếu, đoạn overlap không xuất hiện hai lần.
- Đo WER và kiểm ngữ nghĩa trên tập audio giữ lại, tiếng Việt/thuật ngữ lớp học; báo riêng hiệu quả STT, không suy ra chất lượng dịch/TTS từ kết quả này.

## Đầu ra

Transcript versioned và source references cho phase 03; báo cáo benchmark thực, cấu hình giới hạn media và case chưa hỗ trợ. Không tự thay đổi chế độ giảng dạy trực tiếp để chạy STT.
