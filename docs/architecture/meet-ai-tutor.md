# Trợ giảng AI trong Google Meet — MVP

## Sử dụng

Trong Studio, mở **Google → Cài đặt → Trợ giảng AI**. Nhập Base URL của API **tương thích Chat Completions**, tên model và API key. Base URL là gốc API, ví dụ `https://provider.example/v1`; không thêm `/chat/completions`. HTTP chỉ được chấp nhận cho địa chỉ loopback `127.0.0.1` hoặc `::1`. API local không yêu cầu key có thể để trống.

Chọn **Kiểm tra kết nối → Áp dụng**. Kiểm tra gọi một completion nhỏ thực sự, có thể phát sinh phí tại nhà cung cấp. Key chỉ nằm trong bộ nhớ phiên, không ghi vào preferences, lesson JSON hay log; đóng ứng dụng cần nhập lại. Đổi URL/model/key sẽ tạm dừng trợ giảng, cần kiểm tra và áp dụng lại. Không tự chuyển nhà cung cấp nếu API lỗi.

Vào phòng Meet trong WebView hiện tại, mở chat và chờ lịch sử tải xong. Bật **tự trả lời**. Nếu hệ thống vừa mở panel chat, bật lại sau khi chat sẵn sàng. Bước này lấy mốc lịch sử; chỉ các tin mới có nguồn từ tài liệu Meet hiện tại mới được xét. Giữ chat mở; đóng hoặc thay panel có thể làm mất trạng thái quan sát và cần bật lại.

Mở PDF có lớp văn bản hoặc nội dung bảng có sticker/chalk text. Trợ giảng lấy trang đang trình bày và các đoạn PDF liên quan, không lấy ghi chú riêng, nháp, đáp án Smart Pen hoặc bản đồ phân tích plugin. Bảng ở trang khác không được gửi. PDF chalk bị loại vì dữ liệu hiện tại chưa gắn annotation với đúng tài liệu. Nét viết tay thuần hình học, hình vẽ, PDF quét và lời nói chưa được nhận dạng. PPTX cần xuất/mở PDF trước.

## Hành vi trả lời

Từ 2026-10-26, **cả câu trả lời có nguồn và câu trả lời dự kiến đều tự gửi, không qua duyệt thủ công**:

- `answered` / `high`: model chọn câu nguyên văn từ nguồn, backend xác minh ID và câu trích đầy đủ; frontend xác minh lại trước khi gửi.
- `tentative` / `low`: model được diễn giải/suy luận từ ngữ cảnh hoặc kiến thức chung. Mọi tin đều được hệ thống thêm **“Chưa chắc chắn — câu trả lời dự kiến.”**, không phụ thuộc model có tự ghi cảnh báo hay không. Nếu không có trích dẫn, tin ghi **“Chưa có nguồn bài học xác nhận.”**. Câu hỏi không có văn bản bài học vẫn có thể được trả lời theo nhánh này; AI không được giả vờ đã đọc hình, nét viết tay hoặc nghe lời giảng.

`high`/`low` là phân loại do model trả về cùng các ràng buộc hệ thống, **không phải xác suất đúng đã hiệu chuẩn**. Nếu có trích dẫn ở bất kỳ nhánh nào, ID và câu trích vẫn phải hợp lệ; không nới lỏng kiểm tra trích dẫn giả. Câu trích cần tối thiểu 8 ký tự và dấu kết câu. Tin gửi có tiền tố `[Trợ giảng AI]`, tên người hỏi ở dạng văn bản và nhãn trang nguồn nếu có; không phải @mention có định danh của Google.

Kiểm tra trích dẫn chỉ xác minh văn bản có trong nguồn. Nó **không chứng minh** câu trích trả lời đúng câu hỏi hoặc tài liệu vốn đúng. Chưa có kết quả độ chính xác ngữ nghĩa trên bộ câu hỏi độc lập; cần đánh giá trước khi sử dụng rộng rãi.

Confidence thấp không đưa vào hàng chờ giáo viên: câu trả lời dự kiến hợp lệ được tự gửi. API lỗi, kết quả rỗng/không hợp lệ, trích dẫn giả hoặc Meet chưa xác nhận gửi → **Nhật ký sự cố** để theo dõi; không có nút chấp nhận/duyệt để tiếp tục gửi. Hệ thống không tự thử gửi lại tin chưa xác nhận vì tin có thể đã xuất hiện trên Meet.

Tạm dừng, đổi phòng, thay API hoặc thay nội dung sẽ vô hiệu hóa công việc cũ. Một tin đã được Meet nhận không thể thu hồi bằng nút tạm dừng. Gửi được thực hiện bằng DOM automation, không phải API chat chính thức; chỉ ghi nhận thành công khi quan sát được tin tự gửi mới trong đúng document/phòng. Nếu DOM không chứng minh được danh tính tin tự gửi thì xử lý là chưa xác nhận.

## Giới hạn tải

- Một worker tuần tự, hàng đợi tối đa 20 câu; tối thiểu 5 giây giữa các lần thử gửi.
- Bỏ tin của giáo viên/AI, lọc câu hỏi bằng quy tắc, gộp câu trùng chính xác sau chuẩn hóa trong cùng revision. Chưa gộp ngữ nghĩa hoặc cache câu trả lời lâu dài.
- Một PDF đang hoạt động, tối đa 25 MiB / 200 trang; giữ tối đa 2 triệu ký tự, 10.000 ký tự mỗi trang. PDF parsing chạy qua `compute` ngoài UI isolate trên desktop; trên web `compute` vẫn dùng event loop hiện tại. Chia đoạn theo câu; bỏ câu quá 3.000 ký tự để tránh làm mất phủ định khi cắt giữa câu.
- Tìm kiếm từ khóa, tối đa 6 đoạn × 3.000 ký tự cho mỗi yêu cầu. Không vector database, embedding service hoặc pipeline âm thanh mới.
- Backend giới hạn request 64 KiB, provider response 32 KiB, deadline 12 giây và không theo redirect. Tối đa 1.200 ký tự câu trả lời.

## API và ranh giới

`POST /api/tutor/test` nhận `{config:{baseUrl,apiKey,model}}`; chỉ trả `success:true` khi completion thật trả `OK`.

`POST /api/tutor/answer` nhận `{config,question,currentPage,sources:[{id,label,text}]}`; trả `{status:"answered"|"tentative"|"review",confidence:"high"|"low"|"unavailable",answer,sources:[{id,quote}],reason}`. `review` chỉ biểu thị không có phản hồi hợp lệ/sự cố, không phải yêu cầu phê duyệt. Provider trả `{answer,sources,confidence:"high"|"low"}`; payload cũ chỉ có `{answer,sources}` được chấp nhận qua kiểm tra trích nguyên văn, không tự mở nhánh low. Config được chụp riêng cho mỗi request, không ghi lại phía backend. Dùng companion token hiện có, thêm kiểm tra socket/Host/Origin riêng cho tutor. Mọi lỗi được lược bỏ thông tin nhạy cảm; không trả body lỗi nhà cung cấp.

Frontend nằm trong `features/meet_tutor`, backend trong `modules/tutor`. `StudioInspectorPanel` sở hữu vòng đời controller và collector, giữ chúng khi đổi tab, hủy listener và công việc khi đóng inspector. Không thay đổi hệ plugin.

## Phạm vi kiểm chứng

Test tự động dùng provider giả lập và DOM fixture; không gửi tin vào lớp thật. CI gate không thay thế nghiệm thu Windows WebView2 + tài khoản học sinh và API thật. Cần kiểm chứng: đọc tin mới, không trả lời lịch sử, thấy câu trả lời từ máy học sinh, dừng/đổi bài lúc đang xử lý, độ trễ/tải cùng Meet và độ chính xác trên câu hỏi giữ riêng.
