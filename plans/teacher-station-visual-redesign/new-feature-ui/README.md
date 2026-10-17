# Đồng bộ diện mạo các chức năng mới từ develop

Đã áp dụng hệ thiết kế HocLucStation cho các phần UI mới từ `develop` tại `ef70426`. Giữ bố cục, kích thước vùng làm việc, callback, điều hướng và hợp đồng dữ liệu hiện có.

## Thay đổi

| Bề mặt | Diện mạo đã đồng bộ |
| --- | --- |
| Google Workspace | Thay teal riêng bằng primary; panel trắng/viền slate, tiêu đề 700, badge và thông báo dùng màu ngữ nghĩa; copy tên HocLucStation |
| Duyệt vào lớp | Nút/biểu tượng dùng primary và error; popup radius panel, elevation 4; nút xác nhận kế thừa hover/pressed/disabled từ AppTheme |
| Meet trong app | Trạng thái chờ/lỗi theo palette; tên app thống nhất; không thay nội dung trang Google trong WebView |
| Microphone Windows | Nền slate tối đặc, icon và meter tint sáng; focus viền sáng; settings dialog và input dùng theme chung |
| Studio và chat | Thanh trạng thái buổi học theo selected/success/error, overlay elevation thấp; cuộn chat hỗ trợ reduced motion |

Không thay service, model, plugin, API, cơ chế OAuth, quyền Meet hay điều khiển microphone. Các màu nét vẽ và tài liệu vẫn độc lập với palette chrome.

## Kiểm chứng

- **229 test qua**, gồm architecture test và các test Google Workspace, OAuth, admission, microphone, studio, PDF và geometry hiện có.
- Phân tích Dart sạch trên 7 file UI được chỉnh cùng `new_feature_appearance_test.dart`.
- Web release và Windows release build thành công; log kèm trong thư mục này.
- Review độc lập đã kiểm tra việc giữ callback và layout. Review phát hiện `animateTo` không nhận thời lượng 0; đã đổi sang `jumpTo` khi giảm chuyển động, chờ thêm một frame để lazy list cập nhật extent. Test với 40 tin nhắn xác nhận cuộn tới tin mới nhất, không phát sinh exception.
- Ảnh là render Flutter thật với font bundle và dữ liệu fixture: Workspace 1440×1000; admission/microphone 1366×768. Không dùng ảnh sinh làm bằng chứng UI.

## Ảnh

- [Workspace có lớp và danh sách học sinh](workspace-connected.png)
- [Trạng thái cần cấp quyền lại](workspace-reconnect.png)
- [Hộp duyệt vào lớp](meet-admission.png)
- [Cụm microphone](microphone-controls.png)
- [Cài đặt microphone](microphone-settings.png)

## Giới hạn

Chưa thao tác Google thật, WebView2, camera hoặc thiết bị microphone thật trong phiên này. Test dùng API/channel giả lập; không khẳng định dữ liệu/thiết bị production đã hoạt động. Browser tích hợp không khả dụng nên ảnh được chụp qua widget renderer Flutter. Build vẫn có cảnh báo font Cupertino và NuGet/CMake từ dependency như trước; cả hai build kết thúc thành công.

## Lệnh

Chạy trong `frontend/`:

```text
flutter test --no-pub --dart-define=HLS_CAPTURE=true --reporter expanded
flutter build web --release --no-pub --no-wasm-dry-run
flutter build windows --release --no-pub
```

Trong môi trường này Flutter CLI được gọi trực tiếp bằng Dart SDK và `flutter_tools.snapshot --no-version-check` để dùng cache SDK hiện có. File tạm/ảnh trung gian và snapshot source trước sửa được giữ trong `.run/new-feature-appearance/` (đã ignore). Không tạo commit hoặc push.
