# Soạn bài — happy cases để test thủ công

Cập nhật 2026-10-20. **60 happy cases, chưa thực thi thủ công**. Đây là bộ hướng dẫn kiểm thử, không phải báo cáo PASS. Chỉ bao phủ luồng thành công theo yêu cầu; không sinh negative/boundary cases. Áp dụng QUICK của generate-testcases-from-requirements / rbt-manual-testing với phạm vi happy-only do người dùng chỉ định.

## Cách dùng

- Thanh dashboard: **Phòng học | Kế hoạch giảng dạy | Soạn bài | Lịch sử**. Kế hoạch giảng dạy dùng **Tạo kế hoạch / Chỉnh sửa** để mở Studio; Soạn bài dùng **Soạn bài mới** (danh sách trống), **Soạn mới** (đã có bài), **Soạn tiếp** để mở workspace. Form mới là **Tạo bài soạn mới → Bắt đầu soạn**.
- Hai nhánh dùng chung thư viện/bài/ID, không có migration hay kho bản sao riêng. Xóa một bài trong nhánh này cũng làm bài đó biến mất ở nhánh kia; các bộ lọc môn của hai nhánh độc lập. Các nhãn workspace dưới đây lấy từ code hiện tại. Tên lớp/dữ liệu QA là dữ liệu người test chuẩn bị.
- Trong workspace, menu **Xuất và sử dụng** là biểu tượng trên thanh đầu. Khu vực gồm **Nội dung bài / Bảng & tài liệu / Video / Nguồn / Tác vụ / Học liệu**. **Lịch sử & công cụ bài** nằm trong menu này.
- Mỗi case có điều kiện trước, dữ liệu cụ thể, ba bước và ba kết quả tương ứng. Dùng CSV UTF-8 có BOM cùng tên để mở Excel và ghi PASS/FAIL/Blocked, người chạy, bằng chứng nếu cần. Automatable chỉ là khả năng tự động hóa sau này, không có nghĩa case đã được automation chạy.
- Nếu thiếu điều kiện trước thì ghi **Blocked — thiếu điều kiện trước**, không ghi PASS và không coi việc nút bị khóa là nghiệm thu chức năng đó. Giữ nguyên trạng thái ban đầu **Chưa chạy** cho tới khi người test thực hiện.

## Chuẩn bị một lần

| Mã điều kiện | Cần chuẩn bị |
|---|---|
| Cơ bản | Backend chạy, frontend kết nối được, đăng nhập giáo viên QA; dùng dữ liệu thử riêng. |
| Fixtures | [Script Việt](fixtures/lesson-preparation/water-cycle-vi.txt), [script Anh](fixtures/lesson-preparation/water-cycle-en.txt). Tạo PDF chữ một trang từ script; PNG WATER CYCLE; video60giây có giọng Việt (0–20 bốc hơi,20–40 ngưng tụ,40–60 mưa); WAV cùng nội dung. Mỗi file dưới20MB. Các file nhị phân này do người test chuẩn bị, không giả định có trong repo. |
| STT_READY | Python/runtime và PhoWhisper-small được cài, kiểm tra thành phần đạt. |
| TRANSLATE_READY | Runtime và VinAI Translate vi2en-v2 được cài, kiểm tra đạt. |
| TTS_READY | Runtime và Kokoro-82M được cài, kiểm tra đạt; ưu tiên giọng Anh. |
| RENDER_READY | TTS_READY, FFmpeg và FFprobe cấu hình đúng, narration Anh đã duyệt. |
| API_READY | Provider/model/API base URL OpenAI-compatible được chọn; key cấu hình trên backend theo [hướng dẫn API](../architecture/preparation-authoring-api.md); có kết nối và hạn mức. **Hiện chưa chọn provider nên TC024–025 chưa thể chạy thành công; ghi Blocked nếu vẫn chưa cấu hình.** Không đưa key vào tài liệu/CSV. |
| QUESTION_READY | Dùng quy trình quản trị kho hiện có để tạo nguồn active APPROVED có nhóm QA Water Cycle: context chung, Q1/Q2, đáp án, ảnh câu hỏi và hình lời giải. Nhóm hoàn chỉnh trước khi chạy case. |
| LOCAL_CLASS_READY | Tài khoản QA sở hữu lớp nội bộ QA 5A trong dữ liệu lớp. |
| GOOGLE_READY | Giáo viên đã kết nối Google và có quyền dạy lớp thử QA HocLuc Sandbox; có học sinh QA kiểm link. Người test chủ động đồng ý đăng dữ liệu QA. **Không dùng lớp học thật; bộ case không tự thực hiện đăng.** |
| MEET_READY | Google/Meet dùng được trong app; có máy/tài khoản học sinh QA riêng. Nghiệm thu notes riêng cần quan sát đầu nhận thật, chưa được suy ra từ widget tests. |
| OFFLINE_PACKAGE_READY | Có ZIP runtime/model/FFmpeg đúng manifest theo [hợp đồng gói offline](../architecture/preparation-offline-components.md). **Weights/gói phân phối đang chờ được cung cấp thì case liên quan model/cài gói là Blocked**, không giả định pull repo đã có weights. |

## Thứ tự chạy đề xuất

Chạy A trước để có bài, B–D để có nguồn/nội dung, E để thử kho và biến thể, F để tạo video, G để xuất, H để nghiệm thu Google/Meet, I cho cài đặt/tác vụ/bảng. Có thể bỏ qua nhóm chưa đủ điều kiện và ghi Blocked. Lưu bài giữa các nhóm, dùng bài QA riêng khi thao tác xóa/khôi phục.

## Giới hạn UI đối chiếu trước khi test

- PDF hiện được đưa vào bảng Studio trong app; chưa có bộ trích văn bản PDF/OCR tự động. TC019 kiểm luồng nhập PDF lên bảng, không hứa tự sinh transcript từ PDF.
- Renderer hỗ trợ cảnh Hình minh họa nhưng scene editor hiện chưa có điều khiển gán ảnh nguồn vào cảnh. TC037/045 dùng Chữ và chuyển cảnh, Sơ đồ đơn giản, Chữ nhấn mạnh; không yêu cầu một nút gán ảnh chưa có. Ảnh câu hỏi được kiểm riêng ở TC030.
- Animation nhân vật/cảnh AI, TTS tiếng Việt, pause/resume bản thu và catalog tải model online có chữ ký không thuộc chức năng đã có nên không được đưa vào happy cases này.

## A. Điều hướng và quản lý bài

### HOCLUC_PREP_TC_001 — Hai nút Kế hoạch giảng dạy và Soạn bài tách biệt

**Điều kiện:** Đã đăng nhập tài khoản giáo viên; có bài QA Vòng tuần hoàn nước.

**Dữ liệu:** Bài QA Vòng tuần hoàn nước.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Quan sát thanh điều hướng dashboard. | Soạn bài nằm ngay sau Kế hoạch giảng dạy. |
| 2 | Mở bài QA Vòng tuần hoàn nước từ Kế hoạch giảng dạy; quay lại dashboard. | Nhánh Kế hoạch giảng dạy mở Studio như luồng cũ. |
| 3 | Mở cùng bài từ Soạn bài. | Nhánh Soạn bài mở workspace có Nội dung bài, Bảng & tài liệu, Video, Nguồn và Tác vụ / Học liệu. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Smoke @CriticalPath @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_002 — Tạo bài mới trong Soạn bài

**Điều kiện:** Dashboard đang ở Soạn bài.

**Dữ liệu:** Tên: QA Vòng tuần hoàn nước; môn Sinh học; thời lượng 15 phút.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn Soạn bài mới nếu danh sách trống, hoặc Soạn mới nếu đã có bài; nhập tên/chọn môn Sinh học tại Tạo bài soạn mới và chọn Bắt đầu soạn. | Form tạo bài mở đúng luồng Soạn bài. |
| 2 | Workspace mở phần chọn nguồn; mở Nội dung bài, mở Thời lượng bài và nhập15 tại Thời lượng dự kiến của bài (phút, tùy chọn), rồi Lưu bài. | Bài được tạo và mở workspace. |
| 3 | Quay về Soạn bài rồi chọn Soạn tiếp ở bài vừa tạo. | Tên bài và dữ liệu đã lưu được giữ. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Smoke @CriticalPath @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_003 — Tìm và mở bài đã lưu

**Điều kiện:** Đã có bài TC002.

**Dữ liệu:** Từ khóa: QA Vòng tuần hoàn nước.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở danh sách Soạn bài. | Danh sách bài tải được. |
| 2 | Nhập từ khóa tìm kiếm. | Có bài khớp tên đã nhập. |
| 3 | Mở bài trong kết quả. | Workspace mở đúng bài và nội dung đã lưu. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_004 — Dùng chung bài hiện hữu giữa hai nhánh

**Điều kiện:** Đã có bài TC002; ghi lại ID bài từ dữ liệu kiểm tra của backend nếu cần.

**Dữ liệu:** Đổi tên thành QA Vòng tuần hoàn nước 15 phút.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở bài trong Soạn bài, đổi tên rồi lưu. | Lưu thành công trên bài hiện hữu. |
| 2 | Quay lại Kế hoạch giảng dạy và tìm bài vừa đổi tên. | Cùng bài đã đổi tên xuất hiện; không tự sinh một bài thứ hai do đổi nhánh. |
| 3 | Mở lại từ Soạn bài. | Nội dung và ID vẫn thuộc cùng bài. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_005 — Nhân bản bài thông thường

**Điều kiện:** Bài TC002 đã có phần nội dung và notes.

**Dữ liệu:** Bản sao: QA Water Cycle Copy; sửa nội dung bản sao thành Copy only.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Tại danh sách Soạn bài chọn biểu tượng Nhân bản bài soạn trên bài gốc. | Có bài sao riêng trong danh sách. |
| 2 | Chọn Soạn tiếp ở bản sao, đổi tên thành QA Water Cycle Copy, sửa nội dung thành Copy only và lưu. | Bản sao lưu được chỉnh sửa. |
| 3 | Mở lại bài gốc. | Nội dung bài gốc giữ nguyên. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

## B. Nguồn và bản thu

### HOCLUC_PREP_TC_006 — Upload PDF

**Điều kiện:** Bài TC002 đang mở. Tạo PDF một trang từ fixture Việt bằng Print to PDF.

**Dữ liệu:** water-cycle.pdf; PDF một trang có chữ chọn được; mỗi file dưới 20 MB để dùng preview trong app.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Nguồn → Thêm PDF / video / audio; chọn file trên. | App nhận file đã chọn. |
| 2 | Chờ upload hoàn tất rồi lưu bài. | Nguồn có tên/loại file trong danh sách. |
| 3 | Mở lại bài và xem nguồn vừa thêm. | Nguồn vẫn tồn tại; mở preview hoặc tải về đọc được nội dung gốc. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_007 — Upload ảnh

**Điều kiện:** Bài TC002 đang mở. Chuẩn bị ảnh PNG 1280×720 có chữ WATER CYCLE.

**Dữ liệu:** water-cycle.png; PNG sơ đồ nước; mỗi file dưới 20 MB để dùng preview trong app.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Nguồn → Thêm PDF / video / audio; chọn file trên. | App nhận file đã chọn. |
| 2 | Chờ upload hoàn tất rồi lưu bài. | Nguồn có tên/loại file trong danh sách. |
| 3 | Mở lại bài và xem nguồn vừa thêm. | Nguồn vẫn tồn tại; mở preview hoặc tải về đọc được nội dung gốc. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_008 — Upload video

**Điều kiện:** Bài TC002 đang mở. Chuẩn bị video 60 giây, có tiếng Việt đọc fixture; mỗi đoạn 20 giây.

**Dữ liệu:** water-cycle-vi.mp4; MP4 H.264/AAC 60 giây; mỗi file dưới 20 MB để dùng preview trong app.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Nguồn → Thêm PDF / video / audio; chọn file trên. | App nhận file đã chọn. |
| 2 | Chờ upload hoàn tất rồi lưu bài. | Nguồn có tên/loại file trong danh sách. |
| 3 | Mở lại bài và xem nguồn vừa thêm. | Nguồn vẫn tồn tại; mở preview hoặc tải về đọc được nội dung gốc. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_009 — Upload audio

**Điều kiện:** Bài TC002 đang mở. Chuẩn bị WAV đọc cùng fixture Việt trong 60 giây.

**Dữ liệu:** water-cycle-vi.wav; WAV PCM 60 giây; mỗi file dưới 20 MB để dùng preview trong app.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Nguồn → Thêm PDF / video / audio; chọn file trên. | App nhận file đã chọn. |
| 2 | Chờ upload hoàn tất rồi lưu bài. | Nguồn có tên/loại file trong danh sách. |
| 3 | Mở lại bài và xem nguồn vừa thêm. | Nguồn vẫn tồn tại; mở preview hoặc tải về đọc được nội dung gốc. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_010 — Upload script UTF-8

**Điều kiện:** Bài TC002 đang mở. Dùng fixture Việt đi kèm tài liệu.

**Dữ liệu:** water-cycle-vi.txt; text/plain UTF-8; mỗi file dưới 20 MB để dùng preview trong app.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Nguồn → Thêm PDF / video / audio; chọn file trên. | App nhận file đã chọn. |
| 2 | Chờ upload hoàn tất rồi lưu bài. | Nguồn có tên/loại file trong danh sách. |
| 3 | Mở lại bài và xem nguồn vừa thêm. | Nguồn vẫn tồn tại; mở preview hoặc tải về đọc được nội dung gốc. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_011 — Xem trước nguồn và xóa nguồn chưa dùng

**Điều kiện:** Upload thêm water-cycle-unused.png; chưa gắn vào phần/cảnh/lịch sử đã lưu.

**Dữ liệu:** water-cycle-unused.png có chữ UNUSED.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở preview ảnh UNUSED rồi đóng. | Ảnh hiển thị đúng. |
| 2 | Chọn Xóa nguồn chưa dùng và xác nhận Xóa nguồn. | App xác nhận xóa nguồn. |
| 3 | Tải lại danh sách nguồn. | Ảnh UNUSED không còn trong nguồn; những nguồn khác vẫn còn. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_012 — Ghi microphone thành nguồn audio

**Điều kiện:** Windows; FFmpeg được cấu hình; đã cấp quyền micro và chọn thiết bị.

**Dữ liệu:** Đọc hai câu đầu fixture Việt trong 15 giây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Trong Nguồn chọn Ghi microphone / màn hình, chọn ghi micro và Bắt đầu ghi. | Trạng thái ghi xuất hiện. |
| 2 | Đọc script, chọn Đang ghi — Dừng và lưu nguồn. | Bản thu được thêm vào nguồn. |
| 3 | Preview nguồn audio vừa tạo. | Nghe được hai câu vừa đọc. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_013 — Ghi toàn màn hình kèm microphone

**Điều kiện:** Windows; FFmpeg hỗ trợ capture; micro đã cấp quyền; chỉ mở dữ liệu QA.

**Dữ liệu:** Hiển thị slide WATER CYCLE và đọc fixture Việt trong 15 giây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn ghi màn hình → Toàn màn hình, bật Ghi kèm microphone và bắt đầu. | Ghi bắt đầu với nguồn đã chọn. |
| 2 | Hiển thị slide/đọc script rồi dừng và lưu. | Có nguồn video mới. |
| 3 | Preview video nguồn. | Video thấy slide và nghe được giọng đọc. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_014 — Ghi riêng cửa sổ

**Điều kiện:** Windows; FFmpeg hỗ trợ hwnd; cửa sổ trình chiếu QA mở và không thu nhỏ.

**Dữ liệu:** Cửa sổ QA Water Cycle; hiển thị WATER CYCLE trong 15 giây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn Ghi màn hình / cửa sổ và chọn đúng cửa sổ QA Water Cycle. | App hiển thị tiêu đề cửa sổ đã chọn. |
| 2 | Xác nhận cửa sổ, bắt đầu ghi; thao tác trong cửa sổ rồi dừng. | Nguồn video được lưu. |
| 3 | Preview nguồn mới. | Khung hình ghi đúng cửa sổ QA. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_015 — Khôi phục bản thu chưa lưu qua restart

**Điều kiện:** Windows; bản thu QA đang ghi ít nhất 10 giây và dữ liệu đã flush; có người vận hành backend QA.

**Dữ liệu:** Bản thu micro đọc đoạn ngưng tụ.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Để bản thu chưa lưu, đóng phiên test và restart backend QA rồi mở lại cùng bài. | App thông báo có bản thu từ phiên trước. |
| 2 | Chọn Khôi phục và lưu bản ghi trước. | Bản thu có thể phục hồi được thêm vào nguồn. |
| 3 | Preview nguồn phục hồi. | Phần đã ghi trước restart nghe/xem được. Không dùng kết quả này để kết luận mọi crash đều cứu được. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

## C. Chép lời và bằng chứng nguồn

### HOCLUC_PREP_TC_016 — Chép lời toàn bộ audio tiếng Việt

**Điều kiện:** STT_READY; audio WAV TC009 đã upload.

**Dữ liệu:** water-cycle-vi.wav, 60 giây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn Chép lời tiếng Việt / trích nội dung trên WAV và chọn toàn bộ nguồn. | Tác vụ chép lời được tạo. |
| 2 | Chạy tác vụ; mở Tác vụ / Học liệu khi hoàn tất. | Tác vụ hoàn tất và có transcript/mốc. |
| 3 | Duyệt kết quả transcript. | Có nội dung tiếng Việt về bốc hơi, ngưng tụ, mưa để giáo viên rà soát. Không đòi khớp tuyệt đối từng từ. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Smoke @Model @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_017 — Chép lời đoạn video đã chọn

**Điều kiện:** STT_READY; video TC008 có nội dung ngưng tụ tại giây20–40.

**Dữ liệu:** water-cycle-vi.mp4; bắt đầu20, kết thúc40 giây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở chép lời trên video và đặt khoảng20–40. | Khoảng chọn được hiển thị. |
| 2 | Preview từ mốc đã chọn rồi chạy chép lời. | Preview bắt đầu ở khoảng20 và tác vụ dùng đoạn đã chọn. |
| 3 | Duyệt transcript kết quả. | Transcript thuộc đoạn ngưng tụ, có mốc tương ứng nguồn. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_018 — Sửa transcript, seek và thêm vào bài

**Điều kiện:** TC017 hoàn tất; transcript có các đoạn.

**Dữ liệu:** Đổi một câu thành Hơi nước ngưng tụ thành mây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Trong transcript bấm mốc thời gian của đoạn. | Nguồn mở tại mốc đoạn. |
| 2 | Sửa câu theo dữ liệu và lưu nội dung đã duyệt. | Transcript hiển thị câu đã sửa. |
| 3 | Chọn Thêm transcript đã sửa vào bài rồi lưu. | Phần bài nhận đúng transcript đã duyệt. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_019 — Mở PDF nguồn lên bảng soạn trong app

**Điều kiện:** PDF chữ TC006 đã upload; bài đã lưu.

**Dữ liệu:** water-cycle.pdf có ba đoạn bốc hơi/ngưng tụ/mưa.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Trong Nguồn, tại PDF chọn biểu tượng Chép lời tiếng Việt / trích nội dung. | PDF được nhập vào bảng và Studio của cùng bài mở trong app. |
| 2 | Trong Studio vừa mở, chọn tài liệu PDF đã nhập và xem trang. | Có thể đọc tài liệu trên bảng; thao tác này không chạy trích văn bản/OCR. |
| 3 | Quay lại workspace và mở lại bảng của bài. | PDF vẫn thuộc bảng cùng bài sau khi quay lại. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_020 — Gắn nguồn và mốc cho phần/cảnh

**Điều kiện:** Đã upload MP460 giây và có phần Ngưng tụ.

**Dữ liệu:** Nguồn water-cycle-vi.mp4; khoảng20–40 giây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Ở phần Ngưng tụ chọn Gắn nguồn đã kiểm chứng. | Hộp Liên kết đoạn nguồn mở. |
| 2 | Chọn video, nhập20–40 và Gắn nguồn; lưu. | Tham chiếu giữ nguồn/revision và khoảng đã chọn. |
| 3 | Bấm tham chiếu vừa gắn. | Nguồn mở tại giây20. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_021 — Trích khung hình video thành nguồn ảnh

**Điều kiện:** FFmpeg và FFprobe sẵn sàng; video TC008 đã upload.

**Dữ liệu:** water-cycle-vi.mp4 tại giây25, khung hình đám mây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Ở video chọn Trích ảnh tại mốc video. | Hộp nhập mốc mở. |
| 2 | Nhập25 và xác nhận trích ảnh. | Tác vụ tạo nguồn ảnh. |
| 3 | Mở ảnh mới trong Nguồn. | Ảnh là khung hình video tại mốc25. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

## D. Nội dung và AI authoring

### HOCLUC_PREP_TC_022 — Tạo nội dung trực tiếp từ script

**Điều kiện:** Mở Nguồn của bài trống; không cần API/model speech.

**Dữ liệu:** Toàn bộ fixture water-cycle-vi.txt.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Dán fixture vào Script hoặc mô tả bài muốn tạo. | Script hiển thị đủ dấu và xuống dòng. |
| 2 | Chọn Dùng script làm nội dung. | Có phần bài từ script, không gắn nhãn AI. |
| 3 | Mở Nội dung bài, sửa tên phần thành Vòng tuần hoàn và lưu. | Tên/nội dung được lưu. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Smoke @CriticalPath @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_023 — Chia script thành nhiều cảnh local

**Điều kiện:** Không cần API/model speech; Python/runtime worker đã cấu hình và mở bài QA video.

**Dữ liệu:** Fixture water-cycle-en.txt có ba đoạn sau tiêu đề.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Dán fixture Anh ở Nguồn. | Script được nhập. |
| 2 | Chọn Chia script thành cảnh, đợi job và Duyệt / áp dụng kết quả. | Các đoạn tạo thành nhiều cảnh qua worker local sau khi duyệt. |
| 3 | Mở Video và kiểm tra các cảnh rồi lưu. | Thứ tự/nội dung cảnh đúng script, có thể sửa từng cảnh. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_024 — API từ mô tả thành bản nháp có duyệt

**Điều kiện:** API_READY; provider/model/key do backend quản lý; người test đồng ý gửi dữ liệu QA.

**Dữ liệu:** Prompt: Create a 15-minute lesson about the water cycle for grade 5. Include three stages and one classroom activity.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn AI đề xuất bài / storyboard; đọc API, model và toàn bộ Nội dung sẽ gửi. | Hộp xác nhận hiển thị đúng đích và prompt. |
| 2 | Chọn Gửi và tạo bản nháp; đợi job hoàn tất và mở Duyệt / áp dụng. | Có bản nháp để duyệt; bài chưa tự bị thay trước khi áp dụng. |
| 3 | Đọc kết quả rồi chọn Thêm kết quả vào bài. | Kết quả được thêm vào bài với nhãn AI/chưa kiểm chứng nguồn. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @CriticalPath @ExternalAPI @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_025 — API từ transcript thành giáo án/storyboard

**Điều kiện:** API_READY; transcript TC018 đã duyệt; người test đồng ý gửi QA.

**Dữ liệu:** Transcript đã sửa: Hơi nước ngưng tụ thành mây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Dùng transcript đã duyệt làm đầu vào AI; đọc lại nội dung gửi trong hộp xác nhận. | Đầu vào có đúng transcript đã sửa; có xác nhận riêng cho job này. |
| 2 | Xác nhận gửi yêu cầu mới và đợi kết quả. | Kết quả có nội dung bài/storyboard về transcript. |
| 3 | Duyệt rồi áp dụng bản nháp. | Bài nhận kết quả sau thao tác duyệt của giáo viên. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @ExternalAPI @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_026 — Biên tập mục tiêu, nội dung và thời lượng

**Điều kiện:** Bài có phần Ngưng tụ.

**Dữ liệu:** Mục tiêu: Giải thích sự hình thành mây; phần5phút; tổng15phút.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở phần Ngưng tụ và điền mục tiêu/nội dung/thời lượng5. | Các trường nhận đúng giá trị. |
| 2 | Đặt thời lượng bài15 phút; lưu. | Dữ liệu được lưu, tổng thời lượng hiển thị theo bài. |
| 3 | Đóng và mở lại bài. | Mục tiêu/nội dung/5phút được giữ. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_027 — Thêm hoạt động gắn mục tiêu

**Điều kiện:** TC026 có mục tiêu phần.

**Dữ liệu:** Hoạt động Quan sát hơi nước; GV: đưa cốc nước ấm; HS: mô tả hơi nước;3phút.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn Thêm hoạt động tại phần Ngưng tụ. | Form hoạt động mở. |
| 2 | Điền dữ liệu, bật Liên kết mục tiêu của phần này và Lưu hoạt động. | Hoạt động có việc GV/HS,3phút và liên kết mục tiêu. |
| 3 | Lưu bài rồi mở lại hoạt động. | Dữ liệu hoạt động được giữ đúng. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_028 — Ghi notes và thẻ riêng giáo viên

**Điều kiện:** Bài có phần Ngưng tụ.

**Dữ liệu:** Notes TEACHER_ONLY_WATER; thẻ Hiểu sai: Clouds are smoke.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Nhập TEACHER_ONLY_WATER vào Lời nhắc, đáp án riêng. | Notes có giá trị đã nhập. |
| 2 | Thêm thẻ hỗ trợ loại hiểu sai, nhập nội dung riêng, giữ riêng tư mặc định. | Thẻ được lưu ở phần riêng giáo viên. |
| 3 | Lưu và mở lại phần. | Notes và thẻ vẫn hiện đúng trong workspace giáo viên. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_029 — Duyệt nội dung công khai của thẻ hỗ trợ

**Điều kiện:** Đã có thẻ riêng TC028.

**Dữ liệu:** Public text: Clouds contain tiny water droplets; private hint: TEACHER_HINT_01.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Sửa thẻ, giữ hint riêng và nhập public text trên. | Thẻ có hai phần riêng/công khai. |
| 2 | Duyệt phần công khai hiện tại rồi lưu thẻ/bài. | Nội dung công khai có trạng thái đã duyệt. |
| 3 | Xuất PDF học sinh và xem. | PDF có public text đã duyệt; hint riêng không có trong bản học sinh. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

## E. Kho câu hỏi, lớp và tái sử dụng

### HOCLUC_PREP_TC_030 — Chèn nhóm câu hỏi đã duyệt có hình và đáp án riêng

**Điều kiện:** QUESTION_READY: nguồn active APPROVED gồm nhóm Water Cycle Q1/Q2, context, ảnh câu hỏi và hình lời giải.

**Dữ liệu:** Nhóm QA Water Cycle;Q1 evaporation;Q2 condensation;answer PRIVATE_ANSWER_WATER.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Xuất và sử dụng → Chèn câu hỏi đã duyệt, tìm QA Water Cycle. | Kết quả tìm là nguồn đã duyệt. |
| 2 | Chọn nhóm/câu trong nhóm và xác nhận chèn. | Chèn trọn nhóm dùng chung context, có ảnh công khai và nguồn snapshot. |
| 3 | Xem phần mới rồi tạo PDF học sinh/giáo viên. | Giáo viên thấy đáp án/hình lời giải; PDF học sinh chỉ có context/câu/ảnh công khai, PDF giáo viên có đáp án. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @CriticalPath @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_031 — Tạo biến thể theo lớp nội bộ

**Điều kiện:** LOCAL_CLASS_READY; bài gốc đã lưu và có PDF/video.

**Dữ liệu:** Lớp QA 5A; tên QA Water Cycle 5A; ghi chú Tăng hoạt động nhóm.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn Biến thể bài theo lớp; chọn QA 5A và điền dữ liệu. | Lớp/tên/ghi chú được chọn. |
| 2 | Chọn Tạo và mở biến thể, sửa một phần rồi lưu. | Có bài biến thể độc lập với nhãn lớp và nguồn bài gốc. |
| 3 | Mở bài gốc và kiểm bản xuất trong biến thể. | Bài gốc không đổi; bản xuất được sao chép cần tạo lại cho biến thể. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_032 — Tạo biến thể theo lớp Google

**Điều kiện:** GOOGLE_READY; giáo viên có quyền dạy lớp QA HocLuc Sandbox.

**Dữ liệu:** Lớp Google QA HocLuc Sandbox; tên QA Water Cycle Google.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Trong Biến thể bài theo lớp chọn Tải lớp Google Classroom. | Danh sách lớp giáo viên tải được. |
| 2 | Chọn QA HocLuc Sandbox rồi Tạo và mở biến thể. | Biến thể mang đúng lớp Google đã chọn. |
| 3 | Chọn Dạy từ bài này và xem lớp được ưu tiên. | Hộp chọn lớp ưu tiên chính xác QA HocLuc Sandbox; chưa tự đăng học liệu. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Google @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_033 — Lưu phần vào thư viện và chèn sang bài khác

**Điều kiện:** Phần câu hỏi TC030 đã lưu cùng ảnh/nguồn; có bài QA Reuse trống.

**Dữ liệu:** Phần QA Water Cycle trong thư viện cá nhân.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Lịch sử & công cụ bài → Thư viện phần bài tại máy; chọn Lưu phần. | Có phần trong thư viện. |
| 2 | Mở QA Reuse và chọn Chèn tại phần vừa lưu. | Bài đích nhận bản sao phần. |
| 3 | Lưu, mở lại phần chèn và xem ảnh/notes/tham chiếu. | Nội dung, tài sản và tham chiếu đi cùng; nội dung riêng vẫn thuộc giáo viên. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_034 — Khôi phục phiên bản thành bản lưu mới

**Điều kiện:** Bài có bản lưu nội dung A rồi bản lưu nội dung B.

**Dữ liệu:** A: Ngưng tụ tạo mây;B: Ngưng tụ tạo giọt nước nhỏ.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Lịch sử & công cụ bài → Lịch sử phiên bản. | Có cả các bản đã lưu. |
| 2 | Chọn Khôi phục phiên bản A và xác nhận. | Nội dung A được khôi phục. |
| 3 | Lưu/tải lại rồi xem nội dung và lịch sử. | Có revision mới mang nội dung A; lịch sử B vẫn còn. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_035 — Checklist và nhận xét sau buổi

**Điều kiện:** Bài QA đã lưu.

**Dữ liệu:** Nhận xét: HS cần ví dụ ngưng tụ gần gũi; việc: Thêm ví dụ cốc nước lạnh.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Lịch sử & công cụ bài, ghi nhận xét sau buổi. | Nhận xét được tạo. |
| 2 | Chọn Đưa vào việc cần sửa rồi đánh dấu hoàn thành việc đã xử lý. | Có việc cần sửa với trạng thái hoàn thành đã chọn. |
| 3 | Lưu và mở lại công cụ bài. | Nhận xét/checklist/trạng thái được giữ. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_036 — Tạo bản sửa độc lập từ nhận xét

**Điều kiện:** TC035 có nhận xét đã lưu.

**Dữ liệu:** Tên bản sửa QA Water Cycle revision; thêm ví dụ cốc nước lạnh.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Tại nhận xét chọn Tạo bản sửa độc lập. | Có bản sao/bản sửa riêng mang việc cần sửa. |
| 2 | Mở bản nháp và sửa phần Ngưng tụ theo nhận xét; lưu. | Bản sửa lưu được nội dung mới. |
| 3 | Mở lại bài gốc. | Bài gốc giữ nội dung cũ. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

## F. Cảnh, dịch, giọng và phụ đề

### HOCLUC_PREP_TC_037 — Biên tập và sắp xếp cảnh animation

**Điều kiện:** Có các cảnh từ TC023.

**Dữ liệu:** Cảnh1 Evaporation:Chữ và chuyển cảnh;2 Condensation:Sơ đồ đơn giản;3 Rain:Chữ nhấn mạnh.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Video, sửa Tên cảnh, Nội dung hiển thị / phụ đề, Script lời đọc tiếng Anh và chọn Cách trình bày theo dữ liệu. | Mỗi cảnh có nội dung/template riêng. |
| 2 | Dùng Đưa lên/Đưa xuống để đổi thứ tự rồi trả về1–2–3. | Thứ tự đổi đúng thao tác. |
| 3 | Lưu và mở lại Video. | Ba cảnh giữ đúng dữ liệu và thứ tự. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_038 — Dịch Việt sang Anh cho cảnh

**Điều kiện:** TRANSLATE_READY; cảnh chưa khóa.

**Dữ liệu:** Text: Hơi nước nguội đi và ngưng tụ thành mây.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Nhập câu Việt vào nội dung cảnh rồi chọn dịch Việt → Anh. | Tác vụ dùng đầu vào Việt hiện tại. |
| 2 | Chờ tác vụ và mở Duyệt / áp dụng. | Có bản dịch Anh để đọc lại. |
| 3 | Duyệt và áp dụng kết quả. | Lời đọc/nội dung được áp dụng theo kết quả đã duyệt, giáo viên có thể sửa tiếp. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Model @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_039 — Nghe giọng Anh và đổi voice

**Điều kiện:** TTS_READY; cảnh có narration Anh.

**Dữ liệu:** Narration: Water vapor cools and forms clouds; voice af_heart rồi chọn một voice khác có sẵn.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn af_heart và tạo/nghe lời đọc cảnh. | Có audio giọng Anh cho narration. |
| 2 | Chọn voice khác trong danh sách và tạo lại lời đọc. | App dùng voice mới, yêu cầu duyệt lại phụ đề liên quan. |
| 3 | Preview audio mới. | Nghe được lời đọc mới, đúng câu đã nhập. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Model @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_040 — Glossary phát âm và tái tạo chọn lọc

**Điều kiện:** TTS_READY; có hai cảnh đã tạo audio, chỉ cảnh1 chứa H2O.

**Dữ liệu:** Thuật ngữ H2O → water;cảnh2 không chứa H2O.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Trong Lịch sử & công cụ bài thêm cách đọc H2O → water và lưu. | Glossary được lưu. |
| 2 | Xem trạng thái phụ đề/audio của hai cảnh. | Cảnh bị ảnh hưởng cần duyệt/tạo lại; cảnh không đổi không bị đánh dấu lại vô cớ. |
| 3 | Tạo lại lời đọc/dựng bài và kiểm thông tin job/cache khi có. | Narration cảnh1 dùng water; cảnh không đổi được tái sử dụng khi cache đáp ứng điều kiện. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_041 — Khóa rồi mở khóa cảnh đã duyệt

**Điều kiện:** Cảnh có nội dung đã lưu.

**Dữ liệu:** Cảnh Condensation.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Bật Khóa nội dung cảnh đã duyệt và lưu. | Cảnh được khóa. |
| 2 | Chọn cảnh khác rồi quay lại; xem trạng thái khóa. | Nội dung đã duyệt được giữ; vẫn dùng được công cụ phụ đề/dựng cho cảnh. |
| 3 | Mở khóa, lưu rồi sửa tiêu đề thành Condensation reviewed. | Có thể sửa lại sau khi mở khóa và lưu. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_042 — Sửa và duyệt cue phụ đề tiếng Anh

**Điều kiện:** Cảnh có audio dài hơn6giây; narration đã chốt.

**Dữ liệu:** Cue1 0–3: Water evaporates.;cue2 3–6: Clouds form.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Phụ đề và diễn tập cảnh; nhập hai cue trên và bật xuất phụ đề. | Cue hiển thị đúng văn bản/mốc. |
| 2 | Chọn Lưu và duyệt phụ đề rồi lưu bài. | Phụ đề được duyệt cho narration hiện tại. |
| 3 | Mở lại cảnh. | Hai cue và trạng thái duyệt còn giữ. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_043 — Phụ đề song ngữ và khung điện thoại

**Điều kiện:** TC042 đã có hai cue.

**Dữ liệu:** Bản dịch cue1: Nước bốc hơi.;cue2: Mây hình thành.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn Song ngữ, nhập bản dịch thứ hai cho từng cue. | Cả Anh/Việt hiển thị theo cue. |
| 2 | Xem thử chiều rộng điện thoại. | Preview cho thấy hai ngôn ngữ theo chiều rộng điện thoại. |
| 3 | Lưu và duyệt phụ đề. | Bản dịch thủ công đã duyệt được lưu; không đòi dịch Anh→Việt tự động. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_044 — Diễn tập cảnh với lời nhắc riêng

**Điều kiện:** Cảnh có phụ đề và notes TEACHER_REHEARSAL.

**Dữ liệu:** Hai cue TC042;notes TEACHER_REHEARSAL.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Phụ đề và diễn tập cảnh, bắt đầu đồng hồ diễn tập. | Đồng hồ bắt đầu chạy. |
| 2 | Theo dõi cue và nhắc riêng giáo viên khi thời gian chạy. | Cue theo mốc và notes riêng hiện cho giáo viên. |
| 3 | Dừng/đặt lại theo điều khiển đang có. | Có thể dừng/đặt lại để diễn tập tiếp. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_045 — Dựng video animation có giọng và SRT

**Điều kiện:** RENDER_READY; ba cảnh có narration Anh; cue đã duyệt khớp thời lượng audio.

**Dữ liệu:** Ba cảnh Water Cycle, tổng khoảng15–30giây,1280×720.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Lưu bài và chọn Dựng video animation. | Job dựng tạo với revision hiện tại. |
| 2 | Theo dõi tiến độ ở Tác vụ / Học liệu cho đến hoàn tất. | Có MP4 và phụ đề/timeline của job. |
| 3 | Preview MP4 và SRT. | Video có chữ/hình theo cảnh, giọng đọc và thứ tự đúng; SRT có cue đã duyệt. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @CriticalPath @Model @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_046 — Bật/tắt CC khi preview MP4

**Điều kiện:** TC045 hoàn tất; job có MP4 và SRT.

**Dữ liệu:** MP4 Water Cycle và SRT cùng job.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở preview MP4 trong app. | Video phát được. |
| 2 | Bật CC và phát qua cue. | Track phụ đề xuất hiện theo mốc. |
| 3 | Tắt CC và tiếp tục phát. | Track phụ đề ẩn khi tắt; phần chữ thuộc hình video vẫn có thể còn. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_047 — Dựng lại bản mới và tái sử dụng cảnh không đổi

**Điều kiện:** RENDER_READY; TC045 có cache; chỉ thay cảnh2.

**Dữ liệu:** Sửa chữ cảnh2 thành Clouds contain water droplets.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Sửa cảnh2 và lưu bài. | Bài có revision mới, video cũ được nhận diện là cũ. |
| 2 | Tạo lại video; xem thông tin job/cache nếu hiển thị. | Cảnh thay đổi được xử lý lại; cảnh không đổi có thể dùng cache đã kiểm. |
| 3 | Preview bản mới và xem danh sách bản xuất. | Bản mới có chữ mới và revision hiện tại, chọn được để xuất. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

## G. Mẫu xuất và học liệu

### HOCLUC_PREP_TC_048 — Ánh xạ mẫu trường/khoa và preview PDF

**Điều kiện:** Bài có mục tiêu/nội dung/notes.

**Dữ liệu:** Trường QA HocLuc;Khoa Khoa học; mẫu QA Faculty; thứ tự Tên bài→Lớp→Mục tiêu→Nội dung;custom Học kỳ I.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Mẫu trường/khoa & preview PDF, nhập trường/khoa và các trường ánh xạ trên. | Form nhận trường và thứ tự ánh xạ. |
| 2 | Thêm custom Học kỳ I, chọn bản học sinh rồi Lưu mẫu. | Cấu hình mẫu lưu được. |
| 3 | Tạo preview PDF trong hộp mẫu. | PDF thật có header/nội dung theo ánh xạ và thứ tự; không tự coi là biểu mẫu chính thức của trường. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_049 — Quản lý mẫu xuất cá nhân

**Điều kiện:** TC048 đã cấu hình mẫu; cùng tài khoản giáo viên.

**Dữ liệu:** Mẫu QA Faculty; bản mới QA Faculty v2.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Lưu thành mẫu mới QA Faculty rồi tải lại mẫu đã lưu. | Mẫu cá nhân được liệt kê và tải lại. |
| 2 | Thay giá trị custom thành Học kỳ II, cập nhật; lưu thành mẫu mới QA Faculty v2. | Mẫu cập nhật và bản mới lưu riêng. |
| 3 | Tải v2 kiểm giá trị rồi xóa riêng v2. | v2 có giá trị mới rồi được xóa; mẫu QA Faculty vẫn còn. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_050 — Xuất PDF học sinh và tải về

**Điều kiện:** Bài có notes TEACHER_ONLY_WATER, đáp án PRIVATE_ANSWER_WATER, thẻ công khai đã duyệt.

**Dữ liệu:** Tên bài QA Vòng tuần hoàn nước; notes/answer như trên.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Lưu bài, chọn Tạo PDF học sinh và đợi hoàn tất. | Có artifact PDF học sinh ở revision hiện tại. |
| 2 | Preview PDF rồi Lưu về máy. | File lưu được và mở được. |
| 3 | Mở PDF tải về và đọc từng trang. | Có bài/câu hỏi/hình công khai; không có notes/đáp án/hình riêng giáo viên. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Smoke @CriticalPath @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_051 — Xuất PDF giáo viên có notes/đáp án

**Điều kiện:** Cùng bài/dữ liệu TC050.

**Dữ liệu:** TEACHER_ONLY_WATER;PRIVATE_ANSWER_WATER;hình lời giải.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chọn Tạo PDF giáo viên (riêng tư). | Có artifact riêng giáo viên. |
| 2 | Preview rồi tải PDF về. | PDF có nhãn BẢN GIÁO VIÊN — CÓ NỘI DUNG RIÊNG trên các trang. |
| 3 | Mở từng trang và đối chiếu nội dung riêng. | Có notes, đáp án/lời giải và ảnh riêng; bố cục chữ/ảnh đọc được. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @CriticalPath @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_052 — Xem/tải và dọn bản xuất chưa dùng

**Điều kiện:** Có bản PDF học sinh phụ chưa publication và không cần giữ trong lịch sử job đang dùng.

**Dữ liệu:** Bản xuất phụ QA-unused.pdf tạo ở bài QA riêng.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Trong Xuất / Đăng Classroom mở tùy chọn Xem trước trên bản phụ. | PDF preview đọc được. |
| 2 | Lưu về máy rồi đóng preview. | File tải về mở được. |
| 3 | Chọn Xóa bản xuất chưa dùng và xác nhận. | Bản xuất được phép dọn không còn trong danh sách; bản khác giữ nguyên. |

Ưu tiên: **High** · Automatable: Yes · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

## H. Classroom và mang bài đi dạy

### HOCLUC_PREP_TC_053 — Đăng học liệu học sinh lên lớp Google thử nghiệm

**Điều kiện:** GOOGLE_READY; bài đã lưu; PDF/MP4 mới; người test cho phép đăng duy nhất lớp sandbox.

**Dữ liệu:** Lớp QA HocLuc Sandbox;tiêu đề QA Water Cycle Material;mô tả For manual QA only.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Xuất / Đăng Classroom; chọn PDF học sinh và MP4 mới, chọn lớp sandbox. | Chỉ học liệu học sinh xuất hiện để chọn, PDF giáo viên không thuộc gói. |
| 2 | Nhập dữ liệu, duyệt gói và xác nhận quyền Google nếu app yêu cầu rồi đăng. | Yêu cầu đăng sử dụng đúng lớp/file đã xác nhận. |
| 3 | Theo dõi tiến độ và bấm Mở học liệu Classroom khi hoàn tất. | Có material/link kết quả; tài khoản học sinh thử nghiệm mở được đúng file. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @CriticalPath @Google @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_054 — Mở lại nhật ký đăng và đối soát yêu cầu gốc

**Điều kiện:** GOOGLE_READY; đã có publication QA từ TC053.

**Dữ liệu:** Material QA Water Cycle Material và request đã tạo.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Đóng hộp đăng rồi mở lại bài/hộp Xuất / Đăng Classroom. | Publication trước vẫn được liệt kê cùng tiến độ/trạng thái. |
| 2 | Xem tiến trình/nhật ký publication; dùng Tiếp tục / đối soát khi trạng thái cung cấp thao tác này. | Trạng thái được tải/đối soát theo request gốc. |
| 3 | Mở link kết quả và xem lớp sandbox. | Link trỏ cùng material; không tạo thêm material do chỉ xem/đối soát. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Google @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_055 — Dạy từ bài đã soạn và xem notes theo trang

**Điều kiện:** Bài có phần/câu/ảnh công khai và notes riêng; lớp QA được chọn.

**Dữ liệu:** Phần Ngưng tụ;notes TEACHER_ONLY_WATER.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Trong Soạn bài chọn Dạy từ bài này; xác nhận lớp QA. | Bài được lưu và luồng Dạy mở đúng bài/lớp. |
| 2 | Mở Studio và chuyển các trang nội dung/câu hỏi. | Nội dung công khai và ảnh câu hỏi hiện đúng thứ tự. |
| 3 | Mở khu vực notes giáo viên cho từng trang. | Notes/đáp án đúng phần/trang hiện trong điều khiển giáo viên. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @CriticalPath @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_056 — Chia sẻ Audience qua Meet và đối chiếu máy học sinh

**Điều kiện:** MEET_READY; máy học sinh QA tham gia cùng Meet; cả hai bên đồng ý buổi thử.

**Dữ liệu:** Slide công khai WATER CYCLE;notes TEACHER_ONLY_WATER;answer PRIVATE_ANSWER_WATER.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Audience riêng từ Studio và chia sẻ đúng cửa sổ Audience trong Meet. | Audience hiển thị nội dung bài. |
| 2 | Giáo viên chuyển trang và xem notes khi nguồn chia sẻ Audience đã được app xác định. | Giáo viên dùng notes trong điều kiện app cho phép; Audience cập nhật trang. |
| 3 | Đối chiếu màn hình máy học sinh qua nhiều trang, câu hỏi và ảnh. | Học sinh thấy nội dung công khai, không thấy notes/đáp án/điều khiển. Chỉ đánh dấu đạt khi quan sát đầu nhận thật. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Meet @CriticalPath @HappyPath · **Chưa chạy**

## I. Thành phần local và tác vụ

### HOCLUC_PREP_TC_057 — Cài gói offline và kiểm tra thành phần

**Điều kiện:** OFFLINE_PACKAGE_READY; Windows; có ZIP theo manifest hỗ trợ và SHA-256; không dùng weights chưa được cung cấp.

**Dữ liệu:** Gói QA do đội triển khai cung cấp gồm runtime,FFmpeg,ba model speech; chọn đúng phiên bản manifest.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Kiểm tra thành phần → Thành phần local và chọn gói ZIP offline. | App nhận gói và hiển thị thông tin. |
| 2 | Theo dõi tiến độ cài đặt đến hoàn tất. | Cài thành công và có lịch sử; không tải model authoring/Ollama. |
| 3 | Chọn Lưu và kiểm tra rồi xem kết quả thành phần. | Runtime/FFmpeg/STT/dịch/TTS đạt trạng thái sẵn sàng theo gói đã cài. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Offline @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_058 — Chọn đường dẫn model/runtime đã có

**Điều kiện:** STT/TRANSLATE/TTS model và runtime được cung cấp ngoài source; FFmpeg/FFprobe có sẵn.

**Dữ liệu:** Thư mục chuẩn do đội dev cấp: runtime Python,FFmpeg,model root chứa PhoWhisper/VinAI/Kokoro.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Kiểm tra thành phần và chọn các đường dẫn hiện có bằng trình chọn trong app. | Các đường dẫn đã chọn xuất hiện. |
| 2 | Chọn Lưu và kiểm tra. | App kiểm tra khả năng chạy thành phần. |
| 3 | Mở lại hộp cài đặt và xem trạng thái. | Cấu hình được giữ và thành phần đủ điều kiện hiện sẵn sàng. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Offline @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_059 — Tiếp tục biên tập trong khi tác vụ chạy

**Điều kiện:** STT_READY; có audio60giây và một phần bài sẵn.

**Dữ liệu:** Job chép lời WAV;đổi mục tiêu thành Describe the three water-cycle stages.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Chạy job chép lời từ WAV. | Job xuất hiện và có trạng thái/tiến độ. |
| 2 | Trong lúc job chạy, mở Nội dung bài, sửa mục tiêu và lưu. | Có thể tiếp tục soạn, mục tiêu được lưu. |
| 3 | Quay về Tác vụ / Học liệu và xem kết quả. | Job hoàn tất; kết quả chỉ vào bài sau khi giáo viên duyệt, không tự ghi đè mục tiêu vừa sửa. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

### HOCLUC_PREP_TC_060 — Mở bảng soạn và giữ tài liệu khi quay lại workspace

**Điều kiện:** Bài đã lưu; có ảnh sơ đồ/PDF nguồn.

**Dữ liệu:** Bảng WATER CYCLE;vẽ mũi tên từ ocean đến cloud.

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Mở Bảng & tài liệu → Mở bảng soạn bài. | Studio/bảng của đúng bài mở. |
| 2 | Đưa tài liệu lên bảng theo công cụ hiện có, vẽ mũi tên rồi lưu bảng. | Nội dung bảng được lưu. |
| 3 | Quay lại workspace và mở bảng của cùng bài. | Bảng/tài liệu vừa soạn còn ở đúng bài, không tạo bài trùng. |

Ưu tiên: **High** · Automatable: Partial · Auto Type: UI · @Regression @HappyPath · **Chưa chạy**

## Bốn luồng end-to-end để chạy liên tục

Các luồng dưới đây tái sử dụng case trên; không tính thêm vào 60 cases.

| Luồng | Mục tiêu | Cases theo thứ tự | Bằng chứng kết thúc |
|---|---|---|---|
| E2E01 — Soạn tay đến PDF | Không phụ thuộc API/model; tạo bài và học liệu riêng cho hai đối tượng | 001→002→010→022→026→027→028→029→048→050→051→004 | Bài đã lưu; hai PDF tải được, bản giáo viên có notes/đáp án, bản học sinh chỉ có phần công khai. |
| E2E02 — Video nguồn đến animation | Chép lời, kiểm nguồn, tạo cảnh và video có giọng/phụ đề | 008→017→018→020→021→023→037→038→039→042→043→045→046→047 | MP4/SRT mới preview được; có tiếng Anh/phụ đề song ngữ và CC; chỉ cảnh thay đổi cần tái tạo. Cần đầy đủ model/runtime. |
| E2E03 — AI/kho đến biến thể và Classroom | AI có consent, kho đã duyệt, bài theo lớp và đăng thử | 024 hoặc025→030→032→048→050→053→054 | Bản nháp đã duyệt, biến thể đúng lớp; material thật trong lớp sandbox mở được bằng tài khoản học sinh QA. Cần API_READY/QUESTION_READY/GOOGLE_READY. |
| E2E04 — Tái sử dụng đến Dạy và cải tiến | Thư viện, notes riêng, dạy, phản tư và bản sửa | 033→055→056→035→036→034 | Phần tái sử dụng có ảnh/nguồn; đầu nhận Meet chỉ thấy nội dung công khai; có bản sửa độc lập từ nhận xét. Cần MEET_READY. |

## Ghi nhận kết quả

Ghi ID, trạng thái thực tế, build/commit, tài khoản QA không chứa bí mật, tên file, thời điểm, ảnh/video minh chứng và mã job/material nếu có. Chỉ PASS khi đã kiểm đủ ba kết quả của case. Bộ tài liệu này **chưa xác nhận** Google/Meet, chất lượng model, phục hồi crash hoặc provider API đã hoạt động trên máy người test.

Rà soát tài liệu: ID duy nhất001–060; từng case có số bước khớp kết quả, dữ liệu cụ thể, metadata và trạng thái Chưa chạy; Markdown và CSV cùng60 case. Bản CSV: [lesson-preparation-happy-cases.csv](lesson-preparation-happy-cases.csv).
