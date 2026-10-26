# Trợ giảng AI trong Google Meet — MVP

## Sử dụng

Cấu hình API của trợ giảng hoàn toàn bằng file `.env` ở gốc dự án (cùng cấp `backend/`, `frontend/`):

```dotenv
HOCLUC_TUTOR_BASE_URL=https://provider.example/v1
HOCLUC_TUTOR_MODEL=your-model
HOCLUC_TUTOR_API_KEY=your-api-key
# Optional: 5..90 seconds; default 45
HOCLUC_TUTOR_REQUEST_TIMEOUT_SECONDS=45
# Optional: only when the provider/model supports reasoning_effort
HOCLUC_TUTOR_REASONING_EFFORT=
# Optional: only for providers supporting response_format json_schema
HOCLUC_TUTOR_STRUCTURED_OUTPUT=false
```

Base URL là gốc API tương thích Chat Completions, không thêm `/chat/completions`. API local không cần khóa có thể để `HOCLUC_TUTOR_API_KEY=`. HTTPS được chấp nhận; HTTP chỉ cho literal loopback `127.0.0.1` hoặc `::1`. Backend dùng bộ đọc `.env` hiện có: tìm từ thư mục khởi chạy lên gốc repo, chọn file gần nhất; biến môi trường của tiến trình ưu tiên hơn `.env`. Khởi động lại backend sau khi sửa file. `.env` đã được Git ignore; không commit file thật hoặc ghi khóa vào log.

Không có ô nhập URL/model/key, nút kiểm tra/áp dụng/nạp `.env` hoặc thông tin nhà cung cấp trong giao diện. Khóa chỉ ở backend, không trả về Flutter và không đóng gói vào assets. Phiên Studio chọn `config: {"useEnvironment": true}` để backend dùng toàn bộ bộ cấu hình môi trường; không trộn URL từ ứng dụng với khóa môi trường.

Vào phòng Meet trong ứng dụng rồi bật biểu tượng robot kèm công tắc trên header, ngay trước nút học sinh. AI tự mở và chuẩn bị chat trong trang Meet chạy nền; giáo viên không phải mở chat hoặc giữ Google panel hiển thị. Vòng chờ là đang lấy mốc lịch sử (nhấn lại để hủy); xanh đặc là đã bật và nhận câu hỏi mới; xám là tắt. Nút chỉ có biểu tượng; tooltip giải thích khi rê chuột. Header và bảng trạng thái trợ giảng dùng chung phiên AI, độc lập với việc đóng/mở panel. Tắt sẽ ngừng nhận câu hỏi mới và hủy xử lý/gửi đang chờ; tin đã gửi không được thu hồi. Tạm rời lớp cũng tắt AI; màn hình soạn bài không nhận quyền điều khiển AI của lớp.

AI không tự bật khi mở Studio. Thiếu/sai cấu hình môi trường hoặc provider lỗi không làm AI đang bật im lặng: nhánh lỗi có thông báo cố định cho học sinh theo cơ chế gửi chat hiện có. Chỉ tin mới từ Meet sau mốc bật thành công được xử lý. Mỗi lần bật có một observation lease riêng: tin lịch sử, tin đến muộn từ lần bật trước hoặc từ phòng/tài liệu cũ đều không được đưa cho AI. Đóng Google panel để giảng/share whiteboard không tắt service hay controller Meet; agent tiếp tục đọc và gửi qua chính phiên Meet đó.

Mở PDF có lớp văn bản hoặc nội dung bảng có sticker/chalk text. Trợ giảng lấy trang đang trình bày và các đoạn PDF liên quan, không lấy ghi chú riêng, nháp, đáp án Smart Pen hoặc bản đồ phân tích plugin. Bảng ở trang khác không được gửi. PDF chalk bị loại vì dữ liệu hiện tại chưa gắn annotation với đúng tài liệu. Nét viết tay thuần hình học, hình vẽ, PDF quét và lời nói chưa được nhận dạng. PPTX cần xuất/mở PDF trước.

## Hành vi trả lời

Từ 2026-10-26, **mọi tin nhắn mới, không rỗng của học sinh được nhận khi trợ giảng đang bật đều có nhánh phản hồi trên chat**, không qua duyệt thủ công. Không còn bộ lọc từ khóa câu hỏi hoặc gộp hai tin riêng chỉ vì cùng nội dung. Tin đã thấy, lịch sử trước lúc bật, tin của giáo viên và tin AI vẫn bị bỏ qua để tránh vòng lặp.

- Ngoài môn/chủ đề bài giảng: backend yêu cầu model phân loại `scope` từ `lessonSubject` và nguồn bài học. Khi `out_of_scope`, gửi câu cố định **“Không nằm trong nội dung bài học”**; không chuyển lời khuyên ngoài chủ đề của model. Phân loại này phụ thuộc chất lượng model, chưa có đánh giá độ chính xác ngữ nghĩa trên lớp thật.

- `answered` / `high`: model chọn câu nguyên văn từ nguồn, backend xác minh ID và câu trích đầy đủ; frontend xác minh lại trước khi gửi.
- `tentative` / `low`: model được diễn giải/suy luận từ ngữ cảnh hoặc kiến thức chung. Mọi tin đều được hệ thống thêm **“Chưa chắc chắn — câu trả lời dự kiến.”**, không phụ thuộc model có tự ghi cảnh báo hay không. Nếu không có trích dẫn, tin ghi **“Chưa có nguồn bài học xác nhận.”**. Câu hỏi không có văn bản bài học vẫn có thể được trả lời theo nhánh này; AI không được giả vờ đã đọc hình, nét viết tay hoặc nghe lời giảng.

`high`/`low` là phân loại do model trả về cùng các ràng buộc hệ thống, **không phải xác suất đúng đã hiệu chuẩn**. Nếu có trích dẫn ở bất kỳ nhánh nào, ID và câu trích vẫn phải hợp lệ; không nới lỏng kiểm tra trích dẫn giả. Câu trích cần tối thiểu 8 ký tự và dấu kết câu. Tin gửi có tiền tố `[Trợ giảng AI]`, tên người hỏi ở dạng văn bản và nhãn trang nguồn nếu có; không phải @mention có định danh của Google.

Kiểm tra trích dẫn chỉ xác minh văn bản có trong nguồn. Nó **không chứng minh** câu trích trả lời đúng câu hỏi hoặc tài liệu vốn đúng. Chưa có kết quả độ chính xác ngữ nghĩa trên bộ câu hỏi độc lập; cần đánh giá trước khi sử dụng rộng rãi.

Confidence thấp không đưa vào hàng chờ giáo viên: câu trả lời dự kiến hợp lệ được tự gửi. API lỗi/timeout → gửi thông báo hệ thống AI đang gặp lỗi; kết quả rỗng/không hợp lệ/trích dẫn giả → gửi thông báo chưa có câu trả lời hợp lệ; ngữ cảnh đổi trước khi gửi → gửi thông báo bài giảng vừa thay đổi. Câu quá dài hoặc quá tải cũng có thông báo cố định. Nội dung lỗi kỹ thuật, secret và câu trả lời bị loại không được đưa vào chat.

Chỉ lỗi vận chuyển/Meet chưa xác nhận gửi mới cần **Nhật ký sự cố**; không có nút phê duyệt. Bridge phân biệt `notDispatched` với `unconfirmed`: chỉ trường hợp chắc chắn chưa dispatch và ngữ cảnh vừa đổi mới được thay bằng thông báo, không retry mù khi có khả năng tin đã được gửi. Vì thế “luôn phản hồi” là chính sách xử lý khi trợ giảng bật và Meet gửi được, không phải bảo đảm giao tin khi mất mạng, đóng phòng, ô chat bị khóa/đang có bản nháp của giáo viên hoặc đã tạm dừng.

Tạm dừng, đổi phòng, thay API hoặc thay nội dung sẽ vô hiệu hóa công việc cũ. Một tin đã được Meet nhận không thể thu hồi bằng nút tạm dừng. Gửi được thực hiện bằng DOM automation, không phải API chat chính thức; chỉ ghi nhận thành công khi quan sát được tin tự gửi mới trong đúng document/phòng. Nếu DOM không chứng minh được danh tính tin tự gửi thì xử lý là chưa xác nhận.

## Giới hạn tải

- Một worker tuần tự, tối đa 20 yêu cầu AI đang chờ; tối thiểu 5 giây giữa các lần thử gửi. Quá tải và câu quá dài dùng thông báo chung FIFO, gộp tối đa một thông báo chờ cho mỗi loại để tránh hàng đợi vô hạn và không chen mãi trước các câu cũ.
- Bỏ tin giáo viên/AI và ID đã xử lý; không bỏ một tin mới chỉ vì trùng nội dung với câu trước. Không có cache câu trả lời lâu dài.
- Một PDF đang hoạt động, tối đa 25 MiB / 200 trang; giữ tối đa 2 triệu ký tự, 10.000 ký tự mỗi trang. PDF parsing chạy qua `compute` ngoài UI isolate trên desktop; trên web `compute` vẫn dùng event loop hiện tại. Chia đoạn theo câu; bỏ câu quá 3.000 ký tự để tránh làm mất phủ định khi cắt giữa câu.
- Tìm kiếm từ khóa, tối đa 6 đoạn × 3.000 ký tự cho mỗi yêu cầu. Không vector database, embedding service hoặc pipeline âm thanh mới.
- Backend giới hạn request 64 KiB, provider response 32 KiB, deadline 12 giây và không theo redirect. Tối đa 1.200 ký tự câu trả lời.

## API và ranh giới

`POST /api/tutor/test` nhận `{config:{baseUrl,apiKey,model}}`; chỉ trả `success:true` khi completion thật trả `OK`.

`POST /api/tutor/answer` nhận `{config,question,currentPage,lessonSubject,sources:[{id,label,text}]}` (`lessonSubject` tùy chọn để tương thích client cũ); trả `{status:"answered"|"tentative"|"out_of_scope"|"review",confidence:"high"|"low"|"unavailable",answer,sources:[{id,quote}],reason}`. `review` được frontend đổi thành thông báo chat an toàn, không phải yêu cầu phê duyệt. Provider thêm `scope:"in_scope"|"out_of_scope"|"unknown"` vào `{answer,sources,confidence}`. Config được chụp riêng cho mỗi request, không ghi lại phía backend. Dùng companion token hiện có, kiểm tra socket/Host/Origin riêng cho tutor; không trả body lỗi nhà cung cấp.

Frontend nằm trong `features/meet_tutor`, backend trong `modules/tutor`. `StudioInspectorPanel` sở hữu vòng đời controller và collector, giữ chúng khi đổi tab, hủy listener và công việc khi đóng inspector. Không thay đổi hệ plugin.

## Phạm vi kiểm chứng

Test tự động dùng provider giả lập và DOM fixture; không gửi tin vào lớp thật. CI gate không thay thế nghiệm thu Windows WebView2 + tài khoản học sinh và API thật. Cần kiểm chứng: đọc tin mới, không trả lời lịch sử, thấy câu trả lời từ máy học sinh, dừng/đổi bài lúc đang xử lý, độ trễ/tải cùng Meet và độ chính xác trên câu hỏi giữ riêng.

### Gemini manual-test configuration

For newly provisioned Gemini accounts tested on 2026-10-26, `gemini-2.5-flash-lite` returned 404 (no longer available to new users). Use an available model, for example `gemini-3.5-flash-lite`, with `HOCLUC_TUTOR_REASONING_EFFORT=minimal` and `HOCLUC_TUTOR_STRUCTURED_OUTPUT=true`. Live probing returned OK, but this alone does not verify Meet delivery or lesson-answer quality. Backend request timeout defaults to 45 seconds, bounded to 5..90 via `.env`; the client transport waits up to 100 seconds. A reasoning-enabled connection probe uses a 512-token budget so it can complete after thinking. No provider/model controls are shown in the teacher UI.

### Bật AI và đọc ngầm, không chiếm màn hình bảng

Handshake tự mở chat, đợi lịch sử ổn định và thử lại có giới hạn trong cùng một lần bật. Khi AI bật, vòng quét People không được giành panel khỏi chat. Nếu DOM input chat remount, agent tự mở lại và giữ các tin mới chờ đến khi quan sát sẵn sàng; không phát lại ID cũ. Tắt AI hủy cả đọc ngầm và chuẩn bị đang chờ; các lệnh begin/end cũ được chặn bằng lease và hạn thực thi. Nếu chưa vào được Meet hoặc không thể chuẩn bị chat, toggle không giả vờ bật và hiển thị thông báo ngay trên màn hình; không yêu cầu giáo viên mở chat thủ công.

Đây vẫn là DOM automation trên WebView2, không phải Google Meet Chat API. Native controller, page, subscription và bridge thuộc service, sống độc lập với widget panel. Không tạo controller hoặc phiên đăng nhập thứ hai; không gắn một WebView nền kích thước nhỏ cạnh một WebView đang hiển thị. Kiểm tra trên Meet thật vẫn cần xác nhận ngoài các test DOM và service giả lập.
