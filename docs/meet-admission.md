# Duyệt yêu cầu Google Meet trong app

Tính năng dành cho bản Windows. Giáo viên dùng tài khoản chủ phòng trong phiên
WebView2 của app; học sinh dùng Google Meet bình thường. Quyền chủ phòng và cài
đặt truy cập phòng của Google quyết định ai phải xin vào. Phòng cho phép vào
thẳng sẽ không phát sinh yêu cầu duyệt.

## Luồng sử dụng

1. Tạo hoặc kết nối phòng trong app, bảo đảm giáo viên đã vào cuộc gọi bằng
   tài khoản có quyền duyệt. Nút mở Meet cạnh link phòng trên thanh trên cùng mở chính phiên Meet này
   trong app, kể cả khi cần đăng nhập hoặc kiểm tra quyền chủ phòng.
2. Trong Studio, nút thêm người nằm ngay trong thanh bút/tẩy có sẵn bên trái,
   hiển thị khi phòng Meet đang mở. Khi có yêu cầu, nút có thêm chấm đỏ. App
   không tự mở hộp hoặc tự duyệt. Không có sidebar thông báo riêng.
3. Bấm biểu tượng để xem tên tài khoản và email nếu Meet cung cấp. Bấm
   **Xác nhận tất cả** để duyệt danh sách tại thời điểm bấm.
4. Mỗi yêu cầu giữ trạng thái chờ đến khi Meet cung cấp bằng chứng người đó
   đã tham gia. Người đến sau vẫn cần lượt xác nhận tiếp theo. Bấm nhiều lần
   không tạo thêm lượt duyệt đang chạy.
5. Esc, nút đóng hoặc bấm bên ngoài chỉ đóng hộp, không xóa yêu cầu. Box tồn
   tại phía trên Navigator; các màn hình khác dùng nút trên thanh công cụ có
   sẵn. Khi xem Câu hỏi hoặc preview, nút nằm trên thanh trên cùng.
6. Tạm rời Studio giữ phiên Meet và bộ lắng nghe yêu cầu. Kết thúc lớp hoặc
   đăng xuất qua Dashboard đóng phiên và xóa danh sách cũ.

Nếu không đọc được tên hoặc chưa xác nhận được kết quả, app giữ thông báo và
hiện **Kiểm tra Meet trong app**. Nút này mở cùng phiên WebView, không tạo phiên
đăng nhập khác hay mở tab trình duyệt ngoài. Các tài khoản trùng tên mà không có
thông tin phân biệt cần được kiểm tra ở đây.

## Giới hạn và kiểm thử

Danh sách người tham gia trong HocLuc chỉ là dữ liệu đọc từ Meet. Nếu panel Mọi người không mở hoặc trang đang tải lại, giao diện báo dữ liệu có thể chưa cập nhật; bridge không tự giành panel. Các thao tác mic, hạ tay và mời ra được thực hiện trực tiếp trong Google Meet bằng nút **Điều khiển trong Google Meet**. HocLuc không tự đổi trạng thái hoặc xóa học sinh trước khi Meet thay đổi. Chat chỉ xuất hiện trong lịch sử khi bridge đọc được tin nhắn từ Meet; click gửi chưa phải bằng chứng đã gửi thành công.

Bản dạy bình thường dùng thiết bị media thật (gồm camera ảo đã cài trên Windows). Thiết bị media giả chỉ bật khi build kiểm thử với `--dart-define=HOC_LUC_TEST_MEDIA=true`; không dùng cấu hình đó để nghiệm thu mic/camera thật. Sau khi đổi cờ phải khởi động lại toàn bộ app/native WebView, không chỉ hot restart.

Đây là cầu nối DOM của WebView2, không phải API duyệt người tham gia của Google.
Mỗi lệnh gắn với phòng, tài liệu, yêu cầu và lượt xử lý cụ thể. Một lần click
hoặc một dòng biến mất không được coi là duyệt thành công. Bộ thử DOM cục bộ
không chứng minh tương thích với DOM Google Meet đang triển khai thực tế.

Kiểm thử tự động:

```text
cd frontend
flutter test
dart analyze lib test
node test/meet_admission_bridge.browser.cjs
flutter build windows --no-pub
```

Bộ thử Node cần Playwright và Microsoft Edge. Các trang mô phỏng được phục vụ
cục bộ; không gửi yêu cầu vào phòng Google thật.

Kiểm thử nghiệm thu cần hai tài khoản thật:

- Giáo viên kết nối Meet trong app bằng tài khoản chủ phòng; học sinh xin vào
  cùng phòng từ trình duyệt riêng. Kiểm tra chấm đỏ và tên tài khoản.
- Giữ nguyên phiên lớp, chuyển Bảng/Câu hỏi, mở preview/dialog, kho đề hoặc
  tạm quay về Dashboard. Yêu cầu phải tiếp tục xuất hiện và duyệt được.
- Bấm Xác nhận tất cả. Kiểm tra từ phía học sinh rằng họ thực sự vào được;
  yêu cầu mới đến trong lượt này vẫn chờ giáo viên xác nhận tiếp.
- Thử mất quyền chủ phòng, thay phòng, tải lại Meet, tài khoản trùng tên và
  gián đoạn kết nối. Không hiển thị thành công khi chưa có xác nhận từ Meet.

Chưa thể coi nghiệm thu Google Meet thật là hoàn thành chỉ bằng build Windows
hoặc bộ thử mô phỏng.
