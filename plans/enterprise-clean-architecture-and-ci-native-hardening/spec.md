# Spec: Enterprise Clean Architecture & CI Native Hardening

## Overview
Dự án Teacher Station sau đợt refactor bước 1 đã xóa bỏ `lib/services/` và `lib/widgets/`. Tuy nhiên, để đạt chuẩn Clean Architecture Feature-First thực thụ cấp Enterprise và đóng các lỗ hổng thực chiến nguy hiểm trên CI, hệ thống cần hoàn tất 2 trụ cột:
1. **Triệt tiêu toàn bộ tàn dư thư mục phẳng ở root `lib/`**: Di dời 100% các file còn sót lại tại `lib/screens/`, `lib/models/`, `lib/theme/`, `lib/utils/`, `lib/constants/` về đúng từng domain feature (`lib/features/<module>/`) và `lib/core/`.
2. **Vá lỗ hổng CI Native & Kích hoạt Browser Test**: Bổ sung job xác thực build native Windows (`flutter build windows`) trên GitHub Actions và kích hoạt test tự động cho các kịch bản browser bridge trong `test/e2e_browser/*.cjs`.

---

## User Stories & Functional Acceptance Criteria

### [P1-1] Triệt tiêu `lib/screens/` và `lib/models/` về Modular Features
- **As a** developer working on Teacher Station,
- **I want** all screen widgets and data models to reside strictly within their bounded contexts (`lib/features/<module>/presentation/screens/` and `lib/features/<module>/domain/models/`),
- **So that** each feature is completely self-contained, domain boundaries are crystal clear, and the root `lib/` directory contains zero flat domain files.
- **Verification Command:**
  `flutter test test/architecture_test.dart` (Bất biến 11 & Bất biến 12 phải pass 100%).

### [P1-2] Thống nhất Nền tảng Dùng chung vào `lib/core/`
- **As a** developer,
- **I want** all global styling and utilities (`theme/`, `utils/`, `constants/`) to be consolidated exclusively into `lib/core/theme/`, `lib/core/utils/`, `lib/core/constants/`,
- **So that** there is no ambiguity between root folders and core folders.
- **Verification Command:**
  `flutter analyze --no-fatal-infos` (0 errors, 0 warnings).

### [P1-3] Mở rộng Bất biến Kiến trúc (Architecture Invariants 11 & 12)
- **As a** team lead / CI guardian,
- **I want** automated architecture invariant tests to permanently ban the existence of `lib/screens/` and `lib/models/` at root,
- **So that** future PRs cannot reintroduce flat root clutter.
- **Verification Command:**
  `flutter test test/architecture_test.dart` (Tất cả 12 bất biến đều PASS).

### [P1-4] Vá Lỗ Hổng CI Native (Windows Compilation & E2E Node Runner)
- **As a** release engineer,
- **I want** the CI pipeline to execute `test/e2e_browser/*.test.cjs` and verify Windows native compilation readiness,
- **So that** desktop C++/CMake build breakages and browser bridge bugs are intercepted prior to merging.
- **Verification Command:**
  `node --test test/e2e_browser/meet_screen_share.test.cjs` PASS và workflow CI được cập nhật.

---

## Success Criteria
1. Root `frontend/lib/` CHỈ chứa đúng 3 thực thể: `main.dart`, `core/`, `features/`. Không còn bất kỳ thư mục phẳng nào khác (`screens/`, `models/`, `theme/`, `utils/`, `constants/` đều biến mất 100%).
2. Toàn bộ 395 unit & widget tests tiếp tục PASS 100% với zero logic change.
3. Bộ bất biến kiến trúc tại `frontend/test/architecture_test.dart` tăng lên **12/12 Invariants PASS**.
4. Script `test/e2e_browser/meet_screen_share.test.cjs` sửa đúng path import và PASS trên NodeJS test runner (`node --test`).
5. `.github/workflows/ci-frontend.yml` được bổ sung step chạy test E2E browser và job kiểm tra Windows native build.

