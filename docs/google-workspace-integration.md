# HocLuc: Classroom, Meet và Calendar

Giáo viên có thể đăng nhập bằng nút Google để kết nối API ngay từ đầu, hoặc mở **Lớp học & kết nối Google** trên dashboard. Đăng nhập email/OTP và đề thi giữ nguyên; tài khoản Google dùng OAuth, phiên Meet WebView được thiết lập khi cần dạy.

## Phân công

- Classroom: tạo lớp, mời email, đọc danh sách học sinh đã chấp nhận.
- Meet: tạo một space do HocLuc quản lý, cấp membership thường cho học sinh đã vào Classroom, gỡ membership do HocLuc quản lý khi học sinh rời lớp.
- Calendar: tạo lịch kèm link Meet đã có, `sendUpdates=all`, không tạo một Meet khác.
- WebView2: mở đúng phòng, giáo viên chọn đúng tài khoản rồi tham gia; giữ các chức năng studio hiện có. Lớp liên kết không dùng auto-admit/duyệt tất cả.

Classroom course và Meet space được liên kết trong dữ liệu HocLuc. Đây không phải thao tác tạo nút Meet nguyên bản trên giao diện Classroom. HocLuc không gọi một API không tồn tại để tạo nút đó.

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
   Với Gmail cá nhân, Google không cho tạo trực tiếp lớp `ACTIVE`. HocLuc tạo `PROVISIONED`, sau đó yêu cầu kích hoạt qua API. Nếu Google từ chối kích hoạt, app giữ lớp đã tạo và hiện hướng dẫn **Mở Classroom → chấp nhận lớp → Đồng bộ**; chưa gửi lời mời hoặc tạo phòng trong lúc chờ. Đây là giới hạn của Google đối với tài khoản, không phải lỗi OAuth.
3. Học sinh mở lời mời trên Classroom và chấp nhận một lần. Việc API trả invitation không phải xác nhận email đã được giao tới hộp thư.
4. Bấm **Đồng bộ** sau khi học sinh tham gia. HocLuc đọc hết các trang roster trước khi thay quyền Meet. Danh sách chưa hoàn tất sẽ không dùng để thu hồi quyền.
5. **Lên lịch học** chọn giờ trên máy và thời lượng. Google Calendar nhận yêu cầu gửi lịch cho các thành viên đã tham gia; giao diện không khẳng định email đã đến hộp thư.
6. **Bắt đầu dạy** đồng bộ lại rồi vào thẳng Studio. Panel Meet bên phải chứa luôn bước chọn tài khoản, mic/camera và tham gia; không mở cửa sổ Meet trung gian hoặc lobby. Chỉ khi bridge báo đã tham gia đúng URL, app mới đăng ký phiên dạy với backend. Có link phòng không đồng nghĩa đang dạy.

## Một luồng vào lớp

- Dashboard **Chọn lớp để dạy** mở danh sách lớp. **Dạy buổi lẻ** là lựa chọn riêng, chỉ lựa chọn này mới tạo Meet mới.
- Các đường chọn lớp, mở lại buổi học, dạy từ bài giảng và dán link đều dùng `TeachingLauncher`. Phòng của lớp liên kết không có fallback sang `meet.google.com/new`.
- Một Studio cho một buổi đang mở. **Về danh sách lớp (giữ buổi học)** giữ route, bảng và controller Meet. Bấm cùng lớp quay về đúng Studio đó, không tải lại WebView. Đây là về danh sách trong ứng dụng, không phải rời cuộc gọi Meet.
- Chọn lớp khác cần xác nhận kết thúc buổi cũ. Chờ thao tác ghi nhận đang chạy hoàn tất, kết thúc session backend, đóng controller cũ rồi mở lớp mới; route trung gian bị dọn khỏi stack.
- Backend tái sử dụng ID/thời điểm bắt đầu khi đăng ký lại cùng phòng, từ chối ghi đè buổi khác bằng HTTP 409. Yêu cầu kết thúc với ID cũ không được đóng buổi mới.
- Trạng thái phiên sau khi khởi động lại app dựa trên backend, còn nét vẽ đang giữ trong RAM chỉ được giữ khi route Studio chưa bị hủy; cần lưu bài trước khi đóng hẳn ứng dụng.

Scope `meetings.space.created` chỉ dùng cho các phòng do ứng dụng tạo; không giả định quyền trên một phòng do Classroom tạo ngoài app. Mặc định xin `TRUSTED`, đọc lại cấu hình thực tế; không tự mở `OPEN`. Tài khoản cùng tổ chức có thể vào theo chính sách TRUSTED. Học sinh không phải co-host. Membership được cấp không phải bằng chứng đã vào cuộc gọi.

## Lỗi và retry

- Request ID ổn định trong cùng biểu mẫu tạo lớp và gửi lịch; Classroom project alias và Calendar event ID giúp retry không tạo trùng sau lỗi mạng.
- Mời thất bại có thể mời lại bằng panel Mời học sinh. Lời mời đang mở không bị gửi lại hàng loạt mỗi lần đồng bộ.
- Meet creation không có request ID đảm bảo exactly-once. Nếu mất phản hồi hoặc Google 5xx, HocLuc ghi `meetCreationUncertain`, không tự tạo phòng khác. Người cài đặt cần đối soát kết quả bằng tài khoản Google và dữ liệu ánh xạ trước khi tiếp tục. Không tự cấp quyền cho phòng khác.
- Đồng bộ là thao tác chủ động, không phải push realtime. Lịch đã gửi không tự được cập nhật khi có thành viên mới/rời lớp.
- Gỡ membership không đuổi người đang trong cuộc gọi, không thu hồi lời mời Calendar cũ hoặc các quyền vào từ tổ chức/chính sách khác. Cần xử lý trong Meet/Calendar nếu muốn thu hồi toàn bộ các đường vào.
- Ngắt kết nối thu hồi OAuth rồi xóa token local; không xóa lớp, phòng hoặc lịch Google.

## Kiểm chứng

Luồng Google thống nhất: nút Google ở màn đăng nhập mở OAuth trong trình duyệt hệ thống. Tài khoản có email đã được Google xác minh trở thành danh tính HocLuc; không cần đăng nhập WebView trước và không lưu Google token ở Flutter. Màn lớp dùng lại kết nối đã lưu, backend tự gia hạn access token. Nút “Cấp quyền lại” chủ động yêu cầu consent để sửa quyền bị thiếu/thu hồi. Đổi tài khoản trong OAuth cập nhật danh tính và tải lại lớp của tài khoản mới. Phiên đăng nhập Meet WebView vẫn độc lập; lần đầu có thể cần đăng nhập cùng tài khoản, các lần sau giữ cookie. Không chuyển token OAuth thành cookie Meet. Cloud ở chế độ Testing có thể cấp refresh token hết hạn sau 7 ngày.

Trạng thái kết nối trả về `NOT_CONFIGURED`, `DISCONNECTED`, `CONNECTED`, `REAUTH_REQUIRED`, `TEMPORARY_ERROR` hoặc `CONFIG_ERROR`. Kiểm tra kết nối xác nhận access token bằng userinfo; nếu access token hết hạn, thử gia hạn một lần. `invalid_grant` yêu cầu cấp quyền lại; lỗi mạng, giới hạn tần suất và lỗi máy chủ không xóa grant và cho phép thử lại. `invalid_client` báo lỗi cấu hình của ứng dụng, không yêu cầu giáo viên đăng nhập lại. Không trả nội dung lỗi Google thô về Flutter.

Các thao tác tách riêng: **Kiểm tra kết nối/Thử lại** không mở trình duyệt; **Đổi tài khoản** dùng account picker; **Cấp quyền lại** ép consent; **Ngắt kết nối** thu hồi token ở Google rồi xóa credentials local, giữ lớp/lịch đã tạo. Đăng xuất HocLuc không thu hồi OAuth. Đổi tài khoản hoặc ngắt kết nối bị chặn khi Studio, phòng Meet hoặc phiên dạy backend còn mở; giáo viên trở về lưu bài và kết thúc buổi trước. Hủy đổi tài khoản hoặc lỗi OAuth giữ nguyên danh tính/lớp hiện tại. Sau khi đổi thành công, xóa danh sách lớp cũ và tải theo tài khoản mới; app vẫn nhắc chọn đúng tài khoản trong WebView vì cookie Meet không tự đổi theo OAuth.

Backend tests dùng H2 trong RAM và GoogleGateway giả lập. Flutter tests dùng HTTP giả lập để kiểm tra trạng thái, lỗi và nhiều chiều rộng. Chúng không xác nhận cấu hình Cloud, email thực sự được giao, account picker WebView, chính sách Workspace hay vào Meet thực tế.

Để nghiệm thu: dùng một giáo viên và tài khoản học sinh được mời/chưa chấp nhận/đã chấp nhận/ngoài lớp; kiểm tra Gmail cá nhân và Workspace nếu sản phẩm hỗ trợ cả hai. Chạy lại Windows app thật sau khi cấu hình OAuth, thử đổi tài khoản, từ chối một scope, token bị thu hồi, thêm/rời lớp và mở lại cùng phòng qua nhiều buổi. Không chạy backend thứ hai trên cùng file H2 đang bị khóa.

Nguồn: [Classroom invitations](https://developers.google.com/workspace/classroom/guides/manage-invitations), [Meet members](https://developers.google.com/workspace/meet/api/guides/meeting-space-members), [Desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app).
