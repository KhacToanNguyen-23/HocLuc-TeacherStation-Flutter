# Brainstorm: In-Board Subject Tool Palette & S-V-O Handwritten Chalk Tool

**Date:** 2026-10-11

## Ideas Explored
- Khay công cụ nổi dạng dock nhỏ gọn (`SubjectToolPalette`) gắn trực tiếp trên bảng phấn thay thế hoàn toàn các modal/drawer web.
- Tương tác chọn câu: Chạm tay / click chuột trực tiếp vào dòng chữ viết tay trên bảng hoặc văn bản trong tệp PDF.
- Công cụ S-V-O: Bóc tách Chủ ngữ (S), Động từ (V), Tân ngữ (O) và tự động vẽ nét gạch chân phấn màu cùng ký hiệu S, V, O ngay dưới nét chữ như giáo viên tự tay cầm phấn gạch.
- Phấn màu thông minh (Smart Chalk Annotation): Hiển thị hòa hợp như nét phấn vẽ thật, đồng thời hỗ trợ nút mắt (👁️ Ẩn/Hiện đáp án) và có thể kéo thả di chuyển linh hoạt.
- Cơ chế thực thi: Tự động 100% ngay khi chạm vào câu văn mà không mở hộp thoại xác nhận trung gian.

## User's Direction
- **Về giao diện**: Một thanh khay công cụ nhỏ gọn nổi trên bảng chứa các icon tính năng bộ môn.
- **Về tương tác**: Giáo viên chạm tay/click trực tiếp vào câu văn trên bảng (chữ viết tay) hoặc câu trong file tài liệu PDF.
- **Về kết quả thể hiện**: Nét gạch dưới và ký hiệu S, V, O xuất hiện như nét phấn vẽ tay thực tế, đồng thời là đối tượng thông minh có thể bấm ẩn/hiện hoặc di chuyển.
- **Về tự động hóa**: Tự động 100% nhận diện và sinh nét gạch S-V-O ngay khi chạm, không cần bước xác nhận trung gian.

## Open Questions
- Thuật toán gom cụm nét vẽ (Stroke clustering theo khoảng cách không gian) để xác định chính xác phạm vi câu văn viết tay giáo viên vừa chạm vào.
- Trình nhận diện chữ viết tay từ nét vẽ (Handwriting / Ink recognition) với từ điển tiếng Anh để xử lý các nét chữ nối hoặc viết ngoáy.

## Risks
- Nét chữ viết tay phức tạp có thể dẫn tới độ trễ xử lý nếu thuật toán gom nét quá nặng -> Cần giới hạn bán kính tìm kiếm nét vẽ quanh điểm chạm.
- Tọa độ gạch chân phải bám sát chân của từng cụm từ viết tay để tạo cảm giác tự nhiên như giáo viên tự gạch bảng.
