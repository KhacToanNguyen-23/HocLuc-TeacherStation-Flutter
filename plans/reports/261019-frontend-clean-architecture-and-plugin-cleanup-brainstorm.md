# Brainstorm: Tái Cấu Trúc Frontend Clean Architecture & Xử Lý Trùng Lặp Plugin

**Date:** 2026-10-19  
**Slug:** `frontend-clean-architecture-and-plugin-cleanup`  

---

## 1. Bối Cảnh & Vấn Đề (Problem Statement)

1. **Thư mục `frontend/lib/` bị manh múng và nợ kỹ thuật nặng:**
   - `lib/services/` chứa 24 file lộn xộn, trộn lẫn giữa Plugin Host, Media/Camera, Auth/Classroom và các nghiệp vụ môn học đặc thù.
   - `lib/widgets/` chứa 36 file trôi nổi ngoài root mà không gom vào thư mục tính năng.
   - Tồn dư dead code (`sidecar_manager*.dart`) và khai báo dependency rác trong `pubspec.yaml` (`wgc_broadcaster` đã bị xóa code nhưng vẫn còn trong dependencies).
2. **Thư mục `frontend/test/` phình to bất thường:**
   - 64 file test nằm phẳng hoàn toàn trong `test/`, không có phân cấp thư mục.
   - Lẫn lộn file script Node.js CJS (`meet_admission_bridge.browser.cjs`, `meet_screen_share.test.cjs`) trong thư mục test của Flutter.
   - Nhiều file test trùng lặp chức năng do các đợt phát triển tính năng lẻ tẻ.
3. **Trùng lặp & Vi phạm kiến trúc Plugin:**
   - Plugin `smart_pen_answer_snap` là một "dummy plugin" (file UI chỉ có 13 dòng test rỗng, không có logic thực), trong khi toàn bộ mã nguồn nặng nề (`smart_pen_answer_classifier.dart`, `smart_pen_answer_index.dart`) lại bị code trực tiếp vào Core Host.
   - Chức năng này giẫm chân lên công cụ Smart Chalk / Smart Pen native của bảng vẽ.

---

## 2. Các Hướng Đi Đã Thảo Luận (Ideas Explored)

- **Hướng A (Layer-First / Theo Tầng Truyền Thống):** Gom file thành `models/`, `views/`, `controllers/`, `services/`.
  - *Đánh giá:* Vẫn gây manh múng khi dự án lớn dần, dev sửa 1 tính năng phải nhảy qua 4 thư mục cách xa nhau.
- **Hướng B (Feature-First / Clean Architecture theo Module Nghiệp Vụ - Được Chọn):**
  - Gom toàn bộ code thành 4 Module cốt lõi: `features/auth/`, `features/classroom_meet/`, `features/studio_board/`, và `features/plugin_engine/`.
  - Giữ lại tầng `core/` chỉ cho Theme, Network client, Utils.
  - Phân loại `frontend/test/` thành: `test/unit/`, `test/widgets/`, `test/features/`, `test/architecture/`, `test/e2e_browser/`.
- **Hướng xử lý Plugin Smart Pen:**
  - Hợp nhất logic Smart Pen Answer Snap vào đúng vị trí Native của nó (`features/studio_board/pdf_viewer/`), xóa bỏ plugin rác giả lập khỏi `plugins/`.

---

## 3. Định Hướng Của Người Dùng (User's Direction)

- Áp dụng **Clean Architecture** gom nhóm các service/packet theo từng module nghiệp vụ cụ thể.
- **Zero Logic Change**: Bảo toàn 100% logic và hành vi của ứng dụng, không làm gãy tính năng hiện tại.
- **Cơ chế chốt chặn lâu dài**: Sử dụng mô hình phòng thủ nhiều lớp (MD Rules + Pre-commit Hook + CI Architecture Test) để tự động chặn đứng việc vứt file bừa bãi trong tương lai.

---

## 4. Các Chốt Chặn Kiểm Soát Mới (Architecture Invariants)

Bổ sung vào `frontend/test/architecture_test.dart`:
- **Bất biến 8:** Cấm file widget/service trôi nổi ngoài root `lib/widgets/` và `lib/services/`. Mọi file mới bắt buộc thuộc `features/` hoặc `core/`.
- **Bất biến 9:** Cấm file test nằm phẳng ở root `frontend/test/` (ngoại trừ file chốt chặn `architecture_test.dart`).
- **Bất biến 10:** Cấm dependency ma (khai báo path không tồn tại trong `pubspec.yaml`).

---

## 5. Rủi Ro & Giải Pháp (Risks & Mitigations)

1. **Rủi ro đứt gãy đường dẫn import (`import 'package:...';`):**
   - *Giải pháp:* Bộ 64 test files hiện tại đóng vai trò là "Lưới an toàn" (Safety Net). Chạy `flutter test` trước và sau mỗi bước di chuyển để đảm bảo 100% compile sạch và test xanh.
2. **Rủi ro ảnh hưởng đến Git history (Merge Conflicts):**
   - *Giải pháp:* Chia nhỏ việc di chuyển file theo từng module (`auth` -> `classroom_meet` -> `plugin_engine` -> `studio_board`).

