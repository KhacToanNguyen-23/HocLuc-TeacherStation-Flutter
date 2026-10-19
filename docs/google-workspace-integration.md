# HocLuc: Classroom, Meet và Calendar

Giáo viên có thể đăng nhập bằng nút Google để kết nối API ngay từ đầu, hoặc mở **Lớp học & kết nối Google** trên dashboard. Đăng nhập email/OTP và đề thi giữ nguyên; tài khoản Google dùng OAuth, phiên Meet WebView được thiết lập khi cần dạy.

## Phân công

- Classroom: tạo lớp, mời email, đọc danh sách học sinh đã chấp nhận.
- Calendar: tạo sự kiện có `conferenceData.createRequest`, `conferenceDataVersion=1`, khách mời là email giáo viên đã chọn, `sendUpdates=all`. Link Meet lấy từ video entry point của sự kiện, không dán link phòng cũ vào location/description.
- Meet: phòng của buổi Calendar dùng trong Studio. Lớp cũ còn dữ liệu membership được giữ để tương thích, nhưng giao diện yêu cầu chuẩn bị buổi Calendar trước khi bắt đầu theo luồng mới.
- WebView2: mở đúng phòng, giáo viên chọn đúng tài khoản rồi tham gia; giữ các chức năng studio hiện có. Lớp liên kết không dùng auto-admit/duyệt tất cả.

Classroom course và sự kiện Calendar được liên kết trong dữ liệu HocLuc. Đây không phải thao tác tạo nút Meet nguyên bản trên giao diện Classroom. HocLuc không gọi một API không tồn tại để tạo nút đó.

## Cấu hình dành cho người phát triển/cài đặt

Giáo viên không cần Google Cloud hoặc Client ID riêng. Người phân phối ứng dụng chuẩn bị Google Cloud project, bật **Google Classroom API**, **Google Meet API**, **Google Calendar API**, cấu hình consent screen và tài khoản thử trước khi phát hành.

Tạo OAuth client loại **Desktop app** cho Windows, dùng trình duyệt hệ thống và PKCE; không nhúng một web-client secret có tính bảo mật vào bản phân phối desktop. Với client Desktop, secret trong tệp Google cung cấp có thể cần truyền khi đổi mã; secret này không phải bằng chứng bảo mật của ứng dụng native. Khai báo các scope theo `GoogleConnectionService.SCOPES`, chỉ xin thêm quyền khi triển khai thêm tính năng. Ứng dụng phát hành có thể cần Google xác minh các scope và quản trị viên Workspace cho phép.

Đặt các biến cho tiến trình backend:

| Biến | Ý nghĩa |
|---|---|
| `HOC_LUC_GOOGLE_CLIENT_ID` | OAuth client của HocLuc |
| `HOC_LUC_GOOGLE_CLIENT_SECRET` | Giá trị đi kèm client nếu Google yêu cầu; không gửi cho frontend |
| `HOC_LUC_GOOGLE_REDIRECT_URI` | Mặc định `http://127.0.0.1:47831/api/integrations/google/callback` |
| `HOC_LUC_GOOGLE_ENCRYPTION_KEY` | Base64 của 32 byte ngẫu nhiên; ổn định qua các lần chạy, lưu ngoài Git |

Sinh khóa một lần bằng PowerShell, lưu vào nơi triển khai bí mật; không commit hoặc gửi khóa qua chat:

```powershell
$googleKeyBytes = New-Object byte[] 32
$googleKeyGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$googleKeyGenerator.GetBytes($googleKeyBytes)
$googleKeyGenerator.Dispose()
$env:HOC_LUC_GOOGLE_ENCRYPTION_KEY = [Convert]::ToBase64String($googleKeyBytes)
```

Khóa cần được cấp lại cho backend ở lần chạy tiếp theo bằng cơ chế cấu hình riêng của bản cài. Mất/thay khóa sẽ làm token đã lưu không đọc được. Không ghi token/secret vào `application.properties`, SharedPreferences hoặc log. Khi chưa cấu hình, giao diện báo rõ và vô hiệu hóa kết nối; không giả thành công.

## Dữ liệu và trạng thái

Flyway V3 bổ sung hai bảng riêng trong schema hiện có: `google_connections` chứa credentials mã hóa AES-GCM, `google_courses` lưu ánh xạ subject/course/space, trạng thái lời mời, quyền Meet và các lịch đã gửi. Không sửa migration cũ. OAuth state + PKCE + poll proof dùng một lần, hết hạn sau 5 phút; callback chỉ nhận từ loopback. Các thao tác khác cần companion session, email giáo viên và nguồn local. Đây là mô hình companion cá nhân trên một máy, không phải backend nhiều người dùng qua Internet.

Refresh token chỉ được dùng ở backend. Danh tính OAuth đã được Google xác minh xác định tài khoản HocLuc; email cũ chỉ là gợi ý, không chặn chọn tài khoản khác. Phiên WebView vẫn riêng; ứng dụng nhắc kiểm tra cùng tài khoản trước khi mở phòng, không tuyên bố xác minh danh tính WebView qua DOM.

## Thao tác

1. Kết nối Google trong HocLuc; chọn đúng tài khoản và cấp đủ quyền trên trình duyệt hệ thống.
2. Tạo lớp, mỗi lần mời tối đa 50 email; mỗi email có trạng thái lỗi riêng nếu Google từ chối.
   Với Gmail cá nhân, Google có thể yêu cầu chấp nhận lớp `PROVISIONED` trong Classroom. Lỗi Classroom không chặn chuẩn bị buổi Calendar hoặc mời email vào sự kiện.
3. Bấm **Bắt đầu dạy**. HocLuc tự tìm lại buổi đang mở, hoặc sự kiện đang diễn ra/sẽ bắt đầu trong 15 phút. Nếu chưa có buổi phù hợp, tự tạo buổi Calendar 90 phút và gửi lời mời tới danh sách email được chọn; không cần nút chuẩn bị riêng. **Lên lịch học** vẫn cho chọn ngày giờ và thời lượng trước.
4. Giao diện hiện **Đang chuẩn bị phòng…**, tự kiểm tra lại hội nghị pending tối đa 10 lần, cách nhau 2 giây, rồi mở Studio khi có link và danh sách khách đã xác nhận. Lỗi hiện **Thử lại**, dùng lại request ID và sự kiện đã lưu. Không quay lại link Meet cũ khi lỗi. **Đồng bộ** nằm trong menu **Thao tác khác**. Mỗi sự kiện có Meet riêng, không sao chép conference data giữa các sự kiện.
5. Học sinh dùng **link mới**, đăng nhập đúng email đã mời. Trạng thái **Có trong lời mời Calendar** chỉ xác nhận danh sách khách mời, không khẳng định email đã được giao hoặc học sinh chắc chắn vào không cần duyệt. Khả năng no-knock còn phải nghiệm thu trực tiếp với Gmail/Workspace đang dùng.
6. **Bắt đầu dạy** đồng bộ lại rồi vào thẳng Studio. Panel Meet bên phải chứa luôn bước chọn tài khoản, mic/camera và tham gia; không mở cửa sổ Meet trung gian hoặc lobby. Chỉ khi bridge báo đã tham gia đúng URL, app mới đăng ký phiên dạy với backend. Có link phòng không đồng nghĩa đang dạy.

## Một luồng vào lớp

- Dashboard **Chọn lớp để dạy** mở danh sách lớp. **Bắt đầu dạy** tự chuẩn bị buổi phù hợp; bấm khi Studio cùng phòng đang mở sẽ **Tiếp tục dạy** ngay. Buổi đã kết thúc trong lịch sử HocLuc không được tái sử dụng dù chưa hết thời lượng Calendar; buổi đang dạy quá giờ giữ nguyên phòng. **Dạy buổi lẻ** giữ luồng riêng.
- Các đường chọn lớp, mở lại buổi học, dạy từ bài giảng và dán link đều dùng `TeachingLauncher`. Phòng của lớp liên kết không có fallback sang `meet.google.com/new`.
- Một Studio cho một buổi đang mở. **Về danh sách lớp (giữ buổi học)** giữ route, bảng và controller Meet. Bấm cùng lớp quay về đúng Studio đó, không tải lại WebView. Đây là về danh sách trong ứng dụng, không phải rời cuộc gọi Meet.
- Chọn lớp khác cần xác nhận kết thúc buổi cũ. Chờ thao tác ghi nhận đang chạy hoàn tất, kết thúc session backend, đóng controller cũ rồi mở lớp mới; route trung gian bị dọn khỏi stack.
- Backend tái sử dụng ID/thời điểm bắt đầu khi đăng ký lại cùng phòng, từ chối ghi đè buổi khác bằng HTTP 409. Yêu cầu kết thúc với ID cũ không được đóng buổi mới.
- Trạng thái phiên sau khi khởi động lại app dựa trên backend, còn nét vẽ đang giữ trong RAM chỉ được giữ khi route Studio chưa bị hủy; cần lưu bài trước khi đóng hẳn ứng dụng.

Luồng Calendar không gọi Meet API để sửa accessType hay thêm co-host. Scope `calendar.events.owned` hiện có được dùng để tạo/cập nhật sự kiện. Scope `meetings.space.created` chỉ dùng cho luồng phòng cũ do ứng dụng tạo. Không mặc định scope này có quyền sửa phòng do Calendar tạo. Membership cũ không phải bằng chứng đã vào cuộc gọi; giao diện ghi **Đã lưu membership** để tránh khẳng định sai.

## Lỗi và retry

- Request ID ổn định trong cùng biểu mẫu tạo lớp và gửi lịch; Classroom project alias và Calendar event ID giúp retry không tạo trùng sau lỗi mạng.
- Mời thất bại có thể mời lại bằng panel Mời học sinh. Lời mời đang mở không bị gửi lại hàng loạt mỗi lần đồng bộ.
- Meet creation không có request ID đảm bảo exactly-once. Nếu mất phản hồi hoặc Google 5xx, HocLuc ghi `meetCreationUncertain`, không tự tạo phòng khác. Người cài đặt cần đối soát kết quả bằng tài khoản Google và dữ liệu ánh xạ trước khi tiếp tục. Không tự cấp quyền cho phòng khác.
- Đồng bộ là thao tác chủ động. Khi thêm/gỡ email, HocLuc cập nhật khách mời của **sự kiện Calendar đang chọn**, gửi cập nhật và đọc lại danh sách; không tự sửa các buổi lịch sử. Khách được thêm ngoài HocLuc được giữ nguyên.
- Gỡ khách mời không đuổi người đang trong cuộc gọi, không thu hồi các quyền vào từ tổ chức/chính sách Google khác hoặc membership của phòng cũ. Không tuyên bố chỉ danh sách HocLuc có thể vào.
- Lưu event ID và request body trước khi POST. Sau timeout/409, đọc lại đúng sự kiện và kiểm tra chủ sở hữu HocLuc, thời gian, danh sách khách, hội nghị trước khi dùng link. Hội nghị pending không được tự tạo một sự kiện khác. Buổi hết giờ không được khởi động lại như buổi mới.
- Ngắt kết nối thu hồi OAuth rồi xóa token local; không xóa lớp, phòng hoặc lịch Google.

## Chia sẻ màn hình trong Meet trên Windows

UnityCapture và luồng camera ảo đã được gỡ bỏ. WebView2 sử dụng camera/microphone thật và hộp chọn chia sẻ của trình duyệt, không bật fake media hoặc tự chọn nguồn phát.

Quyền camera/microphone (và đọc bộ nhớ tạm nếu Meet yêu cầu) được hỏi bằng hộp thoại Flutter **Cho phép / Không cho phép**, nằm trên cả panel Meet nhỏ. Ứng dụng chuyển quyết định trực tiếp qua callback `permissionRequested` của WebView2 để tránh popup trình duyệt không nhận được click trong texture nhúng. Chỉ origin HTTPS chính xác `meet.google.com` có thể hiện hộp hỏi này; quyền không hỗ trợ và yêu cầu từ origin khác bị từ chối. Đóng hộp hỏi hoặc đóng khung Meet cuối cùng sẽ trả về từ chối; nếu vẫn còn khung Meet khác dùng cùng phiên, callback cấp quyền vẫn hoạt động. Hộp chọn màn hình/cửa sổ là UI riêng của trình duyệt, không phải hộp cấp quyền camera/microphone.

1. Khởi động lại ứng dụng sau khi cập nhật để WebView2 nhận cấu hình mới.
2. Vào phòng Meet trong panel bên phải. Bấm **Trình bày ngay / Present now** trực tiếp trong trang Meet.
3. Chọn cửa sổ hoặc màn hình trong hộp chọn của trình duyệt, rồi bấm **Chia sẻ / Share**. Nếu hộp chọn không vừa panel, dùng nút **Phóng lớn Meet trong ứng dụng** trước khi trình bày.
4. Dừng bằng nút của Meet hoặc trình duyệt. Tạm rời/kết thúc lớp cũng yêu cầu dừng các track chia sẻ. Webcam/PIP trên bảng vẫn là tính năng riêng; chọn thiết bị thật trong cài đặt Meet nếu muốn truyền webcam/microphone.

Trạng thái **Đang chia sẻ màn hình** chỉ xuất hiện sau khi `getDisplayMedia` trả về video track đang chạy; bấm nút hoặc hủy hộp chọn không được coi là đã phát. Chia sẻ cửa sổ/màn hình truyền cả nội dung nguồn đó; không còn chế độ tự crop chỉ vùng bảng qua camera ảo.

Kiểm thử tự động kiểm tra vòng đời stream, hủy chọn, dừng track, xử lý trạng thái và kiến trúc. Vẫn cần kiểm chứng trực tiếp với tài khoản Meet trên Windows: panel nhỏ và phóng lớn, chọn đúng cửa sổ HocLuc, hủy rồi chia sẻ lại, dừng từ trình duyệt, và xác nhận bên học sinh nhận được hình/âm thanh đã chọn. Không coi các fixture tự động là bằng chứng của cuộc gọi Google thật.

## Kiểm chứng

Luồng Google thống nhất: nút Google ở màn đăng nhập mở OAuth trong trình duyệt hệ thống. Tài khoản có email đã được Google xác minh trở thành danh tính HocLuc; không cần đăng nhập WebView trước và không lưu Google token ở Flutter. Màn lớp dùng lại kết nối đã lưu, backend tự gia hạn access token. Nút “Cấp quyền lại” chủ động yêu cầu consent để sửa quyền bị thiếu/thu hồi. Đổi tài khoản trong OAuth cập nhật danh tính và tải lại lớp của tài khoản mới. Phiên đăng nhập Meet WebView vẫn độc lập; lần đầu có thể cần đăng nhập cùng tài khoản, các lần sau giữ cookie. Không chuyển token OAuth thành cookie Meet. Cloud ở chế độ Testing có thể cấp refresh token hết hạn sau 7 ngày.

Trạng thái kết nối trả về `NOT_CONFIGURED`, `DISCONNECTED`, `CONNECTED`, `REAUTH_REQUIRED`, `TEMPORARY_ERROR` hoặc `CONFIG_ERROR`. Kiểm tra kết nối xác nhận access token bằng userinfo; nếu access token hết hạn, thử gia hạn một lần. `invalid_grant` yêu cầu cấp quyền lại; lỗi mạng, giới hạn tần suất và lỗi máy chủ không xóa grant và cho phép thử lại. `invalid_client` báo lỗi cấu hình của ứng dụng, không yêu cầu giáo viên đăng nhập lại. Không trả nội dung lỗi Google thô về Flutter.

Các thao tác tách riêng: **Kiểm tra kết nối/Thử lại** không mở trình duyệt; **Đổi tài khoản** dùng account picker; **Cấp quyền lại** ép consent; **Ngắt kết nối** thu hồi token ở Google rồi xóa credentials local, giữ lớp/lịch đã tạo. Đăng xuất HocLuc không thu hồi OAuth. Đổi tài khoản hoặc ngắt kết nối bị chặn khi Studio, phòng Meet hoặc phiên dạy backend còn mở; giáo viên trở về lưu bài và kết thúc buổi trước. Hủy đổi tài khoản hoặc lỗi OAuth giữ nguyên danh tính/lớp hiện tại. Sau khi đổi thành công, xóa danh sách lớp cũ và tải theo tài khoản mới; app vẫn nhắc chọn đúng tài khoản trong WebView vì cookie Meet không tự đổi theo OAuth.

Backend tests dùng H2 trong RAM và GoogleGateway giả lập. Flutter tests dùng HTTP giả lập để kiểm tra trạng thái, lỗi và nhiều chiều rộng. Chúng không xác nhận cấu hình Cloud, email thực sự được giao, account picker WebView, chính sách Workspace hay vào Meet thực tế.

Để nghiệm thu: dùng một giáo viên và tài khoản học sinh được mời/chưa chấp nhận/đã chấp nhận/ngoài lớp; kiểm tra Gmail cá nhân và Workspace nếu sản phẩm hỗ trợ cả hai. Chạy lại Windows app thật sau khi cấu hình OAuth, thử đổi tài khoản, từ chối một scope, token bị thu hồi, thêm/rời lớp và mở lại cùng phòng qua nhiều buổi. Không chạy backend thứ hai trên cùng file H2 đang bị khóa.

Nguồn: [Classroom invitations](https://developers.google.com/workspace/classroom/guides/manage-invitations), [Meet members](https://developers.google.com/workspace/meet/api/guides/meeting-space-members), [Desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app).


## Cấp quyền vào Meet theo email (không chờ Classroom)

- `meetAllowed` lưu lựa chọn của giáo viên. Thêm email hoặc bấm Cấp quyền Meet đặt true; Gỡ quyền Meet đặt false. Đồng bộ Classroom không bật lại quyền đã gỡ và không tự cấp cho thành viên chỉ được nhập từ roster.
- Tạo member với `ROLE_UNSPECIFIED`, không cấp COHOST. Đọc đầy đủ danh sách membership sau POST/DELETE để xác nhận; chỉ báo GRANTED khi có đúng email và resource thuộc đúng space. Lỗi API/không đọc lại được thì hiện trạng thái lỗi, chặn bắt đầu dạy. Không đánh đồng việc bấm nút với việc người học thực sự đã tham gia.
- Khi chuyển dữ liệu cũ, khôi phục quyền từ intendedEmails, invitationId hoặc bản ghi lời mời do app tạo. Với email chỉ có trong roster hoặc không có bằng chứng nhập từ app, giáo viên kiểm tra và bấm Cấp quyền Meet nếu cần.
- Chỉ xóa membership có dấu grantAttempted của HocLuc. Membership có sẵn ngoài app không tự xóa; app hiển thị EXTERNAL_ACCESS để giáo viên xử lý trong Google. Không gán COHOST và không bật bot duyệt tất cả.
- Lỗi hoặc chờ kích hoạt Classroom nằm trong classroomWarnings, không chặn quyền Meet. Email trong danh sách có thể vào khi chưa chấp nhận lời mời Classroom. Lịch Calendar hiện chỉ là thông báo chứa URL, không dùng làm bằng chứng được phép vào Meet và không tự tạo thêm conference.
- Kiểm thử thủ công: giáo viên bấm Đồng bộ trên lớp cũ hoặc Thêm email; đợi email hiện Đã cấp quyền. Học sinh đăng nhập đúng email, mở đúng link của lớp khi giáo viên đã ở trong phòng. Thử email chưa chấp nhận Classroom, email ngoài danh sách, gỡ/cấp lại quyền và kiểm tra lỗi Google theo email. Việc gỡ không đuổi người đã trong cuộc gọi và không xóa các quyền Calendar/Meet khác.


### Lỗi 400 khi đổi chế độ phòng

Kiểm tra thực tế ngày 15/10/2026 trên lớp Toán 12A1: GET space và LIST members thành công; PATCH Restricted trả HTTP 400, trạng thái FAILED_PRECONDITION, tính năng không khả dụng/chưa đủ điều kiện. Không coi đây là mất OAuth hay khuyên cấp quyền lại. Chỉ cho phép fallback trên phòng Trusted khi có lỗi precondition rõ ràng; lỗi mạng hoặc thiếu quyền khác vẫn báo lỗi. Với tạo phòng mới, chỉ thử Trusted sau một phản hồi precondition rõ ràng của lần tạo Restricted, không thử lại khi kết quả tạo chưa xác định. Sau khi sửa, cả hai email đã được Google trả về trong membership; chưa xác nhận việc học sinh thực sự vào cuộc gọi không cần duyệt.
