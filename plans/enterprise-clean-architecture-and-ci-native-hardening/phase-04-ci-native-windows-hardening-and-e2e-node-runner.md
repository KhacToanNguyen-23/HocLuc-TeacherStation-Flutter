# Phase 04: Vá Lỗ hổng CI Native & Kích hoạt Browser Test

## Mục tiêu
Khắc phục lỗi path trong `test/e2e_browser/`, kích hoạt kiểm thử browser bridge trên CI, và bổ sung job kiểm tra native compilation Windows trên GitHub Actions.

## Các công việc cụ thể
1. **Sửa đường dẫn trong `test/e2e_browser/*.cjs`:**
   - Trong `meet_screen_share.test.cjs`: Sửa đường dẫn từ `../lib/services/meet_screen_share_script.dart` thành `../../lib/features/classroom_meet/services/meet_screen_share_script.dart`.
   - Trong `meet_admission_bridge.browser.cjs`: Sửa đường dẫn tương tự trỏ đúng vào `lib/features/classroom_meet/services/`.
   - Chạy kiểm thử cục bộ: `node --test test/e2e_browser/meet_screen_share.test.cjs`.
2. **Cập nhật `.github/workflows/ci-frontend.yml`:**
   - Thêm step chạy `node --test test/e2e_browser/meet_screen_share.test.cjs` ngay sau bước Node.js setup.
   - Thêm job `build-windows-check` (chạy trên `windows-latest` cho pull request vào `develop` và `main`) để thực hiện:
     - Setup Flutter
     - `flutter pub get`
     - `flutter build windows --debug` (hoặc compile CMake check) để đảm bảo không bị gãy C++/CMake native linkage trên môi trường Windows Desktop thật.

## Tiêu chí hoàn thành (Verification)
- `node --test test/e2e_browser/meet_screen_share.test.cjs` PASS trên terminal.
- File `.github/workflows/ci-frontend.yml` hợp lệ về mặt cú pháp YAML và tích hợp đầy đủ các step mới.

