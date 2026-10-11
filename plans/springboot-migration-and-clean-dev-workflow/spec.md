# Spec: Nâng cấp Backend lên Spring Boot & Chuẩn hóa luồng chạy Dev 2 CMD

**Date:** 2026-10-10
**Status:** Ready

---

## Problem Statement
Dự án hiện đang sử dụng Core Java thủ công với router tự viết, quy trình chạy phức tạp qua script PowerShell bọc nhiều tầng, và tồn tại các code smells (thư mục rác mồ côi, tài liệu lệch cấu trúc, script tự đòi quyền Admin). Dự án cần được nâng cấp Backend lên Spring Boot 3 chuẩn mực thực tế, dọn dẹp các smell và thiết lập quy trình chạy 2 CMD độc lập hỗ trợ Hot-Reload.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a Developer, I want to run the Java backend using standard `mvn spring-boot:run` on port `47831` so that I can easily debug, see live console logs, and leverage the Spring Boot ecosystem.
  Accepted when: Backend starts cleanly with Spring Boot 3, serves all existing endpoints (`/api/bootstrap`, `/api/classroom/*`, `/api/lessons/*`, `/api/devices/*`), and accepts CORS from Flutter Web.

- **[P1]** As a Developer, I want to run the Flutter frontend in a separate CMD terminal using standard `flutter run` so that I can take advantage of instant Hot Reload (`r` / `R`).
  Accepted when: Flutter app successfully calls Spring Boot endpoints and renders without CORS or connection issues on Chrome/Windows.

- **[P1]** As a Developer, I want repository smells removed (orphan `service/data` folder removed, `README.md` synced from `app/` to `frontend/`, `.gitignore` updated for `.run/` and logs) so that the codebase is clean, professional, and reliable.
  Accepted when: No orphan folders remain, `README.md` reflects current structure, and runtime artifacts do not dirty Git status.

- **[P2]** As a Developer, I want clean helper scripts (`dev-backend.bat`, `dev-frontend.bat`) without Administrator elevation so that I can launch either service with a single command.
  Accepted when: Double-clicking or executing the bat files launches the respective services without UAC prompts.

- **[P3]** As a Developer, I want to connect Spring Boot to PostgreSQL via Spring Data JPA so that data is stored in the database instead of local JSON files.
  Accepted when: Deferred to future iteration (database models and repository layers planned).

---

## Functional Requirements

1. **FR-01 (Maven & Spring Boot Setup):**
   - Cập nhật `backend/service/pom.xml` với `spring-boot-starter-parent` phiên bản `3.2.x` hoặc `3.4.x` (tương thích Java 17).
   - Thêm `spring-boot-starter-web` và `spring-boot-maven-plugin`.
   - Cấu hình file `application.properties` với `server.port=47831`.

2. **FR-02 (Application Entrypoint & CORS):**
   - Chuyển đổi `vn.teaching.CompanionServer` thành `@SpringBootApplication`.
   - Cấu hình CORS toàn cục cho phép các request từ origin của Flutter Web (hỗ trợ `localhost:*` và `127.0.0.1:*`).

3. **FR-03 (Controller Migration):**
   - Chuyển `ClassroomController` sang `@RestController` và mapping RESTful (`/api/classroom/*`).
   - Chuyển `LessonController` sang `@RestController` (`/api/lessons/*` hoặc các đường dẫn tương ứng).
   - Chuyển `DeviceController` sang `@RestController` (`/api/devices/*`).
   - Giữ nguyên toàn bộ logic nghiệp vụ của `ClassroomService`, `StorageService`, `DeviceService`.

4. **FR-04 (Bootstrap Endpoint):**
   - Cung cấp endpoint `GET /api/bootstrap` trả về status và thông tin cấu hình tương tự implementation cũ để tương thích với Flutter client.

5. **FR-05 (Smell Cleanup):**
   - Xóa thư mục thừa `service/` tại thư mục gốc.
   - Thêm `.run/`, `*.log`, `*.pid` vào `.gitignore`.
   - Cập nhật `README.md` với cây thư mục chính xác (`frontend/` thay vì `app/`) và hướng dẫn chạy 2 CMD chuẩn.

---

## Non-Functional Requirements

- **Performance:** Thời gian khởi động của Spring Boot dưới 4 giây trên môi trường dev.
- **Compatibility:** API responses giữ nguyên định dạng JSON 100% để Frontend Flutter không cần phải sửa đổi code client.
- **Portability:** Không yêu cầu quyền Administrator để chạy bất kỳ lệnh dev nào.

---

## Success Criteria

- [ ] Backend khởi động thành công với `mvn spring-boot:run` (hoặc qua script) tại cổng `47831`.
- [ ] Endpoint `http://127.0.0.1:47831/api/bootstrap` trả về HTTP 200 OK cùng JSON hợp lệ.
- [ ] Frontend Flutter gọi được API của Backend mà không bị lỗi CORS hoặc 404.
- [ ] Hot reload trên Flutter (`r`) hoạt động bình thường khi chạy qua CMD.
- [ ] Thư mục rác `service/` tại gốc repo được xóa sạch.

---

## Out of Scope

- Viết lại toàn bộ UI Flutter.
- Chuyển đổi lưu trữ JSON sang PostgreSQL (để lại cho phase sau).
- Triển khai WebRTC streaming cho camera/mic ảo (giữ nguyên stub hiện có).

---

## Assumptions

- Máy người dùng có sẵn JDK 17 và Maven 3.8+ trong PATH hoặc chạy được qua Maven wrapper.
- Người dùng đã bật Developer Mode trên Windows (hoặc chạy test trên Chrome).
