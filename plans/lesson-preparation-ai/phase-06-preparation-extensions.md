# Phase 06 — Tiện ích soạn bài mới và cảnh sinh AI tùy chọn

Trạng thái: đề xuất, P2/P3. Phụ thuộc: 03–05. Trước mỗi mục, đối chiếu code hiện tại để tái sử dụng, không làm lại CRUD/clone, notes hoặc danh sách lớp đã có.

## P2: tiện ích giá trị trực tiếp

- Glossary theo bài/lớp: sửa thuật ngữ dùng chung cho dịch, phụ đề và hướng dẫn phát âm. Nghiệm thu: đổi một mục chỉ đánh dấu các cảnh phụ thuộc cần tái tạo.
- Bằng chứng theo timestamp: nhấn câu giáo án mở đúng đoạn nguồn; báo đoạn do AI thêm. Nghiệm thu: mọi trích dẫn có source/version/time range hợp lệ hoặc hiển thị thiếu nguồn.
- Rehearsal thời lượng: chạy thử trong app, so thời gian đọc thực với lịch bài, chỉ rõ cảnh vượt thời lượng. Nghiệm thu: đo playback và tổng timeline khớp trong sai số đã xác định khi triển khai.
- Revision và selective regeneration: diff nội dung, giữ cảnh khóa, chỉ tái render phụ thuộc đổi. Nghiệm thu: sửa một scene không tái synth/render cảnh độc lập còn nguyên cache key.
- Phụ đề song ngữ và accessibility: bật/tắt caption, kiểm tương phản, cỡ chữ và nội dung vượt khung. Nghiệm thu: xem trên điện thoại, caption không cắt và đúng ngôn ngữ.
- Preflight gói học liệu: kiểm asset thiếu, font, bản quyền/nguồn do giáo viên cung cấp, cảnh quá dài, caption, notes riêng và quyền Classroom. Nghiệm thu: liệt kê lỗi theo cảnh và dẫn tới chỗ sửa trong app; lỗi chặn phải được sửa trước publish.

## P3: cảnh/nhân vật tạo bằng AI

Định nghĩa `SceneGenerationProvider` nhận mô tả cảnh, reference đã được phép, style, duration; trả job/status/asset metadata. Không chọn nhà cung cấp, giá hoặc thời gian render giả định. App phải hiển thị chi phí dự kiến khi có thể tính, cho duyệt trước yêu cầu tính phí, xử lý quota/cancel và retry có kiểm soát. Nội dung sinh là asset đưa vào storyboard, qua cùng duyệt/render/privacy gate, không thay renderer bằng mã tùy ý.

Cổng mở: chốt nhà cung cấp và ngân sách, điều khoản dùng hình/giọng, retention media, bộ kiểm chất lượng có bài dạy tiếng Việt và hành vi mất mạng. Chưa đạt các cổng thì giữ adapter tắt và vẫn dùng đầy đủ animation đơn giản.

## Bàn giao

Ma trận tính năng đã có/tái sử dụng/mới, báo cáo người dùng thử trong app, benchmark và Google student receiver evidence. Chạy gate repo theo plan; không ghi “hoàn tất” cho phần chưa có nghiệm thu thực trên máy/Google account mục tiêu.
