# Kế hoạch phân hệ SOẠN BÀI trong HocLuc

Date: 2026-10-19
Mode: --hard
Risk: high-risk — mở rộng dữ liệu bài soạn, xử lý media, quyền xuất bản Google và nội dung riêng giáo viên.
Status: Đang triển khai; đã có workspace, pipeline và tích hợp. Chưa nghiệm thu Google/Meet thật và các mục mở rộng. Xem [trạng thái thực tế](../../docs/lesson-preparation.md).

## Session Notes

**Last active:** 2026-10-20.
**Điều chỉnh đã xác nhận:** AI sinh giáo án/storyboard chuyển từ Ollama local sang adapter API bên thứ ba cấu hình endpoint/model, chưa chọn provider. Chỉ nội dung giáo viên xác nhận được gửi qua backend; key và hostname được phép do server quản lý. STT/dịch/TTS giữ ba model hiện có; chia script thủ công vẫn local. Xem [hợp đồng cấu hình](../../docs/architecture/preparation-authoring-api.md).
**Status:** Đã bổ sung kho câu hỏi đã duyệt giữ nhóm/ngữ cảnh và tách đáp án; biến thể gắn lớp độc lập; mẫu trường/khoa có ánh xạ, thư viện cá nhân và preview PDF thật; PDF giáo viên riêng có notes/đáp án và chặn đăng Classroom. Đã có hoạt động/mục tiêu/thẻ hỗ trợ, phụ đề, quản lý nguồn, ghi cửa sổ và installer offline. Chưa đánh dấu hoàn tất gate Google/Meet thật hoặc benchmark dài. Đối chiếu cụ thể ở [ma trận khoảng trống](../../docs/lesson-preparation.md#khoảng-trống-còn-lại-so-với-plan).
Spec: [spec.md](spec.md).

Đợt hoàn thiện tiếp: đã thêm tham chiếu nguồn có version/mốc và seek, trích frame, khóa cảnh, glossary/cache tái tạo chọn lọc, phụ đề song ngữ/CC/preview hẹp, nhận xét thành bản nháp, thư viện sao chép assets qua máy chủ và journal khôi phục bản thu. Gate thực trên Google/Meet và benchmark chất lượng giữ lại vẫn chưa nghiệm thu; không đánh dấu toàn phân hệ hoàn tất chỉ từ unit/widget test.

## 1. Mục tiêu sản phẩm

Nâng phần “Kế hoạch bài giảng” hiện có thành phân hệ **Soạn bài**: giáo viên quản lý bài, nhập/thu nguồn, biên tập giáo án/bài trình chiếu, tạo video có giọng tiếng Anh, lưu ghi chú riêng và đăng học liệu Classroom ngay trong HocLuc. Sau đó có thể dùng bài để dạy bằng Studio hiện tại.

Đây là kế hoạch màn hình, nút, trạng thái, luồng dữ liệu và triển khai của app. Các gợi ý sư phạm trong [nghiên cứu trước](../reports/261019-lesson-preparation-expansion-research.md) chỉ là công cụ tùy chọn bên trong bài; không xây thành 12 module riêng.

## 2. Điểm vào và ba bề mặt giao diện

### A. Dashboard → Soạn bài

Nâng tab/list bài hiện có, không thêm dashboard thứ hai. Có tìm tên, lọc môn, sắp theo cập nhật và trạng thái xử lý. Hành động chính **Soạn mới**; mỗi bài có **Mở** và **Dạy**, menu phụ Nhân bản/Lịch sử/Xuất/Xóa. Bài cũ vẫn mở trực tiếp, không buộc bổ sung mục tiêu hoặc chuyển đổi toàn bộ tài liệu trước.

Tái sử dụng [PlanningListCard](../../frontend/lib/features/classroom_meet/presentation/dashboard/planning_list_card.dart) và [dashboard](../../frontend/lib/features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart).

### B. Soạn mới → chọn cách bắt đầu

Một hộp chọn nguồn, chỉ yêu cầu tên bài; môn/cấp học/thời lượng là tùy chọn:

| Lựa chọn | Thao tác trong app | Kết quả mở |
|---|---|---|
| Bài trống | Nhập tên → Tạo | Workspace có nội dung trống và bảng/PDF sẵn dùng. |
| Từ tài liệu | Chọn PDF hoặc nhập script TXT/Markdown | Nguồn gắn vào bài; PDF vào vùng Bảng & tài liệu, script vào Nội dung. DOCX/PPTX chỉ mở khi adapter thực hỗ trợ, không hiển thị như đã sẵn sàng. |
| Từ video/âm thanh | Chọn MP4/WAV → chọn đoạn → Chép lời | Workspace hiển thị preview nguồn và transcript có mốc thời gian. |
| Ghi nguồn mới | Chọn micro hoặc nguồn cửa sổ/màn hình → bắt đầu/dừng → xem lại | File nguồn được lưu vào bài; giáo viên chọn Chép lời. Không tự thu buổi Meet/học sinh. |
| Từ script/prompt | Dán script hoặc mô tả bài → chọn đầu ra → Tạo nháp | Script giữ nguyên để sửa, hoặc bản đề xuất giáo án/storyboard chờ duyệt. |

Mọi nhánh tạo cùng `planningId`; tạo nội dung lỗi vẫn giữ bài và file nguồn. Không phải năm app con hoặc năm nơi lưu dữ liệu.

### C. Một workspace Soạn bài

```text
[← Soạn bài] [Tên bài · trạng thái lưu]       [Xem trước] [Xuất/Đăng] [Dạy]
------------------------------------------------------------------------
Mục lục bên trái | Nội dung bài | Bảng & tài liệu | Video
------------------------------------------------------------------------
Danh sách phần/  | Vùng chỉnh nội dung đang chọn | Panel ngữ cảnh tùy chọn
trang/scene     |                               | Thuộc tính / AI / Ghi chú
------------------------------------------------------------------------
[Thêm nguồn]  [Nguồn đang dùng]   [Tác vụ: tiến trình · hủy · thử lại]
```

Đây là sơ đồ chức năng, không phải ảnh giao diện đã triển khai. Dùng Manrope, theme blue–slate và component hiện có theo PRODUCT.md/DESIGN.md. Trên cửa sổ hẹp, mục lục/panel thành drawer có Esc/click ngoài để đóng; không ép ba cột hoặc che nội dung đang nhập.

- **Nội dung bài:** giáo án/script với các phần có thể thêm, sửa, di chuyển. Tùy chọn mục tiêu và khối hoạt động; preview bản giáo viên/học sinh.
- **Bảng & tài liệu:** tái sử dụng board/PDF và annotation của Studio. Không tạo engine vẽ/PDF mới. Giữ một route/workspace đang soạn; tích hợp bề mặt board hiện có, không mở thêm phiên giảng dạy hoặc lobby khi chỉnh bài.
- **Video:** danh sách scene, nội dung/hình, script đọc, voice tiếng Anh, thời lượng theo audio, phụ đề và preview. Có **Nghe thử cảnh**, **Tạo lại cảnh**, **Dựng MP4**.
- **Panel nguồn:** preview video/audio, transcript sửa được, liên kết đoạn nguồn; đóng panel không hủy tác vụ.
- **Ghi chú riêng:** theo phần/trang, tách khỏi narration và nội dung học sinh. Khi sang dạy, chuyển theo trang của bài; riêng tư trên Meet là gate kỹ thuật riêng, không chỉ nhãn UI.

Không bắt bài phải có cả giáo án, slide và video. Bài chỉ có PDF/bảng vẫn lưu, xuất và dạy được.

## 3. Luồng thao tác cần hoàn thành

### Video hoặc bản thu → giáo án/bài giảng/video mới

`Thêm nguồn → chọn đoạn → STT Việt → sửa transcript → Tạo nội dung → duyệt từng phần → lưu giáo án/bảng hoặc tạo storyboard → dịch Anh khi cần → TTS Anh → preview → dựng MP4 → xuất/đăng`.

STT chỉ chép lời, không tự đọc công thức/hình trong video. Có thể chọn một frame/ảnh làm nguồn minh họa; OCR/hiểu hình là adapter bổ sung, không suy diễn thành năng lực của STT.

### Script/prompt → animation có giọng

`Dán script/mô tả → chọn template slide/sơ đồ/hình → duyệt scene/script → tạo giọng → xem trước → dựng MP4`.

Script tiếng Anh bỏ qua STT/dịch. Script Việt có thể dịch trước TTS. Prompt cần **LessonAuthoring** bổ sung; model VinAI hiện tại không thay thế bộ sinh nội dung. Nếu authoring chưa sẵn sàng, app cho chọn/cài thành phần trong app hoặc nhập script thủ công, không báo sinh từ prompt thành công.

### Bài → Google Classroom

`Xuất/Đăng → chọn bản học sinh → chọn PDF/MP4/audio đã tạo hoặc file học liệu giáo viên thêm → preview → chọn lớp → tiêu đề/mô tả → Đăng → tiến trình và link kết quả`.

Giáo án giáo viên có notes/đáp án là bản riêng; không đưa vào gói học sinh mặc định. Upload Drive và tạo Classroom material chạy từ backend. Classroom không yêu cầu phải render video trước: bài PDF có thể đăng ngay khi artifact hợp lệ.

Với file giáo viên thêm từ ngoài, preview phải cho giáo viên kiểm tra/xác nhận đây là bản học sinh. Projection chỉ bảo đảm loại private fields của artifact app sinh; metadata allowlist không tự phát hiện mọi đáp án/ghi chú đã nằm trong một PDF/MP4 bất kỳ.

### Bài → dạy trực tiếp

`Dạy → lưu revision thành công → chọn lớp theo flow hiện có → TeachingLauncher → Studio`.

Tái sử dụng [TeachingLauncher](../../frontend/lib/features/classroom_meet/services/teaching_launcher.dart) và luồng lưu/mở bài của [Studio actions](../../frontend/lib/features/studio_board/presentation/screens/studio_screen_actions.dart). Nếu lưu lỗi, không chuyển sang dạy bằng bản cũ mà không báo rõ. Dạy và Đăng Classroom là hai hành động độc lập. Mode 2 không tự cần worker/model AI.

## 4. Chức năng bổ sung đặt ở đâu trong Soạn bài

| Công cụ | Vị trí và thao tác | Đợt |
|---|---|---|
| Kho học liệu của bài | Thêm nguồn → quản lý file/đoạn/ảnh, xem nguồn nào dùng ở phần nào | MVP |
| Mục tiêu và hoạt động | Trong Nội dung bài → thêm khối, việc GV/HS làm, phút dự kiến; báo thiếu liên kết mục tiêu/câu kiểm tra | MVP nhỏ, tùy chọn |
| Câu hỏi từ kho hiện có | Chọn phần → Chèn câu hỏi → lọc kho đã duyệt, giữ nhóm ngữ cảnh; đáp án tách riêng | Mở rộng, không tạo bank mới |
| Ví dụ/gợi ý và hiểu sai | Chọn phần → Hỗ trợ giáo viên; soạn thẻ và chọn bước gợi ý được phép đưa lên học liệu | MVP form thủ công; AI sau |
| Dùng lại một phần bài | Menu của phần → Lưu vào thư viện; bài khác → Chèn từ thư viện | Đợt sau; ban đầu chèn bản sao |
| Biến thể theo lớp | Menu bài → Nhân bản cho lớp → đổi ví dụ/mức hỗ trợ; giữ bài gốc | Đợt sau; không tự phân nhóm học sinh |
| Nhận xét để sửa bài | Mở lại bài → Việc cần sửa; chọn tạo draft mới từ nhận xét sau buổi | Đợt sau |
| Mẫu trường/khoa | Xuất/Đăng → mẫu đã cấu hình, map trường và preview | Đợt sau với một mẫu thật |
| Kiểm tra trước xuất | Trong Xuất/Đăng: thiếu file, render cũ, phụ đề, nội dung riêng, quyền truy cập | MVP |

Glossary, revision, caption, tái tạo scene và rehearsal tiếp tục kế hoạch nền; không tạo thêm menu cấp cao trùng chức năng. CLO/rubric/case là kiểu nội dung tùy chọn cho giảng viên, không buộc mọi giáo viên điền.

## 5. Trạng thái và lỗi trong app

- Lưu: **Chưa lưu → Đang lưu → Đã lưu / Lưu lỗi**. Autosave debounce có revision conflict check; khi rời bài còn tác vụ lưu phải chờ/cho quyết định rõ. Không gắn “Đã lưu” chỉ vì state đã đổi.
- Job: **Chờ → Đang xử lý bước cụ thể → Hoàn tất / Lỗi / Đã hủy**. Hiện bước, tiến độ đo được và hành động thử lại; không giữ một popup khóa app suốt render.
- Artifact: **Chưa tạo / Còn hiệu lực / Cần tạo lại**. Sửa script/voice/scene khiến artifact phụ thuộc cũ mất hiệu lực; không sửa đè file đã đăng.
- Publication: theo từng lớp, artifact và revision: **Đang upload / Đang đăng / Cần đối soát / Đã đăng / Lỗi**. Không gộp thành một cờ “bài đã đăng” khiến bản mới bị hiểu là đã xuất bản.
- Thiếu model/runtime/FFmpeg: panel **Kiểm tra thành phần** cho chọn model local hoặc installer/tải có tiến trình, kiểm version/hash, thử lại trong app. Weights ngoài Git; cloud chỉ bật khi giáo viên chọn.
- Google chưa kết nối/thiếu quyền: khôi phục trong flow xuất bản, không mất bài/file. OAuth có thể yêu cầu trình duyệt hệ thống theo chính sách Google; sau callback app tiếp tục. Không hứa cưỡng ép consent vào WebView.

## 6. Ranh giới dữ liệu và code

Tái sử dụng `/api/plannings` và migration nội dung bài có version. Các API/assets/jobs/publish mở rộng là **hợp đồng đề xuất**, không endpoint đã có:

`Planning → Revision → Section/Page/Scene → SourceAsset/Transcript → Job → Artifact → Publication(courseId, driveFileId, materialId)`.

TeacherNotes và private answers không thuộc student projection. Narrative script là field riêng. Media lưu trên disk và tham chiếu bằng ID; không tải nguyên video/weights vào lesson JSON/RAM. Ánh xạ `planningId/revisionId/sectionId` giữ được sau sắp xếp, clone và qua lần dùng bài.

| Khu vực | Tái sử dụng | Bổ sung dự kiến |
|---|---|---|
| Frontend dashboard | `classroom_dashboard_screen.dart`, `planning_list_card.dart` | entry Soạn bài, tìm kiếm, menu, chọn nguồn |
| Frontend workspace | Studio board/PDF, notes và LocalService | `features/lesson_preparation/{presentation/screens,presentation/widgets,services,domain/models}`; workspace/source/transcript/scene/job/export views |
| Backend bài soạn | PlanningController/PlanningService | schema version/revisions/asset ownership, autosave conflict, migration |
| AI worker | `backend/ai-runtime/models.py`, runtime lifecycle | independent STT/dịch/TTS jobs, authoring adapter, renderer, sequential loading/checkpoints |
| Google | connector Workspace hiện hữu | Drive resumable upload + Classroom material service, scope bổ sung, journal/reconciliation |
| Live integration | TeachingLauncher, Studio notes, sharing observer | projection audience thật và kiểm soát riêng tư; không worker speech trong live entry |

Cần thống nhất identity/ownership cho mới mở rộng; không dựa vào `teacher_default` để chia sẻ dữ liệu nhiều giáo viên. Plugin ngành học đi qua manifest/SDK, port động và lazy disk; không thêm plugin ID/môn vào core. Tách file/component theo giới hạn kiến trúc, không dồn vào StudioScreen.

## 7. Sáu giai đoạn triển khai

| Giai đoạn | Phạm vi bàn giao trong app | Gate |
|---|---|---|
| 01 — Khung Soạn bài | nâng danh sách, chọn nguồn, workspace ba vùng, mở bài cũ, schema/revision/notes riêng, save/autosave | mở/sửa/lưu bài cũ không mất board/PDF/notes; chưa có AI vẫn soạn được |
| 02 — Nguồn và job | nhập/ghi video/audio, panel nguồn, transcript, job tray, kiểm/cài thành phần | nguồn 10 phút xử lý chia đoạn; hủy/restart giữ checkpoint và nguồn; không yêu cầu terminal |
| 03 — Biên tập có AI | script/prompt → giáo án/scene có duyệt, dịch chọn phần, mục tiêu/activity và thẻ hỗ trợ nhỏ | không ghi đè chỉnh sửa; script Anh bỏ STT/dịch; benchmark authoring riêng trước bật |
| 04 — Video và giọng | template animation, TTS Anh theo scene, caption, nghe/xem thử, MP4 | MP4 720p25 dài 1–5 phút, ≥3 scene; không cắt lời; sai lệch tổng audio/video ≤250ms; invalidation đúng |
| 05 — Xuất/Đăng | bản giáo viên/học sinh, PDF/MP4/audio, file thêm, chọn lớp Classroom, tiến trình/kết quả/retry | học sinh lớp thử mở đúng file; không lộ notes/đáp án; timeout không blind-create bài trùng; PDF không phụ thuộc video |
| 06 — Dùng bài và hoàn thiện | Dạy từ workspace, notes theo trang, audience output thật; reuse/nhận xét/biến thể theo ưu tiên | lưu trước launch; Meet hoạt động khi worker dừng; thiết bị học sinh không thấy ghi chú khi nguồn chia sẻ đã xác minh |

Tối thiểu kiểm demo xuyên suốt **script → scene → voice → MP4 → Classroom** và **video → transcript → giáo án → Dạy** trước nghiệm thu toàn phân hệ. Animation nhân vật/cảnh sinh AI vẫn thuộc giai đoạn sau; dùng cùng scene editor/provider interface, không UI/service độc lập và chưa giả định ngân sách.

## 8. Checklist nghiệm thu sản phẩm

1. Từ Dashboard, mở bài cũ hoặc tạo bài bằng mỗi nguồn đã hỗ trợ; không bắt tạo phòng Meet để soạn.
2. Sửa giáo án, PDF/bảng, script và notes trên cùng workspace; đóng/mở không mất dữ liệu.
3. Video/ghi nguồn và script/prompt đi qua pipeline thật; progress/error/cancel/retry hiện trong app.
4. Xem/nghe trước và render; khi sửa script app báo video cũ, không tự dùng nhầm bản.
5. Chọn học liệu hiện có hoặc artifact mới, đăng vào lớp và kiểm bằng tài khoản học sinh thật.
6. Bản giáo viên và học sinh khác nhau đúng; không upload nguyên snapshot/handout notes.
7. Dạy giữ flow Meet/Classroom/Calendar hiện tại; worker/model AI dừng vẫn vào lớp được.
8. Ghi chú đang mở phải ẩn trước picker/chia sẻ mới; đổi nguồn/re-share hủy xác minh cũ. Nếu không xác định nguồn an toàn, không hiển thị notes nhạy cảm hoặc khẳng định riêng tư. Kiểm thực stream thiết bị học sinh.
9. Test migration/ownership/revision/jobs/projection/publication; widget các trạng thái chính và responsive. Chạy plugin validator, 12 architecture invariants, analyzer và web release build khi triển khai frontend.

Chưa có thay đổi runtime hoặc ước lượng lịch giao hàng trong plan này. Hai quyết định phải đo trong giai đoạn tương ứng là model authoring thực đáp ứng nội dung và cơ chế audience output thực trên nền tảng đích; không cần chọn nhà cung cấp video AI để làm MVP.
