# Soạn bài — triển khai và nghiệm thu

Cập nhật: 2026-10-20. Tài liệu mô tả code hiện có, không thay thế nghiệm thu Google/Meet trên tài khoản thật.

**Điều chỉnh authoring:** dùng adapter API bên thứ ba cấu hình được, bỏ phụ thuộc Ollama trong Soạn bài. Nhà cung cấp chưa chọn nên chưa gọi API thật; ba model STT/dịch/TTS vẫn local. Hướng dẫn dev/deployment: [API sinh giáo án](architecture/preparation-authoring-api.md).

## Luồng sử dụng trong HocLuc

**Bản thiết kế lại 2026-10-20:** workspace chính là dàn ý + nội dung phần đang soạn + Hỗ trợ giáo viên; không còn năm tab ngang hàng. Thêm nội dung theo loại đầu vào, Chuẩn bị bảng trình chiếu, Lời nhắc theo trang và Tài liệu đã tạo là hành động trong workspace. Xem [hướng dẫn test bản mới](testing/lesson-preparation-redesign-uat.md). Những mô tả tab bên dưới được giữ như lịch sử chức năng, không phải tên điều hướng mới.

Dashboard có hai nút cạnh nhau: **Kế hoạch giảng dạy** mở Studio để chỉnh bảng kế hoạch; **Soạn bài** mở workspace soạn nội dung và học liệu. Hai mục dùng chung thư viện và ID bài hiện có, bộ lọc môn được giữ riêng từng mục.

Bộ kiểm thử thủ công: [60 happy case và 4 luồng đầu-cuối](testing/lesson-preparation-happy-cases.md), kèm [CSV](testing/lesson-preparation-happy-cases.csv). Trạng thái ban đầu là Chưa chạy; các luồng AI/Google cần đủ cấu hình ghi trong tài liệu.

1. Mở bài trong danh sách Soạn bài trên dashboard. Workspace gồm Nội dung, Bảng & tài liệu và Video; bài cũ tiếp tục dùng cùng `planningId`.
2. Thêm video/audio hoặc ghi nguồn micro/màn hình. Chọn đoạn và chạy Chép lời; sửa transcript cùng mốc thời gian trước khi tạo nội dung.
3. Dán script để chia thành phần/cảnh local, hoặc dùng prompt/transcript với API soạn bài đã cấu hình để đề xuất giáo án/storyboard. App cho xem chính xác đoạn sẽ gửi và xác nhận từng yêu cầu; kết quả phải được giáo viên duyệt trước khi thay nội dung bài.
4. Sửa nội dung, mục tiêu, thời lượng, ghi chú riêng và các cảnh. Có dịch Việt–Anh, nghe giọng Anh, chọn voice và dựng MP4 theo template chữ/sơ đồ/hình.
5. Xem trước, tải học liệu hoặc chọn Xuất/Đăng. Chỉ file học sinh được xác nhận mới vào gói đăng Classroom; ghi chú riêng không thuộc projection xuất bản.
6. Chọn Dạy để chuyển nội dung đã soạn thành trang Studio. Ghi chú riêng đi cùng trang; app có cửa sổ Audience riêng chỉ hiển thị nội dung trình chiếu.

Công cụ bổ sung trong bài: lịch sử phiên bản/khôi phục thành bản mới, nhân bản, thư viện đoạn nội dung cá nhân, glossary phát âm, checklist và phản tư. Các mục này không tạo dashboard riêng.

## Bốn chức năng bổ sung trong menu Soạn bài

- **Chèn câu hỏi đã duyệt:** tìm trong kho đã duyệt, chèn toàn bộ nhóm dùng chung ngữ cảnh cùng hình câu hỏi. Đáp án/lời giải và hình riêng nằm trong nội dung giáo viên; bản học sinh và bảng trình chiếu chỉ nhận phần công khai. Máy chủ kiểm tra lại trạng thái duyệt khi chèn, lưu snapshot nguồn và hoàn tác dữ liệu/file nếu chèn lỗi.
- **Biến thể bài theo lớp:** chọn lớp nội bộ hoặc lớp Google của giáo viên, đặt tên và ghi hướng điều chỉnh riêng. Bản mới giữ nguồn bài/revision/lớp đích, có tài sản độc lập; sửa biến thể không sửa bài gốc. PDF/video sao chép được đánh dấu cần tạo lại. Khi Dạy, app ưu tiên lớp đã gắn và yêu cầu xác nhận nếu đổi lớp.
- **Mẫu trường/khoa & preview PDF:** khai báo trường, khoa và ánh xạ các trường nội dung theo thứ tự xuất; hỗ trợ trường tùy chỉnh và trường riêng giáo viên. Lưu/tải/cập nhật/xóa mẫu cá nhân theo tài khoản. Preview sử dụng PDF do bộ xuất thật tạo ra; mẫu do giáo viên cấu hình, không phải mẫu chính thức đã được trường phê duyệt.
- **Tạo PDF giáo viên (riêng tư):** PDF có nhãn riêng trên mỗi trang, gồm notes/đáp án và hình lời giải. PDF học sinh loại các trường này. Bản giáo viên bị loại khỏi lựa chọn đăng Classroom và bị máy chủ chặn xuất bản, kể cả khi gửi yêu cầu trực tiếp.

Các thao tác nằm trong workspace hiện hữu. Cần lưu bài trước khi tạo biến thể, xuất hoặc chuyển sang Dạy.

## Hoàn thiện các mục còn lại trong workspace

- **Bằng chứng nguồn:** phần/cảnh có thể gắn nguồn và revision, với mốc bắt đầu/kết thúc cho audio/video. App kiểm thời lượng thật bằng FFprobe trước khi gắn; bấm tham chiếu để mở đúng mốc. Nội dung AI có nhãn riêng và chưa được coi là có nguồn chỉ vì model đưa ra trích dẫn. Script thủ công không bị gắn nhãn AI. Tham chiếu là metadata giáo viên, không đưa vào projection học sinh.
- **Khung hình video:** tại nguồn video, dùng nút trích ảnh, nhập mốc để tạo ảnh minh họa thành nguồn của bài. FFprobe cần nằm cạnh FFmpeg đã chọn trong cài đặt. App kiểm quyền sở hữu, thời lượng và giới hạn xử lý, không nhận đường dẫn hay URL tùy ý.
- **Khóa cảnh:** khóa nội dung đã duyệt; muốn sửa/xóa phải mở khóa và lưu trước. Kết quả dịch cũ không được ghi đè bản mới; lệnh dịch cảnh sử dụng đúng đầu vào tiếng Việt.
- **Tái tạo có chọn lọc:** đổi glossary chỉ làm mất hiệu lực lời đọc/caption của cảnh có lời đọc thực sự thay đổi. Cache theo bài tái sử dụng TTS và cảnh video không đổi giữa các job, kiểm SHA-256 và giới hạn 512 MB. Đổi voice/model hoặc nội dung ảnh/lời đọc tương ứng tạo cache key mới; cache không phải artifact được phép đăng.
- **Phụ đề song ngữ:** chọn tiếng Anh/song ngữ, nhập và duyệt bản dịch thứ hai theo cue, bật/tắt xuất phụ đề từng cảnh. Có preview theo chiều rộng điện thoại và cảnh báo quá bốn dòng. SRT giữ mốc và văn bản đã duyệt; preview MP4 nạp SRT cùng job để bật/tắt CC. Đây là track phụ đề, không phải chữ đã đốt vào pixel video; bản dịch thứ hai do giáo viên nhập/duyệt, không hứa dịch tự động Anh→Việt.
- **Nhận xét thành bản sửa:** tạo bản nháp độc lập từ nhận xét, mang theo việc cần sửa, giữ bài gốc. Nếu bước đặt tên/lưu checklist lỗi sau nhân bản, bản sao độc lập vẫn được giữ, app báo lỗi.
- **Thư viện phần bài:** chèn qua máy chủ với nguồn/revision, sao chép và ánh xạ tài sản/tham chiếu/nhóm câu hỏi, bảo toàn nội dung riêng. Nếu bài nguồn đã thay đổi thì yêu cầu lưu lại phần vào thư viện, không âm thầm lấy bản khác. Thư viện cũ có tài sản cần lưu lại một lần từ bài nguồn. Chèn lỗi hoàn tác dữ liệu/file.
- **Khôi phục bản thu:** journal giữ bản thu chưa lưu qua restart. Mở bài để Khôi phục và lưu hoặc Bỏ bản ghi; lỗi remux giữ file gốc để thử lại. Video ghi mới dùng fragmented MP4 để có thể cứu đoạn đã ghi; điều này không bảo đảm cứu mọi file hỏng hoặc đoạn chưa flush ra đĩa. Backend chỉ dừng tiến trình cũ khi xác minh PID/start time/command/output cùng khớp. Chưa có pause/resume và chưa nghiệm thu thu màn hình/micro thật qua crash Windows.

## Bổ sung theo plan ngày 2026-10-20

- **Hoạt động và mục tiêu:** mỗi phần có danh sách việc giáo viên/học sinh làm, số phút, liên kết mục tiêu; kiểm tra thời lượng hoạt động/phần/toàn bài. Các trường này tùy chọn.
- **Thẻ hỗ trợ:** ví dụ, hiểu sai và gợi ý có nội dung riêng giáo viên. Chỉ `publicText` đã được duyệt đúng nội dung hiện tại mới vào PDF/bảng/bản học sinh; sửa thẻ phải duyệt lại.
- **Phụ đề:** sửa cue và mốc tương đối theo cảnh, kiểm mốc hữu hạn/tăng dần/không chồng lấn, lưu duyệt theo narration. Renderer kiểm lại với audio thật, giữ văn bản/mốc giáo viên đã duyệt và xuất SRT. Sửa narration/voice/glossary làm mất hiệu lực duyệt tương ứng. Có đồng hồ diễn tập cảnh, không phải đo căn chỉnh âm vị.
- **Nguồn:** chọn toàn bộ hoặc đoạn bắt đầu/kết thúc, preview từ mốc chọn; xóa nguồn/bản xuất chưa dùng ngay trong app. Nguồn dùng trong lịch sử/job/publication được giữ để khôi phục/đối soát. Upload kiểm chữ ký định dạng, script UTF-8 tối đa 1 MB; mỗi bài tối đa 100 nguồn, tổng file đăng ký 1 GB và kiểm dung lượng trống trước sao chép.
- **Ghi hình Windows:** chọn toàn màn hình hoặc cửa sổ theo handle hiện có, xác minh lại tiêu đề trước ghi, chọn microphone kèm theo. Cửa sổ cần giữ mở, không thu nhỏ; cần FFmpeg hỗ trợ `hwnd` theo [tài liệu FFmpeg](https://www.ffmpeg.org/ffmpeg-devices.html#gdigrab). Chưa kiểm capture thực trên mọi ứng dụng/cửa sổ. Đã có journal và khôi phục bản thu qua restart backend như mô tả bên trên; chưa có pause/resume.
- **Cài offline:** trong Thành phần local, chọn gói ZIP runtime/model/FFmpeg do đơn vị triển khai cung cấp; truyền theo luồng trên Windows, có tiến trình/hủy/lịch sử. Kiểm manifest/version/size/SHA-256 trước kích hoạt, giữ cấu hình cũ nếu lỗi. SHA-256 kiểm toàn vẹn, không xác thực nhà phát hành. Web dùng thành phần trên backend, không nhận gói nhiều GB qua BrowserClient. Xem [hợp đồng gói offline](architecture/preparation-offline-components.md).
- **Trước đăng:** lọc định dạng học sinh, chặn bản xuất cũ/chưa lưu/thiếu lớp/chưa xác nhận, hiện tiến độ từ journal, mở link kết quả Classroom và đối soát bằng request gốc.

## Dữ liệu và xử lý

- Dữ liệu soạn nằm trong `preparation` của bài hiện hữu, có revision và kiểm tra xung đột. API cũ không được ghi đè trực tiếp phần này.
- API `/api/preparation` dùng companion token và phiên đăng nhập giáo viên hiện có. Assets/jobs gắn với chủ sở hữu bài; không nhận đường dẫn file tùy ý từ browser.
- Sources lưu trên đĩa, upload tối đa 50 MB. Ghi nguồn tối đa 30 phút. Job nặng chạy tuần tự; có tiến trình, hủy, thử lại và checkpoint chép lời.
- Worker Python chạy tách khỏi runtime giảng dạy trực tiếp; chỉ tải model cần dùng. STT tiếng Việt dùng PhoWhisper-small, dịch Việt→Anh dùng VinAI Translate vi2en-v2, TTS Anh dùng Kokoro-82M. Ba model speech không được coi là model soạn giáo án. Authoring chạy qua backend API bên thứ ba, không cần Ollama/Python/model speech để tạo bản nháp từ prompt.
- Video template 1280×720, 25 fps H.264/AAC, kèm phụ đề/timeline. Timestamp STT theo chunk, phụ đề theo ước lượng; giáo viên cần rà soát.
- Google upload dùng Drive resumable và Classroom courseWorkMaterials, xin thêm quyền khi đăng. Nhật ký theo request ID hỗ trợ đối soát khi mất phản hồi; không tự tạo lại material khi chưa biết kết quả trước.

## Quyền riêng tư khi dạy

Audience là cửa sổ/process riêng nhận ảnh bề mặt bài giảng; không nhận JSON ghi chú hoặc điều khiển giáo viên. Khi mở trình chọn chia sẻ, app chờ che ghi chú trước khi cho capture tiếp tục. Ghi chú chỉ hiện khi không chia sẻ hoặc nguồn chia sẻ được xác định là đúng cửa sổ Audience còn hoạt động; nguồn không xác định sẽ che ghi chú.

Việc kiểm tra nhãn cửa sổ phụ thuộc WebView/Chromium. Chưa có nghiệm thu qua máy học sinh/Meet thật; không coi kiểm thử script/widget là bằng chứng riêng tư đầu cuối.

## Bằng chứng và giới hạn nghiệm thu

- Đợt hoàn thiện tiếp: backend **210 tests, 0 failures/errors**, toàn Python **42 tests đạt** (một cảnh báo deprecation AnyIO). Toàn Flutter chạy tuần tự **446/446 đạt**, gồm 12 invariant; test plugin từng lỗi cũng đạt trong lần chạy này. Nhóm liên quan trước đó 57 tests đạt, widget gắn nguồn sau sửa race 3/3 đạt. Analyzer cuối `No issues found`. Các số liệu những đợt trước bên dưới được giữ làm lịch sử.
- Web release cuối build đạt (419,1 giây); Windows release cuối build đạt (150,6 giây), khởi chạy và giữ process sau 8 giây rồi dừng đúng process kiểm tra. Giữ các cảnh báo font Cupertino/CMake từ thành phần hiện hữu; build/startup không thay thế nghiệm thu tương tác và tài khoản thật.
- FFmpeg thật: nguồn sine WAV và test-pattern fragmented MP4 bị kill sau khoảng bốn giây đều remux và giải mã đạt sau sửa `flush_packets`; đây là dữ liệu giả lập, không phải nghiệm thu thiết bị capture thật. Video dùng đoạn giọng Kokoro đã có: ba cảnh/tổng 9 giây, SRT Anh–Việt, giải mã đạt; đổi hình/nội dung một cảnh chỉ encode lại một cảnh, hai cảnh còn lại dùng cache. Bằng chứng local bị ignore tại `tmp/preparation-recovery-smoke/result.json` và `tmp/preparation-video-cache-smoke/result.json`. Không suy ra chất lượng ngữ nghĩa hay căn chỉnh phụ đề từ smoke này.
- Đợt bốn chức năng: backend **192 tests, 0 failures/errors**; sau chỉnh ngắt dòng PDF, nhóm export/fixture PDF **10 tests đạt**. Nhóm Flutter Soạn bài/chọn lớp/kiến trúc **46 tests đạt**, gồm 12 invariant; analyzer `No issues found`. Full Flutter **433 đạt, 1 lỗi** ở test cài plugin mẫu `english_assistant_e2e_test.dart`; chạy riêng file này sau đó **4/4 đạt**. Chưa coi full suite là đạt ổn định. PDF mẫu học sinh/giáo viên đã render và kiểm hình (tiếng Việt, hình nhóm câu hỏi, notes/đáp án và nhãn riêng).
- Bản bốn chức năng đã build Web release (151,2 giây) và Windows release (95,8 giây); Windows khởi chạy và giữ process sau 8 giây, sau đó dừng đúng process smoke. Có cảnh báo font Cupertino và CMake plugin hiện hữu; chưa kiểm tương tác UI đầu cuối trên bản release.
- Worker: 28 tests passed ngày 2026-10-20; có một cảnh báo deprecation từ thư viện Starlette/AnyIO.
- Đợt bổ sung: toàn backend **178 tests, 0 failures/errors**, worker **34 tests passed**; full Flutter **427 tests passed**, sau các sửa cuối nhóm Soạn bài + kiến trúc **34 tests passed** (gồm 12 invariant). Analyzer `No issues found`; browser sharing 8/8 và validator 2 plugin đạt. Web và Windows release đã build lại từ mã cuối. Các con số cũ dưới đây là bằng chứng đợt trước.
- Full Flutter suite: 414 tests passed trước vòng sửa review cuối; sau review, nhóm liên quan 35 tests passed, gồm đủ 12 invariant kiến trúc. Analyzer không còn issue. Backend full suite có 156 tests, 0 failures/errors; nhóm preparation sau review có 16 tests passed. Script chia sẻ Meet có 8 tests passed.
- Windows release và web release đã build thành công; web build báo thiếu font Cupertino và Windows có cảnh báo CMake từ plugin hiện hữu. Khả năng build không thay thế nghiệm thu workflow hoặc Google/Meet thật.
- Bản Windows cuối đã được khởi chạy ẩn để kiểm tra startup: process còn hoạt động sau 8 giây, sau đó dừng đúng process vừa tạo; chưa xác nhận tương tác giao diện. Sau sửa template, nhóm Soạn bài 13 tests passed và analyzer không còn issue.
- Bằng chứng lịch sử trước khi đổi authoring sang API: đã chạy Ollama local và TTS Kokoro, dựng video thật 3 cảnh. Bản dựng dùng lại WAV Kokoro: 93,36 giây, 720p, giải mã toàn bộ thành công; chênh cuối audio/video 37,33 ms. Bằng chứng nằm trong thư mục runtime bị gitignore: `backend/ai-runtime/reports/preparation-smoke/long-video/final/`. Không dùng kết quả này để tuyên bố API mới đã được gọi/nghiệm thu.
- Đây là smoke test pipeline, chưa phải đánh giá chất lượng STT/dịch/TTS trên tập held-out hoặc video dài 10 phút.
- Chưa nghiệm thu đăng Classroom/Drive trên tài khoản Google thật, mở video bên học sinh hoặc ghi chú qua đầu nhận Meet thật.
- Chưa có sinh cảnh/nhân vật bằng dịch vụ AI, TTS tiếng Việt, pause/resume bản thu hoặc catalog tải/cài online có chữ ký nhà phát hành. Installer hiện dùng gói offline được cung cấp và không cài dịch vụ Ollama/model authoring mới qua mạng.
- Không đưa model weights, cấu hình cá nhân, token hoặc artifact smoke vào Git.

Chi tiết worker/config: [PREPARATION.md](../backend/ai-runtime/PREPARATION.md). Các yêu cầu sản phẩm còn lại tiếp tục theo hai plan đã duyệt; các mục thiếu bên trên chưa được đánh dấu hoàn tất.

## Khoảng trống còn lại so với plan

| Phạm vi | Trạng thái |
|---|---|
| Script/video → bản nháp/giọng/video và công cụ biên tập trong app | Có code và kiểm thử; cần demo tương tác UI đầu cuối với dữ liệu giáo viên |
| Nguồn 10/15/60 phút, restart/cancel dài và benchmark WER/đúng ngữ nghĩa | Chưa có bộ nghiệm thu thực đầy đủ; không suy ra chất lượng từ unit test hoặc smoke |
| Classroom material ID thật và mở học liệu bên học sinh | Chưa nghiệm thu trên tài khoản Google thật |
| Ghi chú qua đầu nhận Meet thật, đổi/re-share nguồn | Chưa nghiệm thu; nguồn không xác định vẫn che ghi chú |
| P2: chèn câu hỏi đã duyệt từ kho, biến thể bài gắn lớp, mẫu xuất trường/khoa | Đã triển khai API/UI và kiểm thử; mẫu do giáo viên ánh xạ và preview PDF thật |
| Bản PDF giáo viên có notes/đáp án, khác bản học sinh | Đã có bộ xuất riêng, nhãn riêng tư và chặn đăng Classroom; đã kiểm hình PDF mẫu với tiếng Việt và hình câu hỏi |
| Sinh cảnh/nhân vật AI nâng cao | Giai đoạn sau; chưa chọn provider/chi phí/opt-in |
