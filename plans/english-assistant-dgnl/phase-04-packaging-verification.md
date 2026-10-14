# Phase 04: Đóng gói Plugin .hlep & Kiểm thử Hoàn thiện

**ID:** `phase-04-packaging-verification`  
**Stories Covered:** P1, P2 (Đóng gói phân phối, Kiểm thử E2E & Hiệu năng)  
**Priority:** P1  

---

## 1. Objective
Cập nhật manifest, đóng gói plugin thành gói `english_assistant.hlep` (zip package chuẩn của Học Lực Studio), kiểm thử end-to-end trên toàn bộ quy trình: từ phân tích đoạn văn đọc hiểu, kiểm tra hiệu năng (<150ms), kiểm tra tính năng ghim bài tập lên bảng vẽ, và bảo đảm tính tương thích ngược với tính năng S-V-O và OCR ban đầu.

---

## 2. Scope & Implementation Tasks

1. **Cập nhật `plugins/english_assistant/manifest.json`:**
   - Nâng phiên bản lên `1.1.0`.
   - Bổ sung mô tả: *"Bóc tách Cú pháp S-V-O, Phân tích Ngữ liệu chuẩn đề ĐGNL (CEFR B2-C1, Academic Collocations) và Tự động tạo bài tập trắc nghiệm đục lỗ (Cloze Test)."*
   - Xác nhận quyền: `"board:insert_annotation"`, `"board:read_text"`.
2. **Kiểm thử hiệu năng và độ ổn định:**
   - Kiểm tra thời gian phản hồi của backend với đoạn văn 300 từ: đo đạc bảo đảm < 150ms.
   - Kiểm tra bộ nhớ RAM tiêu thụ của tiến trình Python khi nạp thêm dữ liệu từ điển: bảo đảm tăng không quá 15MB.
3. **Kiểm thử tương thích ngược (Regression Testing):**
   - Kiểm tra Tab cũ: Tính năng phân tích S-V-O câu đơn lẻ và OCR bảng viết tay vẫn hoạt động chuẩn xác 100%.
4. **Đóng gói file `.hlep` mới:**
   - Nén thư mục plugin thành `plugins/english_assistant.hlep`.
   - Kiểm tra nạp plugin trên TeacherStation Studio: plugin mở mượt mà trong drawer panel, giao diện sắc nét, kết nối sidecar ổn định.

---

## 3. Files & Modules Affected
- `plugins/english_assistant/manifest.json`
- `plugins/english_assistant.hlep`

---

## 4. Dependencies
- Phụ thuộc vào `phase-01-dgnl-engine-rules-data`, `phase-02-dgnl-backend-api`, `phase-03-dgnl-plugin-ui`.

---

## 5. Tests & Acceptance Criteria
- File `english_assistant.hlep` được tạo thành công, có dung lượng hợp lý.
- Kiểm thử E2E:
  1. Khởi chạy plugin trong TeacherStation.
  2. Dán đoạn trích đề thi ĐGNL mẫu.
  3. Bấm "Phân tích Ngữ liệu": Nhận kết quả và các nhãn highlight đa tầng trong < 150ms.
  4. Bấm "Tự động tạo bài tập Cloze": Sinh 3-5 câu trắc nghiệm đục lỗ.
  5. Bấm "Ghim câu hỏi lên bảng": Thẻ câu hỏi xuất hiện trên bảng phấn điện tử.
  6. Chuyển lại Tab S-V-O: Phân tích câu đơn lẻ vẫn hoạt động bình thường.
