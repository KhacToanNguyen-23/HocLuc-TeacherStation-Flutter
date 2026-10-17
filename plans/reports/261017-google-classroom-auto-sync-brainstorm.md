# Brainstorm: Tự đồng bộ Google Classroom

**Date:** 2026-10-17

## Ideas Explored

- Đồng bộ một lần sau khi HocLucStation tạo lớp, để người dùng không cần bấm nút Đồng bộ ngay sau thao tác này.
- Khi lớp chưa được Google kích hoạt, báo rõ cần chấp nhận lớp trong Classroom; tự kiểm tra lại khi HocLucStation được đưa về foreground sau đó.
- Tự làm mới mỗi lần mở trang quản lý lớp là một cách tổng quát hơn, nhưng không bám sát thao tác tạo lớp bằng hai trigger đã chọn.
- Đồng bộ nền định kỳ có thể tự phát hiện thay đổi muộn, nhưng tạo thêm yêu cầu về polling, quota và cách biểu thị hoạt động nền; chưa cần cho luồng này.
- Chạy đồng bộ sau mọi thao tác như thêm email hoặc bắt đầu buổi dạy có thể mở rộng về sau; hiện tập trung vào tạo và kích hoạt lớp.

## User's Direction

Ưu tiên tự đồng bộ sau khi tạo lớp. Nếu lớp đang chờ Google kích hoạt, đồng bộ một lần và báo người dùng cần chấp nhận lớp. Khi người dùng quay lại HocLucStation sau khi chấp nhận, app tự kiểm tra lại để không cần bấm Đồng bộ lần nữa.

Người dùng muốn kết quả kiểm tra được thông báo ngay trong HocLucStation. Đề xuất dùng lại đúng nghiệp vụ hiện tại của nút Đồng bộ, theo nội dung giao diện là đồng bộ thành viên.

Khi lập plan, kiểm tra code cho thấy backend đã đồng bộ thành viên trong luồng tạo nếu lớp được Google trả về ở trạng thái `ACTIVE`. Vì vậy không gửi thêm yêu cầu đồng bộ sau khi tạo; tự kiểm tra lại chỉ cần thiết cho lớp còn `PROVISIONED` khi app quay lại foreground. Người dùng chọn kiểm tra ở mỗi lần app resume khi lớp còn pending, giữ trạng thái trong phiên màn hình hiện tại và hiển thị kết quả bằng banner trong thẻ lớp.

## Open Questions

- Không còn câu hỏi chặn plan. Flutter `AppLifecycleState.resumed` là tín hiệu app vào foreground/có focus; Google Classroom `courseState == ACTIVE` là trạng thái đã kích hoạt, còn `PROVISIONED` là đã tạo nhưng chưa kích hoạt.

## Risks

- Google có thể chưa cập nhật trạng thái lớp ngay khi người dùng quay lại app; cần thông báo kết quả chưa sẵn sàng mà không tạo vòng gọi lặp.
- Sự kiện app resume/focus có thể phát nhiều lần; đồng bộ trùng có thể gây gọi API dư thừa.
- Lỗi quyền hoặc API bị từ chối cần được trình bày tách biệt với trạng thái chờ kích hoạt, để người dùng biết cách xử lý.
