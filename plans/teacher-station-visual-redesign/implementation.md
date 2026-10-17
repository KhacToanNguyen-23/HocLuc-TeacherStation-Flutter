# HocLucStation — Kết quả thay diện mạo

Trạng thái: đã triển khai và xác nhận bằng source, test, ảnh Flutter và hai production build. Palette và mẫu dashboard được người dùng duyệt trước khi triển khai. Kiểm tra thiết bị thật nằm ngoài bằng chứng của môi trường này.

## Phạm vi đã thực hiện

- Áp dụng xanh dương–slate tiết chế cho đăng nhập/đăng ký, dashboard, soạn bài, sảnh, studio, đề thi, dialog và tiện ích hiện có.
- `AppPalette` là nguồn màu chuẩn; `AppTheme.light()` đồng bộ Material, input, nút, menu, dialog và trạng thái tương tác. `AppColorTheme.light()` dùng cùng palette.
- Nút chính xanh đậm, chữ trắng; thẻ phẳng, viền mảnh, góc control 8/panel 12; giảm độ đậm tiêu đề và bóng trang trí.
- Tab/công cụ chọn dùng xanh nhạt. Overlay giảng dạy dùng slate tối đặc, chữ/icon sáng. Badge môn học, màu plugin sở hữu và màu nội dung giữ phân loại hiện có.
- DashboardActionCard có focus bàn phím và kích hoạt Enter; hover/pressed không nhấc thẻ. Motion tùy biến có phương án giảm chuyển động.
- Giữ bố cục, điều hướng, kích thước/padding, minh họa đăng nhập, Manrope/Literata, bảng phấn và nét bút. Không thay model/service/API, assets hoặc dependency manifest.
- Tên tài liệu là HocLucStation; nhãn runtime hiện có không được đổi trong lượt này.

## Các lỗi sửa sau khi xem ảnh/build

1. Preview camera tắt từng vẽ hai lớp chữ chồng nhau: dùng một nền preview và một lớp trạng thái; không thay media logic.
2. Spinner trắng trên nền disabled quá nhạt: nền nút disabled chuyển slate đủ tương phản với chữ/spinner trắng.
3. Chữ G của nút Google dùng font không bundle: dùng Manrope hiện có; màu nhận diện và hình học giữ nguyên.
4. Viền, shadow và nút disabled của panel học sinh được tiết chế; icon mic/camera trên nền tối dùng tint sáng.
5. Các style nút chính cục bộ từng chặn màu hover/pressed của theme: bỏ nền primary cố định, kiểm tra trên nút “Dạy ngay” thật.
6. Web compiler phát hiện kiểu suy luận `DropdownMenuItem<Object>` ở danh sách camera: khai báo rõ `DropdownMenuItem<String>`, không đổi callback hoặc dữ liệu.

## Kết quả kiểm tra

| Yêu cầu | Bằng chứng hiện tại |
| --- | --- |
| Phân tích Dart sạch | `evidence/analyze.log`: No issues found |
| Không hồi quy trong bộ test | `evidence/full-test.log`: 163 test qua |
| Giữ hình học 6 màn chính | `visual_restyle_test.dart` so 24 scene với `test/fixtures/visual_restyle_geometry.json`; cùng anchor và dung sai 1 logical px |
| Desktop và scaling | 1366×768, 1440×900, 1920×1080; thêm 1920×1080 DPR 1.25, tương đương vùng logical 1536×864 |
| Trạng thái bổ sung | Đăng ký, đăng nhập loading/error, đề thi empty/error, 9 trang admin, document/inspector/students drawer, dải học sinh mở/thu và banner xin vào lớp |
| Contrast và tương tác | `app_appearance_test.dart`: các cặp chữ >=4.5, input outline >=3; pointer/keyboard, hover/pressed thật và reduced motion không dịch chuyển target |
| Web release | `evidence/web-build.log`: thành công, output `frontend/build/web` |
| Windows release | `evidence/windows-build.log`: thành công, output `frontend/build/windows/x64/runner/Release/teaching_companion.exe` |
| Palette/spec đồng bộ | `DESIGN.md`, `.fk-skills/design.json`; kiểm tra schema, reference token, 8 CSS specimen và narrative khớp |
| Logic/nội dung được giữ | `git diff` không thay `frontend/lib/models`, `frontend/lib/services`, `frontend/assets`, `frontend/pubspec.yaml`; các test studio/PDF/auth/exam hiện có qua |

Baseline trước thay diện mạo: 25 test chức năng trọng tâm qua; ảnh và tọa độ được chụp trước khi sửa screen/widget. Thay đổi spacing có sẵn trong worktree được giữ làm baseline. Bản đặc tả cũ lưu tại `DESIGN.before.md` và `design.before.json`.

Gallery có 43 PNG thực trong `.run/visual-restyle/after/`; thư mục `evidence/` giữ 11 ảnh tiêu biểu cùng log. Ảnh này là widget Flutter thật với font bundle và dữ liệu fixture. `dashboard-appearance-proposal.png` và `palette-proposal.png` là tài liệu duyệt, không phải ảnh app thật.

## Lệnh tái kiểm tra

Thực hiện trong `frontend/`, Flutter 3.47.6 / Dart 3.13.5:

```text
dart analyze lib test/app_appearance_test.dart test/visual_restyle_test.dart
flutter test --no-pub --dart-define=HLS_CAPTURE=true --reporter expanded
flutter build web --release --no-pub --no-wasm-dry-run
flutter build windows --release --no-pub
```

Trong môi trường Codex, lệnh Flutter chạy qua `D:/flutter/bin/cache/dart-sdk/bin/dart.exe D:/flutter/bin/cache/flutter_tools.snapshot --no-version-check ...` vì cache SDK cần quyền ghi ngoài workspace. Tham số `--no-wasm-dry-run` bỏ lượt thăm dò Wasm; bản web release vẫn được biên dịch và không khẳng định hỗ trợ Wasm.

## Giới hạn bằng chứng

- Browser tích hợp báo không khả dụng; không có kiểm tra live browser hoặc thao tác trên cửa sổ Windows thật trong phiên này. Viewport/scaling là mô phỏng Flutter, không phải thay cài đặt Windows.
- Chưa thử bút vật lý, camera/mic, đăng nhập Google thật và nội dung truyền qua Meet. Bộ test xác nhận hành vi widget/service với fixture và engine hiện có; không khẳng định đường truyền thiết bị hoạt động thật.
- Render SVG minh họa cũ ghi cảnh báo `<filter/>`; giữ nguyên asset theo yêu cầu. Các test có HTTP 400 từ bootstrap giả lập, không phải bằng chứng backend production lỗi.
- Web build có cảnh báo font Cupertino từ cây dependency; UI của app dùng Material và font bundle. Windows build ghi thông báo NuGet/CMake policy từ plugin `webview_windows`; build kết thúc thành công. Không sửa dependency ngoài phạm vi diện mạo.
- CSS specimen trong sidecar là bản diễn dịch để xem token; không thay thế ảnh Flutter, không khẳng định shadow/font trình duyệt giống renderer Flutter từng pixel.

## Ảnh xem nhanh

- [Dashboard](evidence/dashboard.png)
- [Đăng nhập](evidence/login.png)
- [Studio](evidence/studio.png)
- [Sảnh vào lớp](evidence/lobby.png)
- [Đề thi](evidence/exams.png)
- [Các trạng thái học sinh](evidence/studio-meet-states.png)
