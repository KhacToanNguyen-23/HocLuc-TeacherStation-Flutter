# Plan: Nâng cấp Backend lên Spring Boot & Chuẩn hóa luồng chạy Dev 2 CMD

**Mode:** Fast
Risk: normal — Spring Boot upgrade and script reorganization

## Overview
Chuyển đổi Backend Java thuần sang Spring Boot 3 (Java 17) giữ nguyên tương thích API trên cổng 47831, dọn dẹp các Code Smells mồ côi trong repo, và thiết lập 2 file script CMD (`dev-backend.bat`, `dev-frontend.bat`) hỗ trợ Hot-Reload và thông minh nhận diện Flutter SDK.

## Phases

- [x] **Phase 1: Nâng cấp Backend lên Spring Boot 3** (`phase-01-spring-boot-migration.md`)
  - Cập nhật `pom.xml` sang `spring-boot-starter-web` (Spring Boot 3.2.5, Java 17).
  - Thêm `application.properties` với `server.port=47831`.
  - Cấu hình `@SpringBootApplication` và CORS Filter toàn cục.
  - Chuyển `ClassroomController`, `LessonController`, `DeviceController` sang `@RestController`.
  - Bổ sung controller cho `/api/bootstrap`.
  - Đã pass 100% test suite với `mvn test`.

- [x] **Phase 2: Dọn dẹp Code Smells & Cấu trúc Repo** (`phase-02-code-smell-cleanup.md`)
  - Xóa thư mục mồ côi `service/` ở thư mục gốc (đã có `backend/service/data`).
  - Thêm `.run/`, `*.log`, `*.pid` vào `.gitignore`.

- [x] **Phase 3: Tạo công cụ chạy 2 CMD & Cập nhật README** (`phase-03-dev-scripts-and-docs.md`)
  - Tạo `dev-backend.bat` (chạy `mvn spring-boot:run` tại `backend/service`).
  - Tạo `dev-frontend.bat` (tự động nhận diện Flutter PATH hoặc fallback `.sdk/flutter`, chạy `flutter run -d chrome`).
  - Cập nhật `README.md` sang cấu trúc chuẩn và hướng dẫn người dùng chạy dự án.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-10 23:48
**Phase in progress:** Completed all phases
**Status:** Backend migrated to Spring Boot 3, tests passing, smell cleanup finished, dev scripts ready.

### Decisions made this session
- Giữ nguyên cổng backend 47831 và cấu hình CORS toàn cục cho Flutter Web.
- Tạo `dev-frontend.bat` có khả năng tự động fallback nếu Flutter chưa có trong PATH máy.
- Xóa thư mục mồ côi `service/` rỗng ở root.

### Next immediate action
Hướng dẫn người dùng các bước đơn giản trên máy cá nhân để khởi chạy dự án.
