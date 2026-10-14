# Google Meet: cookie/WebView, duyệt trong HocLuc và tuỳ chọn OPEN

App chỉ dành cho giáo viên. Học sinh dùng link Google Meet bình thường, không cần tài khoản HocLuc hoặc cài app.

## Luồng mặc định: WebView/cookie và duyệt học sinh trong HocLuc

1. Đăng nhập HocLuc bằng tài khoản hiện có, bấm **Bắt đầu**. App vào Lobby và mở panel Meet trên Windows, không yêu cầu OAuth Client ID để tạo phòng bằng giao diện Meet.
2. Panel mở `https://meet.google.com/new` bằng profile WebView2. Đăng nhập Google trong panel nếu cookie chưa hợp lệ, rồi **tự bấm Tham gia ngay**. App nhận đúng mã phòng từ URL Google; việc nhận mã không có nghĩa giáo viên đã vào cuộc gọi hoặc có quyền chủ phòng.
3. Đóng panel để quay về bảng giảng dạy. App giữ controller/trang Meet đang chạy; không điều hướng về `about:blank` khi chỉ đóng panel. Cookie do WebView2 quản lý, không chuyển thành token OAuth giả.
4. Khi Meet hiển thị yêu cầu xin vào, bridge gửi snapshot từng yêu cầu có mã riêng theo document/dòng DOM, tên và thông tin phân biệt nếu có. Banner **Yêu cầu vào lớp** hiển thị ngay trên Studio, không cần mở tab Meet ngoài.
5. Giáo viên bấm **Cho vào** ở đúng học sinh. App gửi mã document/yêu cầu/lượt thao tác, kiểm tra dòng vẫn thuộc đúng người rồi bấm nút Admit/Chấp nhận/Bring in tương ứng. Bấm liên tiếp cùng yêu cầu chỉ tạo một lượt xử lý.
6. Chỉ báo thành công khi yêu cầu đã rời hàng chờ và có bằng chứng mới từ UI Meet rằng đúng người đã vào (participant ID hoặc tên duy nhất trong danh sách/notification tham gia). Chỉ bấm được nút hoặc hàng chờ biến mất chưa đủ chứng minh duyệt thành công.
7. Không xác nhận sau 8 giây phía bridge/10 giây phía app, tên trùng không đủ thông tin, document đổi, hoặc nút không truy cập được: giữ thông báo cần kiểm tra. Giáo viên mở panel Meet ngay trong app để xử lý/xác nhận hoặc đóng thông báo. Snapshot hàng chờ rỗng cập nhật bộ đếm về 0 nếu không còn thao tác chờ/chưa xác nhận.

Giáo viên phải đang ở trong cuộc họp và có quyền duyệt theo Google. Cấu hình Trusted/Open/waiting room của phòng quyết định có yêu cầu xin vào hay không; luồng cookie không tự cấu hình OPEN. Các nút cũ **Cho vào tất cả** không bấm hàng loạt theo chữ trên toàn trang nữa. Những control khác như mute/chat không thuộc phần xác nhận admission này.

Nếu Google chặn đăng nhập trong WebView hoặc runtime không hỗ trợ, có thể mở Meet ngoài/dán link; bridge điều khiển từ HocLuc cần phiên Meet thực sự hoạt động trong WebView. Cookie của Chrome/Edge ngoài không tự chuyển sang WebView2.

## Tuỳ chọn: tạo OPEN bằng OAuth + Meet API

1. Đăng nhập HocLuc bằng phương thức hiện có, hoặc chọn đăng nhập Google.
2. Trong Lobby, mở **Tuỳ chọn phòng học → Tạo phòng cho phép vào trực tiếp**. Nếu chưa kết nối Google, app mở trình duyệt hệ thống để giáo viên chọn tài khoản và cấp quyền Google Meet.
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

Test local dùng Google giả lập để kiểm tra code/PKCE, scope, hủy, callback sai state/replay, refresh token, body OPEN/ALL, xác nhận phản hồi, chống fallback và link chính xác. Bridge được kiểm tra bằng Playwright trên DOM giả lập (không gửi request Google) và test Flutter cho hàng chờ, xác nhận, timeout, trùng tên và callback cũ. DOM Google thật chưa được thu thập/xác minh cho adapter này.

Nghiệm thu bridge thật: giáo viên đăng nhập/join trong WebView bằng tài khoản có quyền chủ phòng; học sinh ở trình duyệt/tài khoản khác xin vào; đóng panel và giữ bảng HocLuc; kiểm tra banner đúng người; bấm Cho vào; xác nhận học sinh thật đã tham gia. Thử hai người, người rút yêu cầu và người trùng tên; kiểm tra thông báo không tự báo thành công khi chưa có bằng chứng. Test cookie còn giữ sau restart/nâng cấp app. Bước này không cần OAuth Client ID.

Nghiệm thu OPEN thật: cấp quyền bằng credentials đã cấu hình; tạo phòng qua menu tuỳ chọn; kiểm tra host dùng đúng tài khoản; dùng tài khoản học sinh khác hoặc phiên trình duyệt riêng tham gia bằng link; kiểm tra không cần duyệt theo cấu hình hiện hành. Test local/build không thay thế nghiệm thu Google thật.

Chạy test bridge từ thư mục `frontend`:

```powershell
flutter test test/meet_admission_service_test.dart test/studio_admission_banner_test.dart test/classroom_dashboard_test.dart
# Cần package Playwright trong Node module search path và Microsoft Edge.
node test/meet_admission_bridge.browser.cjs
```

Tài liệu Google: [Desktop OAuth và PKCE](https://developers.google.com/identity/protocols/oauth2/native-app), [spaces.create](https://developers.google.com/workspace/meet/api/reference/rest/v2/spaces/create), [SpaceConfig và AccessType](https://developers.google.com/workspace/meet/api/reference/rest/v2/spaces).
