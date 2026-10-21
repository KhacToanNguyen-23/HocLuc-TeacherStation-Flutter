# Nghiên cứu — DRAFT, 2026-10-20

Nguồn sơ cấp dùng làm cơ sở thiết kế, không là bằng chứng rằng giáo viên Việt Nam đã chấp nhận sản phẩm. Nhận xét nhu cầu địa phương cần phỏng vấn và usability thực tế.

| Nguồn | Điểm liên quan | Quyết định thiết kế và giới hạn |
|---|---|---|
| [DfE: Planning and resources workload report](https://www.gov.uk/government/publications/reducing-teacher-workload-planning-and-resources-group-report) | Lập kế hoạch phục vụ tiến trình học; tránh xem giáo án chi tiết như hồ sơ phải sản xuất vì hình thức | Không bắt form đầy đủ cho mọi phần; tái sử dụng/adapt tài liệu; nguồn Anh, không quy định Việt Nam |
| [EEF: Aila teacher choices trial](https://educationendowmentfoundation.org.uk/projects-and-evaluation/projects/aila-teacher-choices-trial) | 81% giáo viên nhóm Aila dùng ít nhất một lần, nhưng công cụ chỉ được dùng cho khoảng 7% bài trong một tuần trung bình; nhu cầu tạo từ đầu khác với điều chỉnh nguồn sẵn | AI không là cửa bắt buộc; tài liệu có sẵn là luồng chính. Nghiên cứu tiểu học ở Anh, không suy luận 7% là tỷ lệ giáo viên chấp nhận ở Việt Nam hay tác động của HocLuc |
| [CMU: Alignment](https://www.cmu.edu/teaching/assessment/basics/alignment.html) | Mục tiêu, hoạt động và đánh giá cần phù hợp | Gợi ý nối mục tiêu/câu hỏi khi cần, không biến thành ba form bắt buộc |
| [Cornell: Defining learning outcomes](https://teaching.cornell.edu/teaching-resources/preparing-teach/designing-your-course/defining-learning-outcomes) | Kết quả học tập rõ và quan sát được hỗ trợ thiết kế học phần | Cho mục tiêu tùy chọn với ví dụ theo cấp học; hoạt động đại học linh hoạt |
| [Oak: Lesson planning](https://www.thenational.academy/lesson-planning) | Nguồn bài dạy có thể dùng và điều chỉnh | Thư viện/reuse/class variants hữu ích hơn một hộp prompt độc lập; không sao chép nội dung có bản quyền ngoài điều kiện cho phép |

## Giả thuyết cần thử

1. Giáo viên chuẩn bị từ tài liệu cũ thường xuyên hơn từ một trang trắng; cho bắt đầu bằng PDF và notes giảm nhập lại.
2. Notes ngay ngữ cảnh đang dạy có giá trị hơn một danh sách ghi chú tách rời.
3. Chỉ tên phần + nội dung ở lần đầu giúp người mới hiểu hơn form dài; optional fields vẫn đủ cho người cần giáo án đầy đủ.
4. Preview hai phía giúp hiểu dữ liệu nào học sinh nhìn thấy; chỉ receiver thật mới xác minh bảo mật đường truyền.

Các giả thuyết này chưa có kết quả đo của HocLuc. Nghiên cứu không chứng minh thêm nhiều tính năng là tốt hơn. Mẫu 2345/5512 chỉ xem xét sau khi lấy tài liệu trường đang sử dụng và kiểm tra phiên bản; không khẳng định là nghĩa vụ pháp lý hiện hành.

## Điều tra code được đưa vào kế hoạch

PlanningService là điểm common persistence cần kiểm soát writers. Thông báo Bài chưa lưu có guard frontend nhưng nguyên nhân chuỗi thoát/mở lại chưa xác định. PDF đã Java native và speaker notes có audience protection; hai phần này được giữ và nghiệm thu lại. Không lấy screenshot rỗng làm bằng chứng backend hỏng hoặc tính năng chưa tồn tại.

Screenshot hiện đồng thời banner chưa xác thực và nhãn Đã lưu: cần phân biệt saved local/server và load/auth failure thay trạng thái gây hiểu nhầm. Tác vụ còn lộ raw JSON ở kết quả trong code review: thay bằng tóm tắt dùng được/action theo loại, chi tiết kỹ thuật chỉ là disclosure chẩn đoán.
