# API sinh giáo án — cấu hình cho dev/deployment

Yêu cầu hiện hành: chỉ AI sinh giáo án/storyboard chuyển sang API. PhoWhisper-small, VinAI Translate vi2en-v2 và Kokoro-82M tiếp tục là model local. Chia script thành cảnh thủ công cũng xử lý local. Không còn fallback Ollama trong luồng Soạn bài.

## Hợp đồng adapter

Adapter hiện hỗ trợ giao thức **OpenAI-compatible Chat Completions**, không tự nhận tương thích mọi API nhà cung cấp. Cần endpoint hỗ trợ `POST <baseUrl>/chat/completions`, Bearer authentication, `response_format: {type: json_object}`, `max_tokens`, `temperature` và response `choices[0].message.content` chứa JSON, `finish_reason: stop`. API native khác cần adapter riêng sau khi chọn provider.

Chưa chọn nhà cung cấp/model nên mặc định không có endpoint khả dụng và không tự gọi API. Lưu cài đặt chỉ kiểm định dạng/cấu hình, không xác nhận key hợp lệ hoặc model thực tồn tại.

## Cấu hình

1. Trên process backend, người vận hành đặt `HOCLUC_AUTHORING_API_KEY` và `HOCLUC_AUTHORING_ALLOWED_HOSTS` (danh sách hostname chính xác, phân cách dấu phẩy, không wildcard/scheme/path). Không gửi key trong chat, Flutter, job JSON, repository hay file mẫu chứa giá trị thật.
2. Trong HocLuc → Soạn bài → Cài đặt, nhập API base URL HTTPS và model ID. Hostname phải nằm trong danh sách server đã cho phép. Chỉ cổng HTTPS mặc định/443 được hỗ trợ; không nhận credentials, query hoặc fragment trong URL, không theo redirect.
3. Bấm sinh từ mô tả/transcript: app hiện nơi nhận, model và đúng nội dung sẽ gửi. Giáo viên có thể hủy. Backend kiểm lại destination/model khớp xác nhận và đóng băng chúng theo job; đổi cài đặt sau đó không âm thầm đổi nơi nhận của job cũ.
4. Nhận bản nháp và duyệt trong app. Thiếu model speech không chặn bước này; muốn chép lời/tạo giọng/dựng video vẫn cần thành phần local tương ứng.

API key được đọc từ môi trường server lúc gọi, không lấy từ frontend. Danh sách host là chính sách server, không thể thay từ UI. Với deployment thực, đặt thêm egress policy của hạ tầng; DNS check ở ứng dụng không thay thế kiểm soát mạng.

## Dữ liệu, lỗi và chi phí

Payload chỉ chứa system instruction/schema, đoạn `text` đã chọn, ngôn ngữ và tham số sinh. Không tự gửi toàn bộ bài, notes/đáp án riêng, file video/audio, đường dẫn hoặc tài sản. Nếu giáo viên tự dán nội dung riêng vào đoạn chọn thì nội dung đó nằm trong preview và sẽ được gửi sau xác nhận.

Giới hạn đầu vào 40.000 ký tự, response 2 MB; timeout hữu hạn, hủy ngừng chờ/gửi kết quả về app. Hủy không bảo đảm nhà cung cấp ngừng xử lý hoặc hoàn phí. Không retry tự động: yêu cầu authoring lỗi/hủy cần tạo yêu cầu mới và xác nhận lại. Nội dung lỗi/body nhà cung cấp không được sao chép thẳng ra UI/log job.

Output chỉ nhận các trường giáo án/cảnh đã định nghĩa; chặn asset/path/code do model tự chỉ định, ID trùng, template không hỗ trợ, nội dung quá dài và response chưa hoàn chỉnh. Kết quả luôn cần giáo viên duyệt, không tự publish.

## Ba model speech dành cho dev khác

Source code không kèm weights. Khi bộ model được phát hành qua repository model hoặc Release/artifact của project, dev tải về thư mục model và chọn **Thư mục ba model speech** trong app, hoặc nhập gói offline qua installer hiện hữu. Dùng [gói offline](preparation-offline-components.md) để kiểm manifest/version/size/SHA-256. Hiện chưa có URL phát hành weights được cấu hình và chưa thực hiện upload weights.

Không cần Ollama/Qwen. API key và model speech là hai cấu hình độc lập: authoring dùng API trên backend; speech dùng checkpoint theo cấu hình local. Bộ installer offline chưa tự tải weights từ URL repo.

## Kiểm chứng adapter

Backend toàn bộ **229 tests đạt**, gồm **14 adapter tests và 5 job integration tests**; Flutter Soạn bài/kiến trúc **57 tests đạt**, gồm bấm nút thật và kiểm payload sau xác nhận; Python **46 tests đạt**, analyzer sạch. Các test API dùng transport giả lập, không gửi key/nội dung đến nhà cung cấp và không phát sinh phí. Chưa có bằng chứng kết nối, model quality hoặc thành công trên tài khoản API thật vì nhà cung cấp chưa được chọn.

Web release và Windows release đều build thành công từ mã cuối (164,4 giây và 97 giây). Các cảnh báo font Cupertino/CMake hiện hữu không chặn build; đây không phải nghiệm thu API thật.
