# Phase 04: Architecture Tests & Verification

**Parent Plan:** `plans/plugin-architecture-marketplace/plan.md`  
**Stories Covered:** Quality Criteria, Uninstall Story (P2)  
**Risk Tier:** normal  

---

## 1. Goal
Viết bộ kiểm thử kiến trúc tự động (Architecture Unit Tests) để khóa cứng toàn bộ các quy tắc bất biến trong CI/CD, và đóng gói lại `english_assistant.hlep` thành Golden Sample hoàn chỉnh.

---

## 2. Tasks & Detailed Implementation Steps

1. **Xây dựng `frontend/test/architecture_test.dart`**:
   - **Test 1: Zero Hardcoded Plugin Names**:
     - Quét toàn bộ các file `.dart` trong thư mục `frontend/lib/`.
     - Khẳng định không có file nào chứa chuỗi `'english_assistant'`, `'com.hocluc.plugin.english'`, hoặc `'18888'`.
   - **Test 2: Zero Direct Imports**:
     - Khẳng định không có file nào trong `frontend/lib/` import thư mục `plugins/` hoặc ngược lại.
   - **Test 3: Schema Validation**:
     - Đọc và kiểm tra tính hợp lệ của tất cả các file `manifest.json` trong thư mục `plugins/` theo JSON Schema v2.
   - **Test 4: Dynamic Port Supervisor**:
     - Khẳng định logic `findAvailablePort()` luôn trả về cổng khả dụng > 1024 và không bị xung đột.

2. **Đóng gói `english_assistant.hlep` v2 (Golden Sample)**:
   - Chạy script đóng gói nén thư mục `plugins/english_assistant/` thành tệp `plugins/english_assistant.hlep`.
   - Kiểm tra import tệp `.hlep` này vào Teacher Station Desktop thông qua tính năng "Cài đặt từ tệp máy tính".

3. **Chạy kiểm thử toàn diện**:
   - Chạy lệnh `flutter test` toàn bộ suite kiểm thử trong `frontend/`.
   - Chạy kiểm thử thủ công: Bật plugin, phân tích câu văn tiếng Anh, ghim kết quả lên bảng vẽ, đóng plugin, kiểm tra giải phóng RAM và tắt tiến trình con.

---

## 3. Verification Criteria
- [x] Lệnh `flutter test test/architecture_test.dart` chạy thành công với 100% test cases PASSED (5/5).
- [x] Gói `plugins/english_assistant.hlep` đóng gói đúng chuẩn v2, cài đặt và chạy mượt mà trên môi trường Windows Desktop (4/4 tests passed trong english_assistant_e2e_test.dart).
