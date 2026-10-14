# Phase 03: Giao diện Người dùng ĐGNL & Soạn Đề Cloze

**ID:** `phase-03-dgnl-plugin-ui`  
**Stories Covered:** P1 (Multi-layer Highlight UI, Pedagogical Metrics), P2 (Ghim Cloze lên bảng phấn)  
**Priority:** P1  

---

## 1. Objective
Nâng cấp giao diện Webview của Plugin (`plugins/english_assistant/ui/`):
- Bổ sung thanh Tab chuyển đổi linh hoạt: **[Cú pháp S-V-O]** và **[Ôn thi ĐGNL & Cloze Test]**.
- Xây dựng cơ chế hiển thị Multi-layer Highlight (viền cho ngữ pháp, nền cho cụm từ, màu cho từ vựng).
- Bổ sung bảng chỉ số sư phạm (thanh đo Lexical Density và CEFR Profile).
- Bổ sung khu vực xem trước câu hỏi Cloze Test tương tác, hỗ trợ sao chép đề và ghim bài tập lên bảng phấn (`INSERT_ANNOTATION`).

---

## 2. Scope & Implementation Tasks

1. **Cập nhật `index.html`:**
   - Thêm bộ điều hướng Tab ở Header: Tab 1: `S-V-O Syntax`, Tab 2: `Ôn thi ĐGNL`.
   - Trong Tab ĐGNL:
     - Thêm ô nhập liệu lớn hoặc dán đoạn văn bản đọc hiểu.
     - Thêm danh sách mẫu bài đọc chuẩn đề ĐGNL (Sample Passages).
     - Nút hành động: `⚡ Phân tích Ngữ liệu ĐGNL` và `📝 Tự động tạo bài tập Cloze`.
     - Khu vực kết quả phân tích:
       * Khối Thống kê Sư phạm (Pedagogical Metrics card): Thước đo chuẩn ĐGNL, thanh % từ vựng A1–B1 vs B2 vs C1–C2, chỉ số Lexical Density.
       * Khối Văn bản Đa tầng (Multi-layer Highlight Text): Khung chứa văn bản bôi màu trực quan, có chú giải màu sắc (Legend).
     - Khu vực Bài tập Cloze Test: Danh sách thẻ câu hỏi trắc nghiệm (Thẻ câu hỏi, các nút phương án A/B/C/D, nút hiện lời giải, nút "📌 Ghim câu hỏi lên bảng").
2. **Cập nhật `style.css`:**
   - Định kiểu cho Multi-layer Highlight:
     - `.highlight-grammar`: Đường viền nét đứt màu xanh dương `#3B82F6` kèm tooltip nhãn.
     - `.highlight-collocation`: Nền xanh lá `#10B981` độ trong 20%.
     - `.highlight-cefr-b2`: Nền vàng cam `#F59E0B` độ trong 25%, chữ đậm.
     - `.highlight-cefr-c1`: Nền tím `#8B5CF6` độ trong 25%, chữ đậm.
   - Thước đo chỉ số sư phạm (Progress bar nhiều màu sắc, huy hiệu đánh giá "Chuẩn ĐGNL").
   - Thiết kế thẻ bài tập trắc nghiệm đục lỗ chuẩn UX giao diện học tập hiện đại.
3. **Cập nhật `app.js`:**
   - Logic chuyển đổi tab không làm mất trạng thái dữ liệu.
   - Hàm `renderMultiLayerText(text, highlights)`: Cắt văn bản thành các token/span an toàn, tránh lỗi thẻ HTML lồng nhau.
   - Tích hợp gọi API `http://127.0.0.1:18888/api/dgnl/analyze` và `/api/dgnl/generate-cloze`.
   - Cơ chế Fallback offline: Nếu không kết nối được FastAPI, vẫn có bộ regex offline bóc tách các điểm ngữ pháp cơ bản và collocations thông dụng.
   - Xử lý sự kiện "📌 Ghim câu hỏi lên bảng": Gửi `postMessage` tới host WebView2/Iframe với định dạng thẻ bài tập để hiển thị trực tiếp lên bảng phấn điện tử.

---

## 3. Files & Modules Affected
- `plugins/english_assistant/ui/index.html`
- `plugins/english_assistant/ui/app.js`
- `plugins/english_assistant/ui/style.css`

---

## 4. Dependencies
- Phụ thuộc vào `phase-02-dgnl-backend-api` (Để gọi REST endpoints).

---

## 5. Tests & Acceptance Criteria
- Chuyển đổi qua lại giữa 2 Tab mượt mà, không giật lag.
- Dán đoạn văn bản mẫu -> Bấm "Phân tích Ngữ liệu ĐGNL" -> Hiển thị chính xác các highlight với kiểu dáng đa tầng (viền xanh ngữ pháp, nền xanh lá collocation, highlight vàng cam từ vựng).
- Bấm vào một điểm highlight -> Hiển thị thông tin ghi chú ngữ pháp / CEFR level tương ứng.
- Khối thống kê sư phạm hiển thị đầy đủ tỷ lệ % và nhận xét chuẩn đề thi ĐGNL.
- Bấm "Tự động tạo bài tập Cloze" -> Hiển thị danh sách câu hỏi trắc nghiệm có thể bấm chọn đáp án thử và xem lời giải.
- Bấm "📌 Ghim câu hỏi lên bảng" -> Phát tín hiệu `postMessage` thành công.
