# Plan: Re-architect Plugin System for Production Cloud Marketplace & Dev Decoupling

**Date:** 2026-10-17  
**Mode:** --fast  
**Risk:** normal — Xây dựng API Plugin Marketplace trên Spring Boot, tích hợp tải qua Internet trên Flutter, dọn dẹp triệt để các widget hardcode môn học trong Core.  

---

## 1. Executive Summary & Architecture Blueprint

Hiện tại hệ thống thêm plugin đang phụ thuộc vào quét thư mục cục bộ (`plugins/`) trong môi trường dev. Để đưa hệ thống lên môi trường production sẵn sàng cho giáo viên thật và bên thứ 3:
1. **Phân tách rạch ròi Dev vs Prod**:
   - **Môi trường Prod (Giáo viên)**: Tải plugin qua Internet từ **Backend Cloud Marketplace** (`GET /api/v1/plugins` & `GET /api/v1/plugins/{id}/download`). Tải 1 lần, giải nén vào `%LOCALAPPDATA%/HocLuc/plugins/`, sau đó chạy 100% offline.
   - **Môi trường Dev (Lập trình viên)**: Tự động quét thư mục `plugins/` trong repo hoặc hỗ trợ Sideload kéo-thả `.hlep` để dev test nhanh không cần deploy lên server.
2. **Backend Spring Boot Cloud Marketplace**:
   - Quản lý kho catalog plugin (`PluginEntity` hoặc metadata service).
   - Phục vụ API danh mục kèm thông tin dung lượng, icon, version, permissions.
   - Endpoint download trả về file `.hlep` dạng nhị phân stream.
3. **Tổng vệ sinh Core Flutter (Pure Microkernel Host)**:
   - Xóa bỏ hoàn toàn widget `SubjectToolPalette` (khay công cụ S-V-O hardcode của Tiếng Anh) khỏi `stage_container.dart`.
   - Chuẩn hóa `StudioDocumentDrawer` và `StudioPluginsMarketplacePanel`: Nạp danh mục từ Backend API (kết hợp cache máy), zero hardcoded strings.
4. **Bảo toàn 100% bài kiểm tra bất biến kiến trúc**:
   - Đảm bảo `flutter test test/architecture_test.dart` và toàn bộ backend/frontend unit test đều PASSED.

---

## 2. Phases Overview & Work Breakdown

| Phase | Title | Scope & Output Files |
| :--- | :--- | :--- |
| **Phase 01** | Backend Spring Boot Marketplace API | Viết `PluginMarketplaceController` & `PluginMarketplaceService` trong `backend/api/`. Cung cấp `GET /api/v1/plugins` và `GET /api/v1/plugins/{id}/download`. Tạo unit test `PluginMarketplaceControllerTest`. |
| **Phase 02** | Frontend Cloud Downloader & Cache Manager | Viết `PluginMarketplaceService` trong `frontend/lib/services/`. Tích hợp tải file `.hlep` qua HTTP stream, thanh tiến trình % tải, và giải nén vào AppData. Hỗ trợ fallback offline nếu mất mạng. |
| **Phase 03** | Core Flutter Cleanup & Pure Microkernel | Xóa bỏ `SubjectToolPalette` khỏi canvas bảng phấn; chuyển toàn bộ nút môn học trong `studio_document_drawer.dart` sang nạp động từ Marketplace; chuẩn hóa thanh tiêu đề và SDK bridge. |
| **Phase 04** | End-to-End Verification & Architecture Gate | Kiểm thử luồng: Tải plugin Casio qua API backend -> Cài đặt vào máy -> Mở cửa sổ nổi tính toán; chạy toàn bộ test backend & frontend (5/5 bất biến đạt 100%). |

---

## 3. Risks & Mitigations

1. **Rủi ro mạng chập chờn / mất kết nối khi tải**:
   - *Giải pháp*: Tải theo dạng streaming, kiểm tra tính toàn vẹn của archive trước khi giải nén; nếu lỗi thì xóa file tạm và giữ nguyên trạng thái cũ.
2. **Rủi ro đứt gãy offline khi giáo viên đứng lớp**:
   - *Giải pháp*: Cache metadata và file đã cài vào ổ cứng (`%LOCALAPPDATA%`). Khi mở app không có mạng, app tự lấy danh sách đã cài trong máy để phục vụ ngay lập tức.
3. **Rủi ro vi phạm kiến trúc bất biến (Hardcoded strings)**:
   - *Giải pháp*: Không viết bất kỳ ID nào (`casio`, `english_assistant`...) vào mã nguồn `frontend/lib/`. Kiểm tra liên tục bằng `architecture_test.dart`.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-17 16:05  
**Phase in progress:** Ready to implement  
**Status:** Plan created. Ready for /bb-cook.
