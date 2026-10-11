# Brainstorm: Nâng cấp Backend lên Spring Boot & Chuẩn hóa luồng chạy Dev 2 CMD

**Date:** 2026-10-10

## Ideas Explored

1. **Giữ Core Java thuần (`HttpServer` + `Gson`) + thêm `exec-maven-plugin`:**
   - Ưu điểm: Siêu nhẹ, khởi động trong 0.2 giây, dễ đóng gói `jlink`.
   - Nhược điểm: Cấu hình router thủ công, không có hệ sinh thái Spring (JPA, Security, Validation), dev Java khó tiếp cận.
2. **Nâng cấp Backend lên Spring Boot 3 (Java 17) [ĐÃ CHỌN]:**
   - Ưu điểm: Chuẩn doanh nghiệp thực tế, lệnh `mvn spring-boot:run` quen thuộc, dễ tích hợp PostgreSQL/JPA trong `docker-compose.yml`, annotation `@RestController`, `@GetMapping` rõ ràng.
   - Nhược điểm: Dung lượng jar tăng từ 2MB lên ~35MB, khởi động mất 2-3s (hoàn toàn chấp nhận được).
3. **Chạy All-in-one Script vs Chạy 2 CMD độc lập [ĐÃ CHỌN: 2 CMD]:**
   - Đánh giá: 2 CMD (CMD 1: Backend, CMD 2: Frontend) mang lại trải nghiệm chuyên nghiệp thực tế, giữ nguyên Hot-Reload (phím `r`) của Flutter và log trực tiếp của Spring Boot.
4. **Dọn dẹp các Code Smells trong Repo:**
   - Xóa thư mục mồ côi `service/data` ở thư mục gốc.
   - Đồng bộ tài liệu `README.md` (sửa `app/` thành `frontend/`).
   - Cập nhật `.gitignore` loại trừ `.run/`, log files và build artifacts.
   - Thay thế script tự xin quyền Administrator bằng hướng dẫn bật Developer Mode.

## User's Direction

- Người dùng quyết định **chuyển đổi Backend sang Spring Boot** để chuẩn thực tế và dễ mở rộng.
- Thực hiện phương án **chạy 2 lệnh ở 2 cửa sổ CMD độc lập** (Frontend & Backend).
- Giao AI thực hiện toàn bộ việc tái cấu trúc mã nguồn, dọn dẹp Code Smell; sau khi hoàn tất, AI sẽ hướng dẫn từng bước để người dùng chạy lại dự án trên máy của mình.

## Open Questions

- Giữ nguyên cổng backend `47831` hay đổi về mặc định `8080`: Chốt giữ cổng `47831` để giữ tương thích 100% với Frontend Flutter client mà không cần sửa code Flutter.
- Cấu hình CORS: Cần thêm `@CrossOrigin` hoặc `WebMvcConfigurer` cho Spring Boot để chấp nhận các kết nối từ Flutter Web runner.

## Risks

- **Đóng gói portable exe cũ (`Build-Windows.ps1`):** Cần lưu ý jar Spring Boot sẽ được đóng gói theo dạng fat jar, launcher script cần trỏ đúng jar mới nếu sau này build lại bản portable.
- **Xung đột Symlink trên Windows:** Cần nhắc người dùng bật Developer Mode một lần trên Windows để chạy Flutter Desktop mà không bị đòi quyền Administrator.
