# Test thủ công Soạn bài sau thiết kế lại

Ngày 2026-10-20. Các bước dưới đây chưa được nghiệm thu bằng giáo viên/tài khoản Google thật. Bộ 60 happy case trước đây dùng nhãn UI cũ; dùng tài liệu này và [ma trận 24 luồng](../../plans/lesson-preparation-redesign/acceptance.md) cho bản thiết kế lại.

## 1. Tự soạn và mở lại

1. Dashboard → Soạn bài → tạo bài. Chọn Tự soạn nội dung.
2. Đặt tên bài, viết hai phần. Điền lời nhắc riêng khác nhau tại Hỗ trợ giáo viên. Để trống mục tiêu/thời lượng nếu không cần.
3. Chuyển phần qua lại, đổi thứ tự; lời nhắc phải theo đúng phần. Chờ Đã lưu trên máy chủ, thoát và mở lại.
4. Thử xóa một phần có ghi chú theo trang; kiểm tra lựa chọn giữ/xóa ghi chú và Hoàn tác.

## 2. Bảng/PDF và lời nhắc theo trang

1. Chọn Chuẩn bị bảng trình chiếu. Thêm trang hoặc PDF, lưu và trở về workspace.
2. Mở/đóng/mở lại bảng, lần đầu không sửa; lần sau viết/vẽ rồi lưu; lần nữa chọn bỏ thay đổi. Không được báo lỗi Bài chưa lưu vô nghĩa; dữ liệu đã lưu phải còn.
3. Chọn Lời nhắc theo trang. Gắn lời nhắc cho trang 3 của PDF A, gắn lời nhắc khác cho trang 3 của PDF B. Có thể chọn scope chung hoặc scope một phần bài.
4. Đổi thứ tự trang hoặc thay tài liệu: lời nhắc không được tự gán sang tài liệu mới. Kiểm tra mục lời nhắc cần gắn lại trang; remap phải là hành động chủ động.

## 3. Khi dạy

1. Chọn Dạy từ bài này, chọn lớp theo flow app hiện có.
2. Chuyển trang bảng/PDF: panel giáo viên tự đổi lời nhắc. Khi một trang dùng ở hai phần, chọn đúng phần đang trình bày.
3. Ghim lời nhắc, chuyển nội dung trình chiếu: lời nhắc đã ghim giữ nguyên. Chọn theo trang hiện tại để trở lại tự động.
4. Với tài khoản/thiết bị học sinh QA riêng, xác nhận đầu nhận chỉ có nội dung trình chiếu. Thử đổi nguồn chia sẻ và reconnect; nguồn chưa xác minh phải ẩn notes. Chia sẻ cả desktop không được coi là luồng notes riêng an toàn.

## 4. Nhập nội dung, dùng lại và xuất

1. Thêm nội dung → chọn văn bản, tài liệu/bản ghi, ghi âm hoặc AI theo nhu cầu. Không cần API AI để tự soạn hoặc xuất PDF.
2. Từ bài trống chọn Dùng lại bài cũ → chọn một bài trong thư viện → mở bản sao, sửa và xác nhận bài gốc không đổi.
3. Chèn nhóm câu hỏi đã duyệt: ngữ cảnh/nhóm/ảnh giữ nguyên; lời giải riêng không vào bản học sinh.
4. Xem trước nội dung là bản tóm tắt. Chọn xem PDF xuất thật để kiểm mẫu trường/khoa và bản học sinh/giáo viên bằng file do backend tạo.
5. Tài liệu đã tạo → mở/nghe/xem/tải file. Khi có xử lý mới thấy tiến độ. Chỉ chọn file học sinh để đăng Classroom sandbox; kiểm link bằng học sinh QA.

## 5. Lưu lỗi và phục hồi

1. Tắt kết nối backend khi đang sửa: nội dung phải còn và trạng thái không giả là đã lưu trên máy chủ.
2. Khởi động lại app với cùng tài khoản: chọn khôi phục nháp khi được đề nghị. Đăng nhập tài khoản khác không được thấy nháp tài khoản trước.
3. Sửa cùng bài từ hai nơi: so sánh bản đang sửa/bản máy chủ, chọn rõ bản cần giữ; không được tự ghi đè.
4. Phiên không xác thực khi mở bài phải báo chưa mở được bài, không hiện bài trắng giả là đã lưu.

## Điều kiện riêng

- AI sinh nội dung cần cấu hình provider/model/key ở backend; chưa cấu hình thì không ghi PASS cho luồng gọi API thật.
- STT/dịch/TTS cần runtime và model local; video cần FFmpeg. Những điều kiện này không chặn soạn thủ công hoặc PDF Java.
- Google Classroom/Meet cần tài khoản sandbox, quyền kết nối và đầu nhận thật. Kiểm thử widget/backend không thay thế xác nhận này.
- DOCX/PPTX editing hoặc chuyển đổi chưa bật trong bản này; không đưa chúng vào luồng nhập PDF/ảnh/văn bản hiện có.
