# Google Meet: OAuth của giáo viên và phòng OPEN

App chỉ dành cho giáo viên. Học sinh dùng link Google Meet bình thường, không cần tài khoản HocLuc hoặc cài app.

## Luồng sử dụng

1. Đăng nhập HocLuc bằng phương thức hiện có, hoặc chọn đăng nhập Google.
2. Bấm **Bắt đầu**. Nếu chưa kết nối Google, app mở trình duyệt hệ thống để giáo viên chọn tài khoản và cấp quyền Google Meet.
3. Backend dùng authorization code + PKCE, kiểm tra scope `https://www.googleapis.com/auth/meetings.space.created` và lấy thông tin tài khoản từ Google.
4. Backend gọi `POST https://meet.googleapis.com/v2/spaces` với `config.accessType = OPEN`, `entryPointAccess = ALL`. Chỉ trả thành công khi Google xác nhận `OPEN` và cung cấp `meetingUri` hợp lệ.
5. Lobby mở panel Google Meet trên Windows với đúng `meetingUri`. Đăng nhập panel bằng tài khoản Google đã tạo phòng và chọn **Tham gia ngay**. OAuth và cookie đăng nhập của WebView2 là hai phiên riêng; OAuth không tự đăng nhập vào giao diện Meet.
6. Sao chép link gửi học sinh. Trong Studio, vào tab **Trực tiếp → Mở panel Google Meet** để dùng giao diện chính thức của Meet: quyền tham gia, duyệt người chờ, quản lý học sinh và micro theo quyền Google cho phép. Đóng panel chỉ ẩn giao diện, không hủy phòng; mở lại dùng cùng WebView đang có.

Đăng nhập HocLuc bằng mật khẩu/OTP vẫn giữ nguyên tài khoản và token local khi liên kết Google. Tài khoản demo và marker WebView từ bản cũ không được coi là OAuth hợp lệ. Link dán vào app giữ cấu hình vốn có của Google; app không gắn nhãn OPEN cho link chưa xác minh.

## Cấu hình Google Cloud trên máy giáo viên

Trong Google Cloud project, bật **Google Meet REST API**, cấu hình OAuth consent screen và tạo OAuth client loại **Desktop app**. Khi project ở chế độ Testing, thêm tài khoản giáo viên vào Test users. Cấp scope Meet bên trên cùng `openid email profile`. Quyền này vẫn chịu chính sách Workspace của tổ chức.

Không dùng client loại Web với callback động này. Luồng Desktop sử dụng callback `http://127.0.0.1:<cổng động>/oauth/callback` và trình duyệt hệ thống, không dùng OAuth trong WebView.

Nếu đã tải file credentials JSON của Desktop app, để file ngoài repo, rồi chạy trong PowerShell dùng để khởi động app:

```powershell
$googleCredentialsPath = 'D:\Secrets\hocluc-google-desktop.json'
$googleCredentials = Get-Content -LiteralPath $googleCredentialsPath -Raw | ConvertFrom-Json
if (-not $googleCredentials.installed.client_id) { throw 'Cần credentials JSON loại Desktop app (installed).' }
$env:GOOGLE_OAUTH_CLIENT_ID = $googleCredentials.installed.client_id
$env:GOOGLE_OAUTH_CLIENT_SECRET = $googleCredentials.installed.client_secret
Set-Location D:\Projects\HocLuc-Teacher
# Dừng service cũ do launcher này quản lý để service mới nhận cấu hình.
.\Start.ps1 -Mode Stop
.\Start.ps1 -Mode Windows -FlutterPath 'D:\Tools\teaching-companion\flutter\bin\flutter.bat'
```

Hai biến môi trường chỉ áp dụng cho cửa sổ PowerShell này và các tiến trình được nó mở. Không in giá trị credentials, không commit JSON hoặc token. Có thể đặt `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET` trực tiếp thay vì đọc JSON.

Google access/refresh token và local grant handle được giữ trong bộ nhớ, không ghi vào SharedPreferences hoặc file dữ liệu lớp học. Token được gia hạn trong phiên backend; sau khi khởi động lại app/backend, hết 12 giờ không dùng, hoặc bị thu hồi quyền, cần kết nối Google lại. OAuth đang chờ hết hạn sau 5 phút. Đăng xuất gỡ grant khỏi backend, không thu hồi toàn bộ quyền của ứng dụng trên tài khoản Google.

## Giới hạn và kiểm thử thật

- Panel trong app dùng WebView2 trên Windows. Web preview/macOS/Linux mở cùng link trong trình duyệt, không nhúng Meet vào iframe.
- Nếu Google/WebView2 không cho đăng nhập hoặc không hỗ trợ thao tác trên máy, dùng nút mở cùng phòng trong trình duyệt. OAuth token không được chèn vào cookie/URL panel.
- Tạo OPEN bị Google từ chối hoặc trả cấu hình khác sẽ báo lỗi; không tự chuyển sang `/new` hoặc Calendar để tạo phòng chưa rõ quyền.
- Nhãn OPEN xác nhận cấu hình lúc tạo. Nếu giáo viên đổi quyền trong panel, Google Meet là nơi hiển thị cấu hình hiện tại. Không coi nhãn lúc tạo là bằng chứng quyền chưa từng thay đổi.
- Các nút bridge/chat của HocLuc còn phụ thuộc DOM Google Meet; panel chính thức là nơi xác nhận thao tác thật. Không coi danh sách local hay trạng thái Flutter là bằng chứng đã duyệt/tắt mic học sinh.
- Phòng được tạo sẵn; giáo viên tự chọn tham gia trong panel. Tạo phòng thành công không có nghĩa giáo viên đã vào cuộc họp. Thao tác kết thúc lớp hiện có trong HocLuc không tự gọi API kết thúc cuộc họp cho tất cả người tham gia.

Test local dùng Google giả lập để kiểm tra code/PKCE, scope, hủy, callback sai state/replay, refresh token, body OPEN/ALL, xác nhận phản hồi, chống fallback và link chính xác. Để nghiệm thu Google thật: cấp quyền bằng credentials đã cấu hình; tạo phòng; kiểm tra host dùng đúng tài khoản; dùng tài khoản học sinh khác hoặc phiên trình duyệt riêng tham gia bằng link; kiểm tra không cần duyệt và thử các nút quản lý trong panel. Test local/build không thay thế bước này.

Tài liệu Google: [Desktop OAuth và PKCE](https://developers.google.com/identity/protocols/oauth2/native-app), [spaces.create](https://developers.google.com/workspace/meet/api/reference/rest/v2/spaces/create), [SpaceConfig và AccessType](https://developers.google.com/workspace/meet/api/reference/rest/v2/spaces).
