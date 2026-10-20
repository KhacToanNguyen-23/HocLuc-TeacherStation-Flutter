# Phase 03: Deep Dart Architecture Test Hardening (`architecture_test.dart`)

**Parent Plan:** [plan.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/plugin-lifecycle-ci-enforcement/plan.md)  
**Status:** Completed  
**Target File:** `frontend/test/architecture_test.dart`  

---

## 1. Mục Tiêu & Yêu Cầu

Nâng cấp bài kiểm thử kiến trúc `architecture_test.dart` để biến nó thành chốt chặn kỹ thuật không thể xuyên thủng trên CI và local test suite.

### Tiêu chí nghiệm thu:
1. **Phát hiện Gói Mồ Côi (Orphan `.hlep` Package Check):**
   - Quét toàn bộ file `plugins/*.hlep`.
   - Nếu có file `.hlep` nào mà thư mục nguồn tương ứng `plugins/<name>/` đã bị xóa -> Báo lỗi FAIL ngay:
     `"Phát hiện gói mồ côi: plugins/<name>.hlep. Thư mục nguồn đã bị xóa, hãy xóa file .hlep này!"`
2. **Kiểm tra Đồng bộ File Byte-level (Deep Integrity Sync):**
   - Tận dụng thư viện `package:archive` đã có sẵn trong `frontend/pubspec.yaml`.
   - Đọc và giải nén ảo từng file `.hlep`.
   - Đối chiếu danh sách file trong zip với file thực tế trong `plugins/<name>/` (bỏ qua `node_modules`, `__pycache__`, `.venv`).
   - Kiểm tra:
     - Mọi file trên đĩa đều phải có mặt trong file `.hlep`.
     - Kích thước byte (`content.length`) giữa file trong zip và file trên đĩa phải khớp nhau.
     - Nếu có file bị lệch hoặc thiếu -> Báo lỗi rõ ràng: `"Gói <name>.hlep KHÔNG ĐỒNG BỘ với thư mục nguồn! Hãy chạy: node scripts/package_plugin.mjs <name>"`.
3. **Giữ vững 100% các bất biến hiện tại:**
   - Bất biến 1: Cấm hardcode tên plugin trong `lib/`.
   - Bất biến 2: Cấm cổng tĩnh 18888.
   - Bất biến 3: Cấm import chéo `package:plugins/`.
   - Bất biến 5: Cổng động không trùng lặp.
   - Bất biến 6: Giới hạn dòng code God Class.

---

## 2. Các Bước Triển Khai

1. Mở file `frontend/test/architecture_test.dart`.
2. Import `package:archive/archive.dart` và `package:path/path.dart as path`.
3. Bổ sung đoạn test Orphan Package Check trước khi lặp qua thư mục.
4. Mở rộng Bất biến 4 với logic giải nén zip và so sánh byte-level.
5. Chạy lệnh kiểm thử `flutter test test/architecture_test.dart` để xác nhận toàn bộ test PASS.

