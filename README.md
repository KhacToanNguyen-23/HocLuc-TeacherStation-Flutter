# Mộc · Teaching Studio

Khung thử phần mềm hỗ trợ giáo viên bằng **Flutter (Dart) + Java 17**. Có bản Windows portable mở bằng `.exe`, source runner Flutter Windows/macOS và bản preview web. Không có lab trong bản này.

## Clone và build trên máy mới

Repo chứa mã nguồn, lockfiles, fonts và script build. `dist/`, SDK/runtime tải về, dependency cache và dữ liệu bài giảng không nằm trong Git. Sau khi clone phải build một lần để có `.exe`; bản portable đã có trên máy phát triển vẫn được giữ nguyên.

Chuẩn bị **Flutter 3.47.7** (lockfile yêu cầu Flutter >=3.47.0 / Dart >=3.13.0), **JDK 17** có `java` và `jlink`, **Maven 3.9+**, **Node.js/npm** (khuyến nghị Node 22+; đã kiểm tra với Node 26.5.0). Thêm các công cụ vào PATH. Build portable dùng Windows 10/11 x64 và compiler .NET Framework 4.8 có sẵn ở đường dẫn hệ thống; không cần Visual Studio. Lần build đầu cần mạng và khoảng 3 GB dung lượng trống cho cache/output, thêm dung lượng cho Flutter SDK và dependency.

```powershell
git clone --branch codex/hocluc-teacher-desktop https://github.com/KhacToanNguyen-23/HocLuc-TeacherStation-Flutter.git
Set-Location .\HocLuc-TeacherStation-Flutter
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Windows.ps1
# Nếu Flutter chưa nằm trong PATH, dùng thay lệnh build ở trên:
# powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Windows.ps1 -FlutterPath C:\SDK\flutter\bin\flutter.bat
```

Script in đường dẫn `HocLuc-Teacher.exe` khi hoàn tất. Double-click file đó để mở app. Toàn bộ folder output cần đi kèm exe khi sao chép. Microsoft WebView2 runtime được pin trong script; nếu Microsoft ngừng cung cấp phiên bản đó, build sẽ dừng với thông báo cần cập nhật và kiểm chứng phiên bản mới.

Prototype UI ban đầu của repo được giữ tại [docs/legacy/teacher_station_prototype.dart](docs/legacy/teacher_station_prototype.dart); app hiện tại chạy từ `app/`, không dùng prototype này làm entrypoint.

## Mở app bằng double-click

Trong thư mục `dist/HocLuc-Teacher-Windows-x64`, double-click **`HocLuc-Teacher.exe`**. App tự mở giao diện và Java service riêng; đóng cửa sổ sẽ dừng service. Giữ toàn bộ thư mục portable bên cạnh exe khi sao chép sang nơi khác.

- Không cần terminal hoặc cài Java, Flutter, Node, Maven, Visual Studio hay WebView2 runtime để chạy. Bản portable có Java runtime và WebView2 Fixed Version đi kèm; yêu cầu Windows 10/11 x64 với .NET Framework 4.8.
- Giao diện, CanvasKit và fonts có sẵn trong bundle; có thể mở app khi offline. Kết nối Flat/Netless vẫn cần mạng.
- Bài/cấu hình của bản app được lưu tại `%LOCALAPPDATA%\HocLuc-Teacher\data`; logs tại `%LOCALAPPDATA%\HocLuc-Teacher\logs\desktop.log`. Thư mục bundle không chứa bài/ghi chú của người dùng.
- Đây là **Flutter web chạy trong cửa sổ WinForms/WebView2**, backend Java, không phải kết quả `flutter build windows`. Host Windows mỏng nằm ở `packaging/windows/Program.cs`. Không mở tab trình duyệt ngoài.
- Camera/mic ảo và AI streaming vẫn chưa được triển khai. Đóng gói `.exe` không làm các capability này tự hoạt động.
- Bản exe chưa ký số; chưa phải bộ cài tự cập nhật hoặc bản phát hành thương mại.

Build lại portable trên máy phát triển:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Windows.ps1
# Chỉ dùng khi đã build Flutter offline và whiteboard host mới nhất:
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Windows.ps1 -SkipFrontendBuild
```

Build tạo folder có timestamp trong `dist`; `.packaging/latest-output.txt` ghi đường dẫn output. `-CreateZip` tạo thêm zip để phân phối toàn bộ folder. SDK/runtime lấy từ NuGet Microsoft và API download Microsoft; cache build nằm trong `.packaging`. Java runtime được tạo bằng `jlink`, không cần quyền admin. Khi build mới muốn đặt tên cố định như bundle ban đầu, đổi tên toàn bộ folder output sau khi app đã đóng.

Kiểm tra chính file exe bằng test riêng, không ghi dữ liệu vào profile app của giáo viên:

```powershell
.\scripts\check-windows-package.ps1 -Bundle '<đường dẫn output>'
```

Test sao chép bundle sang đường dẫn có khoảng trắng, bỏ Java/Flutter khỏi PATH, chặn tài nguyên web bên ngoài, xác nhận Flutter đã render, lưu/đọc bài, đóng app bình thường và buộc dừng parent process. Ảnh và report được ghi vào `.packaging/package-check-*`.

## Những gì dùng thử được

- Đổi tên/môn bài giảng; chuyển giữa ba trang bảng nháp.
- Vẽ, đánh dấu, chọn màu, tẩy nét, hoàn tác và xóa nét trang hiện tại.
- Mở câu hỏi trắc nghiệm mẫu; ẩn/hiện đáp án; chạy/dừng đồng hồ hai phút.
- Ghi chú riêng; xem khung trình bày 16:9 không chứa ghi chú/cấu hình.
- Java liệt kê các thiết bị thu âm mà JavaSound nhận diện; chọn một thiết bị để lưu cấu hình. Chưa thu âm hoặc kiểm tra chất lượng mic.
- Nhập endpoint API AI riêng, chọn ngôn ngữ và tùy chọn lọc âm. Hiện chỉ lưu cấu hình, chưa gửi giọng hay gọi API.
- Lưu/tải lại bài, nét vẽ và cấu hình bằng Java API, dữ liệu ở `service/data/lesson.json` và `config.json`.
- Nút **Mở Flat** mở host của engine Fastboard cùng phiên bản trong Flat. Nhập app identifier, room UUID, room token và region để thử với session Netless hợp lệ. Token chỉ giữ trong bộ nhớ host, không lưu bằng nút Lưu bài.

**Bảng nháp mặc định là demo Flutter để thử luồng dùng, không phải whiteboard Flat đã được port.** Host Flat tái sử dụng engine/dependency và cách tạo/mount bảng từ `service-providers/fastboard`; chưa ghép toàn bộ store, file conversion/upload, session provisioning và các công cụ Flat vào shell mới. Host giữ mounted khi chuyển sang câu hỏi; chọn quay về Bảng nháp sẽ đóng host, lần sau phải nhập lại session.

## Chạy preview từ source trên Windows

Trong PowerShell, từ thư mục đã clone:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Start.ps1 -Mode Preview
```

Mở **http://127.0.0.1:47831**. Java chạy nền không mở cửa sổ console. Chỉ dùng `-SkipBuild` khi đã build source trên máy này và source chưa thay đổi:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Start.ps1 -Mode Preview -SkipBuild
```

Cần các công cụ ở mục Clone và build. Launcher tìm `flutter` trong PATH; có thể truyền `-FlutterPath` khi SDK ở nơi khác. Không đổi PATH hoặc execution policy toàn máy. Lần build đầu cần mạng để tải dependency và Flutter web renderer.

```powershell
.\Start.ps1 -Mode Status
.\Start.ps1 -Mode Stop
```

Logs ở `.run/service.log` và `service-error.log`. Dừng launcher chỉ dừng Java service thuộc launcher này; tab preview có thể đóng bình thường. Nếu PowerShell chặn chạy script, dùng cùng lệnh `powershell -NoProfile -ExecutionPolicy Bypass -File ...` cho Status/Stop.

## Build Flutter desktop native từ source (hướng khác với portable trên)

### Windows

Cần Visual Studio với workload **Desktop development with C++**, Flutter Windows toolchain và bật Windows Developer Mode để plugin tạo symlink. Host bảng cần Edge WebView2 Runtime. Sau khi `flutter doctor -v` xác nhận Windows toolchain:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Start.ps1 -Mode Windows
```

Java chạy nền; Flutter chạy app desktop. Đóng cửa sổ desktop rồi dùng `-Mode Stop` để dừng Java. Máy hiện tại chưa có Visual Studio và symlink support; **chưa build/chạy Flutter Windows native runner**. Bản portable `.exe` ở mục đầu dùng WebView2 host và không phụ thuộc toolchain này khi chạy.

### macOS

Cần máy Mac, Xcode, CocoaPods, Flutter, Java 17+, Maven và Node/npm. Trong thư mục `HocLuc-Teacher`, mở hai terminal:

```bash
# Terminal 1
bash start-macos.sh service
# Terminal 2
bash start-macos.sh app
```

Dừng từng terminal bằng Ctrl+C. Có runner macOS, network-client entitlement và host WKWebView; **chưa build/test trên Mac**. Native release sẽ cần JRE đóng gói, quản lý lifecycle sidecar Java, signing/notarization và installer riêng; đây chưa phải bộ cài phân phối.

## Cấu trúc và trách nhiệm

```text
app/                     Flutter UI + Windows/macOS/web runners
  lib/models/            trạng thái bài, nét demo, cấu hình
  lib/services/          client gọi Java API
  lib/widgets/           host Flat: iframe / WebView2 / WKWebView
service/                 Java HTTP service trên loopback, persistence, JavaSound inventory
whiteboard-host/         Fastboard host độc lập, không khởi tạo Agora RTC/RTM
scripts/check-service.mjs kiểm tra Java API qua tiến trình thật
scripts/check-windows-package.ps1 kiểm tra exe portable và lifecycle sidecar
packaging/windows/       WinForms/WebView2 host, runtime config và hướng dẫn portable
Build-Windows.ps1        đóng gói UI offline + Java runtime + WebView2 + exe
Start.ps1                build/start/status/stop cho Windows
start-macos.sh           entrypoint hai terminal trên Mac
```

Flutter viết bằng **Dart**; Java là dịch vụ riêng, không phải ngôn ngữ viết UI Flutter. UI và Java trao đổi JSON qua loopback; preview dev dùng `127.0.0.1:47831`, app portable chọn cổng trống riêng và UI dùng origin của chính phiên đó. Camera/audio frame tốc độ cao trong bản hoàn thiện cần đường media/native riêng, không đưa raw video qua REST JSON.

Fastboard dùng SDK web và Netless session. Tận dụng phần này trong Flutter cần WebView và bridge sự kiện; chưa có bảng Flat offline. Đây là chi phí tích hợp thêm so với tiếp tục Electron/React của Flat, nhưng Flutter + Java vẫn là cấu trúc khả thi nếu chấp nhận bridge đó.

## Ranh giới chưa triển khai

| Thành phần | Trạng thái |
| --- | --- |
| UI và Java lưu/tải bài | Đã triển khai trong khung thử |
| Windows portable exe | Đóng gói WinForms/WebView2 + Flutter web + Java runtime; kiểm chứng bằng test chính exe |
| Flutter Windows/macOS runners | Có source; chưa xác nhận native Flutter runtime |
| Bảng nháp Flutter | Demo tương tác và persistence |
| Host Fastboard | Bundle được; có màn nhập session; chưa kiểm chứng join bằng credentials thật |
| Camera vật lý | Chưa có capture/selection adapter |
| Capture microphone | Chưa có; JavaSound hiện chỉ liệt kê |
| Camera ảo / micro ảo | Chưa có native bridge/driver; API báo không hỗ trợ, không giả lập phát thành công |
| AI API streaming/lọc âm/dịch giọng | Chưa có; chỉ cấu hình endpoint của AI do bạn quản lý |
| Thu đáp án từ Meet | Chưa có; học sinh trả lời trong Meet, giáo viên đọc thủ công |
| Capture/export/publish khung Flat ra meeting | Chưa có; preview Flutter không nhân bản một session Flat khác |
| Lab | Không thuộc bản này |

Preview trình bày chỉ là khung riêng trong app, chưa tạo thiết bị để chọn trong Google Meet. UI không báo “đang phát” hay hiển thị độ trễ AI giả. Ghi chú riêng được loại khỏi widget preview; native capture boundary vẫn cần kiểm chứng khi phát triển bridge.

## API và kiểm tra

`GET /api/bootstrap` cấp token phiên cục bộ. Các API còn lại yêu cầu header `X-Companion-Token`. Browser chỉ được dùng origin loopback của service; service không mở ra LAN. Token đổi sau khi Java khởi động lại.

- `GET /api/capabilities`, `GET /api/devices`.
- `GET/PUT /api/lesson`, `GET/PUT /api/config`.
- `POST /api/output/start` trả **501**, vì chưa có virtual-device bridge.
- `/flat/` phục vụ whiteboard host; `/` phục vụ Flutter web đã build.

```powershell
mvn -q -f .\service\pom.xml package
node .\scripts\check-service.mjs
Set-Location .\app
flutter analyze --no-pub
flutter test --no-pub
```

Test API dùng thư mục tạm riêng, không ghi đè bài của giáo viên. Widget/state tests kiểm tra persistence, giữ thay đổi khi save lỗi/đang save, layout ba kích thước và preview không chứa field riêng. Đây không phải bằng chứng mic thật, Netless room thật, thiết bị ảo hoặc hoạt động trong Meet.

## Bước triển khai kế tiếp

1. Xác nhận Flutter native build Windows và Mac nếu chọn chuyển khỏi WebView2 host; bản portable đã quản lý lifecycle Java.
2. Nối Flat session provisioning và các capability bảng cần dùng; kiểm chứng WebView/capture trên hai OS.
3. Thêm camera/mic capture thật và native virtual-output bridge; thử thiết bị trong Meet.
4. Thống nhất contract AI API tự train rồi nối streaming, mute, reconnect và buffer dịch giọng.
5. PoC adapter thu chat Meet phía giáo viên nếu chọn scope này. Không yêu cầu app/web riêng cho học sinh.

Nguồn kỹ thuật: [Flutter desktop](https://docs.flutter.dev/platform-integration/desktop), [platform channels](https://docs.flutter.dev/platform-integration/platform-channels), [Windows WebView2 plugin](https://pub.dev/packages/webview_windows), [macOS WebView plugin](https://pub.dev/packages/webview_flutter).
