# Spec: Thiết lập Docker Infrastructure (PostgreSQL)

**Date:** 2026-10-10
**Status:** Ready

---

## Problem Statement
Nhóm gồm 4 Fullstack dev cần một môi trường cơ sở dữ liệu đồng nhất để code và test dự án tại local mà không cần phải cài đặt thủ công PostgreSQL lên từng máy tính.

---

## User Stories

- **[P1]** As a Fullstack Developer, I want to run `docker-compose up` so that I have a local PostgreSQL database running immediately.
  Accepted when: The database container starts successfully and exposes port 5432 to localhost.

- **[P1]** As a Developer, I want my test data to persist across container restarts so that I don't lose data when stopping the container.
  Accepted when: A Docker volume is configured and mounted to the PostgreSQL data path.

---

## Functional Requirements

1. FR-01: Tạo file `docker-compose.yml` ở thư mục gốc của dự án.
2. FR-02: Cấu hình container chạy PostgreSQL phiên bản mới (ví dụ 15+).
3. FR-03: Thiết lập các biến môi trường cấu hình tài khoản mặc định (user, password, db name) cho môi trường dev.

---

## Non-Functional Requirements

- Performance: Khởi động db container nhanh chóng (< 5s).
- Security: Chỉ expose port 5432 ra `127.0.0.1` (localhost) để an toàn.

---

## Success Criteria

- [ ] File `docker-compose.yml` chạy thành công không có lỗi.
- [ ] Backend Java (`service`) có thể kết nối vào Database chạy trong Docker.

---

## Out of Scope

- KHÔNG đóng gói (Dockerize) Java `service` backend.
- KHÔNG đóng gói Node.js `whiteboard-host`.
- KHÔNG đóng gói Flutter `app` frontend.

---

## Assumptions

- Tất cả 4 thành viên trong team đều đã cài đặt Docker Desktop hoặc Docker Engine trên máy của mình.
