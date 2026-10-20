# Spec: Tái Cấu Trúc Frontend Clean Architecture & Xử Lý Trùng Lặp Plugin

**Date:** 2026-10-19  
**Status:** Ready  
**Brainstorm Report:** [261019-frontend-clean-architecture-and-plugin-cleanup-brainstorm.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/reports/261019-frontend-clean-architecture-and-plugin-cleanup-brainstorm.md)  

---

## 1. Problem Statement

Mã nguồn `frontend/` đang bị manh múng và nợ kỹ thuật nặng: `lib/services/` chứa 24 file trộn lẫn 5 miền nghiệp vụ, `lib/widgets/` chứa 36 file trôi nổi ngoài thư mục gốc, `frontend/test/` chứa 64 file phẳng không phân cấp kèm script CJS, và tồn tại plugin giả lập `smart_pen_answer_snap` giẫm chân lên tính năng native. Cần tái cấu trúc sang **Clean Architecture (Feature-First)** bảo toàn 100% logic nghiệp vụ và khóa cứng các chốt chặn CI để ngăn chặn tái diễn.

---

## 2. User Stories

- **[P1 - Developer] Cấu trúc mã nguồn theo Domain Modules (Feature-First):**
  - Là một lập trình viên / AI Agent,
  - Tôi muốn mã nguồn được tổ chức rõ ràng thành 4 module độc lập (`features/auth`, `features/classroom_meet`, `features/studio_board`, `features/plugin_engine`) và tầng `core/`,
  - Để dễ dàng bảo trì, tìm kiếm code, và giảm thiểu tối đa xung đột khi nhiều người cùng làm việc.
  - *Accepted when:* Không còn bất kỳ file widget hay service trôi nổi ngoài thư mục gốc `lib/widgets/` và `lib/services/`.

- **[P1 - Developer] Phân cấp và dọn dẹp thư mục Test:**
  - Là một lập trình viên,
  - Tôi muốn 64 file test được gom nhóm có hệ thống vào các thư mục con (`test/unit/`, `test/widgets/`, `test/features/`, `test/architecture/`, `test/e2e_browser/`),
  - Để test suite chạy có trật tự, dễ debug và không lẫn lộn giữa test Dart và script Node CJS.
  - *Accepted when:* 100% các file test trong `frontend/test/` đều pass và nằm trong đúng thư mục con phân loại.

- **[P1 - Kiến trúc] Hợp nhất và dọn dẹp Plugin rác & Dead code:**
  - Là một kiến trúc sư phần mềm,
  - Tôi muốn xóa bỏ plugin giả `smart_pen_answer_snap`, hợp nhất logic của nó vào module native `studio_board`, dọn dẹp các file dead code (`sidecar_manager*.dart`) và xóa bỏ dependency rác (`wgc_broadcaster`),
  - Để hệ thống plugin giữ đúng bản chất Microkernel thuần túy và `pubspec.yaml` sạch sẽ 100%.
  - *Accepted when:* `node scripts/validate_plugins.mjs` kiểm tra chỉ còn đúng các plugin thực chất, không còn package ma trong `pubspec.yaml`.

- **[P1 - CI Gate] Chốt chặn tự động ngăn ngừa tái diễn:**
  - Là một Tech Lead,
  - Tôi muốn bổ sung các quy tắc bất biến mới vào `architecture_test.dart` và CI workflow,
  - Để tự động đánh fail PR nếu có ai tạo file trôi nổi ngoài module hoặc vứt test bừa bãi ra root test.
  - *Accepted when:* Bất biến 8, 9, 10 trong `architecture_test.dart` được kích hoạt và chạy tự động trên CI.

---

## 3. Functional Requirements

1. **FR-01 (Tạo cấu trúc Feature-First):**
   - Thiết lập các thư mục: `lib/core/`, `lib/features/auth/`, `lib/features/classroom_meet/`, `lib/features/studio_board/`, `lib/features/plugin_engine/`.
2. **FR-02 (Di chuyển Services & Widgets):**
   - Di chuyển 24 file services và 36 file widgets về đúng module tính năng tương ứng.
   - Cập nhật 100% đường dẫn `import` trong toàn bộ codebase Flutter.
3. **FR-03 (Phân loại Test Suite):**
   - Tạo các thư mục con: `test/features/`, `test/unit/`, `test/widgets/`, `test/architecture/`, `test/e2e_browser/`.
   - Di chuyển 64 file test về đúng thư mục phân loại và cập nhật import tương ứng.
4. **FR-04 (Dọn dẹp Dead Code & Dependency):**
   - Xóa `sidecar_manager.dart`, `sidecar_manager_native.dart`, `sidecar_manager_web.dart`.
   - Xóa dependency `wgc_broadcaster` khỏi `frontend/pubspec.yaml`.
   - Hợp nhất `smart_pen_answer_snap` về `features/studio_board/` và xóa folder/package plugin giả lập.
5. **FR-05 (Thắt chặt Architecture Invariants):**
   - Mở rộng `frontend/test/architecture/architecture_test.dart` với Bất biến 8 (cấm file trôi nổi `lib/widgets` và `lib/services`), Bất biến 9 (cấm file test phẳng ở root `test/`), Bất biến 10 (cấm dependency ma).

---

## 4. Non-Functional Requirements

- **Zero Regression (Bảo toàn 100% logic):** Ứng dụng không thay đổi bất kỳ hành vi hiển thị hay tính toán nào đối với người dùng (Giáo viên).
- **Test Integrity:** 100% các bài test hiện có sau khi di chuyển phải **PASS** mà không được xóa bỏ assertion kiểm tra logic nào.
- **Tốc độ CI:** Thời gian chạy toàn bộ `flutter test` sau khi tái cấu trúc không tăng quá 10%.

---

## 5. Success Criteria

- [ ] `flutter analyze --no-fatal-infos` báo `0 issues`.
- [ ] `flutter test` chạy toàn bộ test suite và đạt **100% PASS**.
- [ ] `node scripts/validate_plugins.mjs` đạt `0 errors`.
- [ ] Không còn bất kỳ file `.dart` nào trôi nổi trực tiếp trong `lib/services/` hay `lib/widgets/`.
- [ ] Thư mục `frontend/test/` ở cấp gốc chỉ còn file chốt chặn `architecture_test.dart`, toàn bộ test khác nằm gọn trong các thư mục con.

---

## 6. Out of Scope

- Không viết lại logic lõi của stroke engine, PDF rendering hay WebRTC Meet.
- Không thay đổi thiết kế giao diện UI (Figma/Visual Theme giữ nguyên 100%).

---

## 7. Assumptions

- `flutter test` hiện tại trên `develop` đang đạt 100% pass và có thể dùng làm thước đo chuẩn để đối chiếu độ an toàn trong suốt quá trình refactoring.

