# Kế hoạch Tích hợp & Merge các nhánh của Team vào Develop

> **Mục tiêu:** Tích hợp toàn bộ thành quả của 3 thành viên (Gia Huy, Quốc Thái, Đức Thịnh) và tính năng Zero-Click Meet Automation / Student Admission hiện tại vào nhánh `develop` một cách an toàn, có chốt kiểm thử (test gates) sau từng giai đoạn, không gây hồi quy (regression) và không làm vỡ cấu hình build Windows.

---

## Thông tin phân loại & Phạm vi
* **Mode:** `--hard` (Multi-member branch integration, native Windows C++ plugins, DB migrations)
* **Risk:** `high-risk` — Chạm vào cấu hình build C++ native (`audio_bridge`, `camera_windows`), Flyway DB migrations backend, phiên xác thực OAuth và luồng Studio chung.
* **Test:** Chạy test suite `flutter test` và smoke test sau mỗi bước merge.

---

## Ma trận các thành phần cần tích hợp

| Giai đoạn | Nhánh nguồn / Thành phần | Tác giả | Nội dung cốt lõi | Rủi ro & Điểm kiểm soát |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1** | Local working tree (`develop`) | Bạn | Zero-Click Google Meet Automation & Duyệt học sinh trong Drawer | Baseline xanh 27/27 tests |
| **Phase 2** | `origin/develop` (đã có PR #9) | Quốc Thái | Soạn giáo án điện tử (Lesson Planning) & tách TopBar `isPlanning` | Rebase với local working tree |
| **Phase 3** | `origin/fix/camera-innit-fix` | Đặng Gia Huy | Fix camera init 2 lần + Chọn stream Board / App toàn màn hình | 0 conflict, test webcam preview |
| **Phase 4** | `origin/feat/vact-hsa-exam-platform` | Nguyễn Đức Thịnh | Luyện thi V-ACT/HSA, flyway migrations, Exam Drawer | 0 conflict code, kiểm tra backend API |
| **Phase 5** | `origin/feat/local-ai-speech-translation` | Nguyễn Đức Thịnh | AI dịch offline giọng nói, C++ audio loopback bridge | Đồng bộ `pubspec.lock`, CMake Windows |
| **Phase 6** | Toàn bộ hệ thống trên `develop` | Cả nhóm | Chạy full test suite, build Windows native, verify luồng hoàn chỉnh | Push lên `origin/develop` |

---

## Chi tiết các Phases thực thi

### Phase 1: Đóng gói và Commit tính năng Local (Zero-Click Meet & Student Drawer)
* **Mục tiêu:** Tạo commit chuẩn cho các file đang chỉnh sửa trên máy bạn, biến working directory thành sạch (clean state).
* **Nhiệm vụ:**
  - `git add` các file liên quan đến Meet Automation, WebView persistence, Studio Student Drawer và banner.
  - Viết commit message rõ ràng: `feat(meet): implement zero-click meet automation and in-app student admission drawer`.
  - Chạy `flutter test` đảm bảo 27/27 tests pass.

### Phase 2: Đồng bộ `origin/develop` (Chứa tính năng Soạn giáo án của Quốc Thái)
* **Mục tiêu:** Tích hợp code `develop` mới nhất của Thái vào local branch.
* **Nhiệm vụ:**
  - Chạy `git pull --rebase origin develop`.
  - Kiểm tra xem có conflict giữa tính năng `isPlanning` của Thái và `StudioStudentsDrawer` của bạn trên `studio_top_bar.dart` và `studio_screen.dart` hay không.
  - Khẳng định: Nút mở Drawer học sinh chỉ hiện khi đang dạy học (`!isPlanning`), ẩn khi đang soạn bài.
  - Chạy lại toàn bộ test suite.

### Phase 3: Merge nhánh của Đặng Gia Huy (`fix/camera-innit-fix`)
* **Mục tiêu:** Tiếp nhận bản sửa camera init và tính năng stream board/app toàn màn hình.
* **Nhiệm vụ:**
  - Chạy `git merge origin/fix/camera-innit-fix --no-ff -m "merge: integrate camera contention fix and app stream options from GHP1991"`.
  - Kiểm tra các file: `media_device_service.dart`, `camera_broadcast_service.dart`, `app_capture_surface.dart`.
  - Chạy test camera: `flutter test test/camera_initialization_test.dart test/camera_broadcast_test.dart`.

### Phase 4: Merge nhánh Đề thi V-ACT/HSA của Nguyễn Đức Thịnh (`feat/vact-hsa-exam-platform`)
* **Mục tiêu:** Tích hợp nền tảng luyện thi và ngân hàng câu hỏi.
* **Nhiệm vụ:**
  - Chạy `git merge origin/feat/vact-hsa-exam-platform --no-ff -m "merge: integrate V-ACT/HSA exam platform from Nguyen Duc Thinh"`.
  - Xác nhận không có conflict code nhờ Thịnh đã chuyển popup vào document drawer.
  - Kiểm tra Flyway migration SQL `V1__exam_platform.sql` và backend Spring Boot build (`mvn test-compile`).

### Phase 5: Merge nhánh AI Dịch giọng nói Offline (`feat/local-ai-speech-translation`)
* **Mục tiêu:** Tích hợp C++ WASAPI bridge và audio translation controls.
* **Nhiệm vụ:**
  - Chạy `git merge origin/feat/local-ai-speech-translation --no-ff`.
  - Nếu gặp conflict ở `frontend/pubspec.lock`: Chạy `flutter pub get` để Flutter tự động hòa giải lockfile.
  - Xác nhận plugin C++ `audio_bridge` và `camera_windows` cùng tồn tại hài hòa trong `CMakeLists.txt`.

### Phase 6: Tổng kiểm tra hệ thống (System Verification & Final Gate)
* **Mục tiêu:** Đảm bảo toàn bộ ứng dụng build thành công trên Windows và các test suite pass 100%.
* **Nhiệm vụ:**
  - Backend: `mvn clean test` (hoặc test các controller chính).
  - Frontend: `flutter test` toàn bộ project.
  - Build thử nghiệm: `flutter build windows --debug` (hoặc dry-run kiểm tra liên kết plugin native).
  - Push `develop` lên `origin/develop` để cả nhóm cùng dùng chung bản chuẩn.
