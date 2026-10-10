# Brainstorm: Cấu trúc thư mục & Docker Infrastructure

**Date:** 2026-10-10

## Ideas Explored
1. Đổi tên thư mục thành `fe` và `be`: Đã loại bỏ vì làm mất ý nghĩa của `app`, `service` và nguy cơ làm vỡ các script chạy hiện tại.
2. Đưa toàn bộ Backend + DB vào Docker: Đã loại bỏ vì team gồm 4 fullstack dev, cần chạy trực tiếp Backend để dễ debug.
3. Chỉ đưa Database (PostgreSQL) vào Docker: Tối ưu cho team fullstack, tạo môi trường đồng nhất mà không làm chậm quá trình code/hot-reload.

## User's Direction
Team thống nhất giữ nguyên cấu trúc thư mục (`app` cho Flutter FE, `service` và `whiteboard-host` cho BE).
Với Docker, chỉ áp dụng để đóng gói Database (PostgreSQL) bằng `docker-compose` phục vụ môi trường Local Dev. Code FE và BE sẽ được chạy trực tiếp trên máy cá nhân thông qua IDE.

## Open Questions
- Không có. (Đã chốt xong)

## Risks
- 4 bạn dev phải tự đảm bảo máy cá nhân đã cài đặt Java, Maven, và Node.js với phiên bản tương thích của dự án.
