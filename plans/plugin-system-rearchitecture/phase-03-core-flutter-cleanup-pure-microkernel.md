# Phase 03: Core Flutter Cleanup & Pure Microkernel Boundary

**Goal:** Dọn dẹp triệt để các tàn dư hardcode môn học trong Core Flutter, biến Teacher Station thành một Microkernel Host trung lập thực thụ (Zero Subject-specific Logic).

---

## 1. Scope & Action Items

1. **Loại bỏ `SubjectToolPalette` khỏi canvas bảng phấn:**
   - Xóa `SubjectToolPalette` khỏi `stage_container.dart`.
   - Các tính năng S-V-O, highlight cú pháp Tiếng Anh được đưa về hoạt động 100% bên trong UI Webview của chính plugin Tiếng Anh.
2. **Dọn dẹp `StudioDocumentDrawer`:**
   - Xóa dòng chữ cứng `"Cài đặt Plugin Mẫu (Trợ giảng Tiếng Anh)"`.
   - Nút "Cài thêm tiện ích môn" chỉ đơn thuần mở bảng Kho Tiện ích (Marketplace Panel) hoặc hiển thị danh sách plugin động lấy từ `PluginManager`.
3. **Chuẩn hóa `HostBridge` & `BoardSticker`:**
   - Đảm bảo `HostBridge` nhận mọi loại sticker (text, latex, image, table, formula) từ bất kỳ plugin nào mà không gán cứng theo token `SUBJECT/VERB/OBJECT`.
4. **Kiểm tra Zero Hardcoded Names:**
   - Đảm bảo không còn bất kỳ chuỗi tên plugin hay mã ID cụ thể nào nằm trong `frontend/lib/`.

---

## 2. Verification Criteria
- [ ] Không còn widget hardcode môn học nào (`SubjectToolPalette`) trên canvas bảng phấn.
- [ ] Mở máy tính Casio không bị lẫn bất kỳ nút hay tính năng nào của môn khác.
- [ ] 5/5 bất biến kiến trúc trong `architecture_test.dart` tiếp tục đạt 100% PASSED.
