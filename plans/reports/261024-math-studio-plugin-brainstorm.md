# Brainstorm: Plugin Môn Toán Học Lực (Math Studio Plugin — Lấy Cảm Hứng Từ NoteRenderer)

**Date:** 2026-10-24  
**Status:** Completed  
**Slug:** `math-studio-plugin`

---

## 1. Problem Context & Inspiration
* **Inspiration:** Tài liệu và tính năng từ phần mềm chuyên sâu **NoteRenderer** (55 trang tài liệu hướng dẫn) và video thực tế mentor chia sẻ:
  - Lập Bảng biến thiên tự động (Auto Variation Table) chuẩn sách giáo khoa Việt Nam.
  - Khảo sát & Vẽ đồ thị hàm số 2D (cực trị, giao Ox/Oy, tiệm cận, tô miền diện tích tích phân).
  - Dựng hình học không gian 3D và tọa độ Oxyz xoay đa hướng.
  - Miền nghiệm hệ bất phương trình bậc nhất hai ẩn (Quy hoạch tuyến tính Toán 10).
* **Nỗi đau thực tế của Giáo viên Toán:**
  - Kẻ bảng biến thiên thủ công bằng bút phấn trên bảng vẽ rất tốn thời gian, nét kẻ xiêu vẹo, viết lại các giá trị giới hạn $-\infty, +\infty$ lâu.
  - Vẽ đồ thị hàm số bằng tay khó đạt độ chuẩn xác về hình dáng cong và tiệm cận.
  - Phần mềm bên ngoài (GeoGebra/Desmos) cồng kềnh, không thể chèn kết quả trực tiếp thành nét vẽ/sticker vào bảng Studio Board để thầy cô cầm bút phấn viết đè lên giảng tiếp.

---

## 2. Ideas Explored & Evaluated

### Ý tưởng 1: Hardcode các công cụ Toán học trực tiếp vào Core Flutter (`frontend/lib/`)
* **Đánh giá:** **BÁC BỎ TUYỆT ĐỐI (Vi phạm Hard Invariants)**. Quy tắc kiến trúc của dự án cấm hardcode tên plugin, môn học hoặc logic riêng biệt vào Core Host Flutter. Bắt buộc phải là Plugin độc lập.

### Ý tưởng 2: Micro-Plugins tách rời (Mỗi công cụ 1 plugin riêng)
* **Đánh giá:** Tách rời bảng biến thiên, đồ thị, hình 3D thành 3–4 plugin nhỏ. Dù modular cao nhưng gây phân mảnh trải nghiệm cho giáo viên dạy Toán (phải mở nhiều cửa sổ cùng lúc).

### Ý tưởng 3: "Math Studio Suite" Plugin (All-in-One Floating & Sidebar Window) — ĐƯỢC CHỌN
* **Đánh giá:** **TỐI ƯU NHẤT**.
  - Một plugin độc lập `plugins/math_studio/` tuân thủ Schema v2.1.
  - Chạy giao diện Webview linh hoạt: mặc định mở dạng **Cửa sổ nổi (Floating Window)** giống máy tính Casio (kéo di chuyển, co giãn kích thước), đồng thời hỗ trợ chế độ mở rộng sang ngăn bên (Sidebar Panel) khi cần diện tích xem trước lớn.
  - Chạy thuật toán toán học 100% bằng JavaScript offline (không cần backend server, khởi động tức thì trong 50ms).
  - Nút **`[ Chèn Lên Bảng Vẽ ]`**: Xuất ảnh trong suốt (PNG/SVG) của Bảng biến thiên hoặc Đồ thị rồi gọi SDK `window.HocLuc.board.insertSticker` đưa thẳng lên canvas Studio Board.

---

## 3. Lộ Trình Phân Kỳ Ưu Tiên (Phased Implementation Strategy)

Người dùng đã thống nhất thứ tự ưu tiên:
* **Giai đoạn 1 (MVP — Ưu tiên số 1): Nhóm Đại số & Giải tích THPT**
  - Lập Bảng biến thiên tự động (Hàm bậc 3, bậc 4 trùng phương, phân thức bậc nhất/bậc nhất, phân thức bậc hai/bậc nhất).
  - Khảo sát & Vẽ đồ thị hàm số 2D (cực trị, giao Ox/Oy, đường tiệm cận đứng, ngang, xiên).
  - Tô màu / Gạch sọc miền diện tích tích phân hình phẳng.
  - Tính năng Chèn vào bảng vẽ Studio Board.
* **Giai đoạn 2 (Tiếp theo): Nhóm Hình học không gian 3D & Oxyz**
  - Dựng hình khối 3D (chóp, lăng trụ, nón, trụ, cầu) với cơ chế xoay đa hướng, tự động đổi nét khuất thành nét đứt.
  - Hệ trục tọa độ Oxyz 3D.
* **Giai đoạn 3 (Hoàn thiện): Nhóm Đại số 10 & Nâng cao**
  - Miền nghiệm hệ bất phương trình bậc nhất 2 ẩn (Quy hoạch tuyến tính).
  - Tích hợp Smart Pen OCR (khoanh đề bài $\rightarrow$ tự động điền hàm số vào Math Studio).

---

## 4. Công Nghệ Đề Xuất Cho Plugin

1. **Giao diện & Điều khiển:** HTML5, CSS3 hiện đại, Vanilla JS hoặc Svelte/React nhẹ.
2. **Thư viện Toán học:**
   - **KaTeX / MathQuill:** Render và gõ công thức Toán học trực quan.
   - **mathjs / Algebrite:** Thư viện Computer Algebra System (CAS) tính đạo hàm $y'$, giải phương trình nghiệm $y'=0$, tính giới hạn.
   - **JSXGraph / Function-Plot:** Vẽ đồ thị 2D mượt mà, hỗ trợ tô màu miền diện tích tích phân.
3. **Giao tiếp Host Bridge:** `hocluc-plugin-sdk.js` với quyền `board:insert_annotation` (hoặc `board:insert_sticker`).

