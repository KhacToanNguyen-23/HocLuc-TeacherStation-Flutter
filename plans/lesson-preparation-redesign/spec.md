# Đặc tả Soạn bài — DRAFT

Status: Implemented following user confirmation; final automated checks and manual acceptance tracked separately. Xem plan.md và docs/testing/lesson-preparation-redesign-uat.md.
Date: 2026-10-20.

## Success criteria và yêu cầu phi chức năng

- A01–A23 core/feature enabled phải PASS; 20 vòng mở/thoát bảng ở cả không edit và edit-save, không mất dữ liệu hoặc generic Bad state. A24 DOCX chỉ là gate khi bật optional feature.
- Không có notes/đáp án private trên receiver thật trong A17; unknown/unverified output fail closed. Bất kỳ leak hoặc account-crossing đều chặn release.
- >=80% workflow thử bởi 5–8 giáo viên hoàn tất không trợ giúp; ít nhất 4/5 người đầu xác định đúng audience. Đây là mục tiêu, chưa là số đo.
- Core soạn/notes/preview/PDF không cần provider AI hoặc speech runtime. Mất kết nối và auth failure giữ nháp, không báo server saved sai.
- Quy trình migration có backup, chạy lại idempotent, concurrent writers không mất scope. Mọi view hỗ trợ cửa sổ desktop hẹp bằng panel thu gọn, keyboard focus/labels và không overflow; đo hiệu năng baseline trước đặt ngân sách latency, chưa tự đặt con số không có căn cứ.

## Stories và thứ tự ưu tiên

| ID | Ưu tiên | Hành vi và giá trị | Accepted when |
|---|---|---|---|
| LP-R01 | P1 | Chuẩn bị bài đầy đủ hoặc một phần, không bắt form dài | Tạo, đổi tên một lần, thêm/sắp lại phần, mở lại giữ đúng dữ liệu |
| LP-R02 | P1 | Tận dụng PDF có sẵn, chỉ thêm lời nhắc | Import PDF, gắn note trang 3, không cần viết lại bài, mở lại note đúng trang |
| LP-R03 | P1 | Soạn nội dung và lời nhắc đúng ngữ cảnh | Chọn phần thấy nội dung, notes và tài liệu của phần đó; reorder không đổi liên kết |
| LP-R04 | P1 | Tin trạng thái lưu và trở lại bảng | Không báo đã lưu khi load/save thất bại; 20 vòng editor/bảng không mất dữ liệu |
| LP-R05 | P1 | Khi dạy biết nói/làm gì tiếp theo | Notes tự theo phần/trang, có ghim và trở về tự động; receiver không thấy notes |
| LP-R06 | P1 | Xem trước và xuất đúng đối tượng | Preview giáo viên/học sinh khớp PDF; bản học sinh không có notes/đáp án |
| LP-R07 | P2 | Dùng bài cũ, câu hỏi đã duyệt, biến thể theo lớp | Nhóm/ngữ cảnh/đáp án giữ nguyên; bản lớp chỉnh không ảnh hưởng gốc |
| LP-R08 | P2 | Gửi học liệu cho lớp trong app | Chọn đúng lớp/tệp, preview, publish có xác nhận kết quả; retry không đăng trùng |
| LP-R09 | P2 | Giảm thao tác với AI tùy chọn | Không cấu hình AI vẫn hoàn tất R01–06; AI trả draft duyệt được, không tự ghi đè |
| LP-R10 | P2 optional | Trao đổi giáo án có thể chỉnh trong Word | DOCX paragraph roundtrip qua compatibility gate; giữ bản gốc và báo mất định dạng |

## Hợp đồng tương tác

Tên bài nằm ở header duy nhất. Phần cơ bản chỉ có tên phần và vùng nội dung giáo viên muốn dạy. Thời gian, mục tiêu, câu hỏi kiểm tra, hoạt động học sinh và ghi chú là tùy chọn theo mục đích, mở dần; không bắt nhập các ô teacher/student/product cho mọi phần. Notes riêng có nhãn rõ, nằm cạnh nội dung đang soạn; không nằm trong nội dung học sinh mặc định.

Có thể lưu ghi chú gắn trang PDF mà không có giáo án văn bản. Bản có một phần và bài thuyết trình ngắn là dữ liệu hợp lệ. Thời lượng trống không bị giả thành 5 phút; tổng chỉ cộng giá trị đã nhập và báo phần chưa ước lượng.

## Dữ liệu và lưu

- Planning ID, page ID và activity ID ổn định. Material reference có ID, ownership, loại, source provenance và version; không dùng index trang làm khóa duy nhất.
- Cues tham chiếu `activityId` và active presentation locator: `board:{pageId}` hoặc `pdf:{documentId,contentFingerprint,pageIndex}`. PDF tài liệu và trang đang xem không đồng nhất với board page. Dùng importedPdfDocuments id/contentFingerprint/totalPages hiện có; PDF thay file/fingerprint phải remap có xác nhận, không tự gán notes theo số trang cũ. Reorder giữ ID; xóa yêu cầu xử lý notes/tài liệu orphan có lựa chọn và undo. Ghim notes chỉ là trạng thái presenter, không sửa mapping.
- Snapshot bảng là dữ liệu trình chiếu; nội dung giáo án có cấu trúc là subdocument riêng. Không tự tái tạo board rồi ghi đè nét viết/trang đã sửa khi nội dung giáo án thay đổi. Hành động cập nhật nội dung đã sinh phải có diff/preview và chọn phạm vi.
- Chọn trình tự trình chiếu rõ ràng, có stable locators. Projection phát sinh là derived snapshot có origin + source revision; preview không sửa canonical lesson/board. PreparationLiveProjection hiện ghép thêm section cards vào board copy; phải chặn teach-again tích lũy trang nếu live snapshot từng được lưu và đưa lại làm đầu vào. Không coi derived pages là source mới một cách âm thầm.
- Mọi writer board/preparation chung một cơ chế serialized atomic scoped merge ở lock thực tế của PlanningService, cùng revision/expectedRevision. Lock riêng controller không đủ. Board save chỉ cập nhật board scope, prep save chỉ prep scope; conflict không last-write-wins âm thầm. Atomic file write/transaction theo persistence thật, có recovery kiểm chứng.
- Migration schema version, backup trước đổi, idempotent; giữ ID cũ. Notes array theo vị trí migrate sang page ID từ snapshot gốc, báo rõ trường hợp không ánh xạ chắc chắn thay vì đoán.
- Local draft namespace theo account subject đã xác minh + planning ID; identity tạm chưa xác minh không được gắn vào dữ liệu server. Nháp chưa xác minh nằm khu vực tách biệt với explicit recovery sau xác minh, không tự nhập vào tài khoản khác.

## State machine nhìn thấy được

`loading`, `load_failed`, `ready_clean`, `dirty`, `saving`, `saved`, `offline_local`, `auth_required`, `conflict` là các trạng thái phân biệt. Chỉ nhận saved sau persistence ACK của đúng revision; local recovery ghi “Đã lưu trên máy”, không giả là server saved. Save failure giữ nội dung. Exit khi dirty cho Lưu / Tiếp tục chỉnh / Bỏ thay đổi chưa lưu; không dùng generic Bad state thay thao tác phục hồi.

Giữ phục hồi session HocLuc và flow Google WebView tương thích đang dùng; server vẫn yêu cầu verified session. Không ép đăng nhập lại vô điều kiện, không coi sentinel WebView là verified identity. Hết hạn → thử restore/refresh theo chính sách hiện có → chỉ reauth khi cần; quay lại đúng nháp sau xác thực.

## Audience và notes

Giáo viên có presenter panel trong app, theo trang/nội dung đang thật sự trình chiếu. Tách view/source học sinh với app điều khiển. Có manual pin, nhãn “Đang ghim”, reset về nội dung hiện tại, next/previous và tình trạng kết nối. Không mở panel riêng chỉ để né việc chuyển tab. Source chưa xác minh thì fail closed, giữ hàng rào StudioSpeakerNotesBar hiện có. Chia sẻ cả desktop không có bảo đảm privacy; không gắn nhãn “riêng tư an toàn” cho trường hợp đó.

Người dùng đã xác nhận auto-follow + ghim/chọn tay + trở về tự động. Active output locator dẫn việc chuyển notes; chọn phần để chỉnh trong editor không tự thay màn hình học sinh cho đến hành động trình chiếu. `currentPageNote` hiện theo index board nên chưa đủ cho PDF page; phải nối active locator thật.

Khi cả note phần và note trang cùng khớp, hiện hai khối có thứ tự “Ghi chú phần” rồi “Ghi chú trang”, không thay nhau âm thầm. Cùng PDF dùng ở hai hoạt động: page cue ưu tiên scope activityId hiện tại; page-global cue chỉ fallback và mang nhãn “Ghi chú chung của trang”. Mất activity association hoặc xóa source thì prompt xử lý orphan, không đoán theo tên/trang. Ghim hiển thị rõ context đã ghim; reset dùng actual output hiện thời.

## Traceability chức năng hiện có

| Chức năng cũ | Quyết định | Vị trí mới/điều kiện |
|---|---|---|
| Tạo/mở/tìm/nhân bản bài | Giữ, làm lại UX | Thư viện Soạn bài; cùng ID và dữ liệu |
| Form phần dài | Làm lại | Editor progressive, title chung một lần |
| Bảng & tài liệu | Làm lại hợp đồng | Chuẩn bị trình chiếu, return/save/reload rõ |
| Nguồn/script/transcript | Giữ, làm lại UX | Thêm nội dung tại phần/tài liệu; bước chọn đầu ra rõ |
| Tác vụ/học liệu | Tách UX | Status background và Tài liệu đã tạo có empty action |
| Notes giáo viên | Giữ, nối và kiểm chứng | Stable activity/page mapping và presenter |
| Kho câu hỏi đã duyệt | Giữ | Chèn tại phần, giữ context/group, đáp án private |
| Biến thể lớp, tái sử dụng | Giữ | Menu bài/phần, provenance và độc lập bản gốc |
| Reflection/history/revisions | Giữ | Sau buổi dạy và lịch sử phiên bản có diff |
| Template trường/khoa | Giữ | Mapping có preview, trường thiếu được báo |
| PDF học sinh/giáo viên | Giữ | Java native, không cần model/API; notes/đáp án tách |
| Classroom | Giữ, gate integration | Tất cả chọn lớp/tệp/trạng thái trong app; OAuth consent có thể cần trình duyệt ngoài |
| Authoring AI | Giữ tùy chọn | API configurable bên thứ ba; consent nội dung, draft review |
| STT/dịch/TTS | Giữ tùy chọn | Model local đã định hướng; trạng thái unavailable rõ |
| Video animation đơn giản | Để sau core, giữ dữ liệu | Công cụ phụ có kiểm thử riêng, không xóa chức năng |
| AI nhân vật/cảnh hoạt hình | Để sau | Không thuộc gate core |
| DOCX | P2 compatibility gate | Paragraph text import + editable export cơ bản, không hứa layout fidelity |
| PPTX | Attachment trước | Chưa preview/native edit; conversion nghiên cứu giai đoạn sau |

Không bao gồm portal học sinh, bắt học sinh cài app, hay thay Google Meet thông thường.
