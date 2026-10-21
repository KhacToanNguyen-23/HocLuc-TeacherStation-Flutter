# Design brief — DRAFT

## Cảm giác sử dụng cần đạt

Giáo viên biết đang soạn phần nào, nội dung nào học sinh sẽ thấy và lời nhắc nào chỉ mình thấy. Không cần biết script/transcript/job là gì để hoàn tất bài. Nhãn theo công việc; không phô thuật ngữ backend hay cấu hình model trong luồng cơ bản.

## Chiến lược thiết kế

Giữ hệ token Manrope, xanh dương/slate hiện có; light theme cho bàn làm việc giáo viên ban ngày, phân cấp bằng khoảng cách/typography hơn là nhiều khung nổi. Notes private có nhãn và icon khóa rõ, không chỉ dựa vào màu. Tham khảo tương tác Word outline để dẫn phần và PowerPoint Presenter để hình dung hai audience; đây là reference thiết kế, không phải tuyên bố sản phẩm đã tích hợp hoặc sao chép tính năng. Không cần thay nhận diện app hay tạo bitmap mockup ở vòng sketch này.

```text
← Soạn bài   Vòng tuần hoàn nước    Đang lưu…  Xem trước  Dạy  Xuất/chia sẻ
┌──────────────────┬──────────────────────────┬────────────────────────┐
│ DÀN Ý / TRANG    │ KHỞI ĐỘNG                │ HỖ TRỢ GIÁO VIÊN       │
│ 1 Khởi động     │ Nội dung đang soạn       │ Lời nhắc riêng         │
│ 2 Kiến thức mới │ + Thêm nội dung          │ Đáp án / lỗi hay gặp   │
│ 3 Luyện tập     │ Tài liệu dùng ở phần này │ + Thêm ghi chú         │
│ + Thêm phần     │ [PDF trang 3] [Câu hỏi]  │                        │
│                 │ ▸ Thời gian / mục tiêu  │                        │
└──────────────────┴──────────────────────────┴────────────────────────┘
                   Tài liệu đã tạo • PDF học sinh • PDF giáo viên
```

Đây là sketch cấu trúc, chưa phải pixel mockup hoặc UI đã chạy. Panel phải co/thu gọn ở cửa sổ hẹp, giữ tiêu đề và nội dung chính; không ba cột cố định gây overflow.

## Ba kịch bản cụ thể

### A. Phổ thông, 45 phút: Vòng tuần hoàn nước

Tạo bài → tên bài một lần → Khởi động 5 phút, Kiến thức 15, Hoạt động nhóm 15, Tổng kết 10. Chỉ nhập mục tiêu nếu cần. Đính ảnh/PDF vào phần Kiến thức; chèn nhóm hai câu hỏi đã duyệt vào Tổng kết. Notes riêng: “Hỏi sự khác nhau bốc hơi/ngưng tụ; đừng đọc đáp án ngay”. Preview học sinh không có đáp án; dạy đổi phần/trang thì notes đổi theo. Xuất hai PDF nếu cần.

### B. Đại học, 90 phút: Nhập môn học máy

Mở bài cũ và tạo biến thể lớp K24 → gắn PDF có sẵn → liên kết trang 3–8 với phần Ví dụ 25 phút, thêm thảo luận 20 phút và các phần khác đủ 90. Notes trang 3 nhắc câu hỏi mở, trang 7 có ví dụ mở rộng; chỉnh bản lớp không đổi bài gốc. Kết thúc ghi reflection “lớp cần thêm ví dụ overfitting”, tạo revision cho lần sau.

### C. Thuyết trình độc lập, 10 phút

Thêm PDF 5 trang → gắn note trang 3 “Dừng 20 giây, hỏi người nghe” → lưu → preview/dạy. Không cần nhập mục tiêu, hoạt động học sinh, form giáo án hay thời lượng từng phần. Đổi sang trang 3 hiện note tương ứng. Thoát và mở lại giữ trang/notes đã lưu theo chính sách resume rõ ràng.

## Bắt đầu và nhập tài liệu

Empty state có ba lựa chọn: Tự soạn / Dùng tài liệu có sẵn / Dùng lại bài cũ. Không bắt wizard với bài đã có. “Thêm nội dung” cho văn bản, ảnh, PDF, câu hỏi; ghi âm/video/AI nằm nhóm phụ. Sau nhập, app cho chọn Gắn tài liệu / Lấy văn bản (nếu loại hỗ trợ) / Chuẩn bị trình chiếu. Không hứa PDF OCR. DOCX unsupported layout cần nói rõ trước import; PPTX chỉ gắn file, chưa mở thành slide native.

## Presenter

Nút Xem trước cho thấy hai ảnh/view có nhãn Giáo viên và Học sinh. Presenter notes theo page/activity đang hiển thị, ghim thủ công có nhãn và nút Theo trang hiện tại. Mất audience verified thì ẩn notes theo fail-closed policy hiện có và hướng dẫn chọn lại nguồn. Không đòi chuyển tab ngoài app để xem notes. Không tự bật nguồn chia sẻ desktop khi bật notes.

## Rỗng, lỗi và tiến độ

Chưa có tài liệu xuất: “Tạo PDF từ bài này” thay danh sách rỗng. Không có tác vụ thì không chiếm một tab riêng. Lỗi lưu có retry/giữ nháp/chi tiết phù hợp, không lộ stack trace. Auth banner giải thích thao tác nào cần xác minh; nội dung nháp không biến mất khi sửa kết nối.
