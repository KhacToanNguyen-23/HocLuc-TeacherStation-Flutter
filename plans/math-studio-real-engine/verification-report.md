# Báo Cáo Kiểm Chứng Chạy Thật: Math Studio Real Engine + Excalidraw

**Ngày thực hiện:** 2026-10-29  
**Kế hoạch:** `plans/math-studio-real-engine/plan.md`  
**Quy cách:** `plans/math-studio-real-engine/spec.md`  

---

## I. Đã chạy thật & Đạt 100% bằng kiểm chứng tự động

Tất cả các lệnh dưới đây đã được thực thi trực tiếp trên máy và ghi nhận output thực tế (không dùng cổng kiến trúc để thay thế kiểm chứng chức năng).

### 1. Kiểm thử TDD Engine toán học (`node --test engine/tests/engine.test.mjs`)
- **Kết quả:** 13/13 tests PASS (436 ms)
- **Minh chứng chức năng:**
  - **Sửa triệt để lỗi cũ (y' hardcode):** Nhập `2x^2 - 3x + 1` tính đúng đạo hàm $y' = 4x - 3$, cực tiểu $(0.75; -0.125)$, nghiệm $x = 0.5$ và $1.0$.
  - **Khảo sát hàm bậc 3:** `x^3 - 3x` tính đúng cực đại $(-1; 2)$, cực tiểu $(1; -2)$, điểm uốn $(0; 0)$, tiếp tuyến tại $x_0=2$ là $y = 9x - 16$, số nghiệm $y = m$ ($m=0 \to 3, m=2 \to 2, m=3 \to 1$).
  - **Hàm phân thức:** `(2x+1)/(x-1)` phát hiện đúng tiệm cận đứng $x = 1$, tiệm cận ngang $y = 2$, không có cực trị.
  - **Phân thức bậc 2 trên bậc 1:** `(x^2+x+1)/(x-1)` phát hiện đúng tiệm cận đứng $x = 1$, tiệm cận xiên $y = x + 2$, cực trị tại $1 \pm \sqrt{3}$.
  - **Lượng giác, mũ, căn, logarit:** `sin(x)` ($y' = \cos(x)$), `e^(-x^2)` (cực đại $(0; 1)$, ngang $y=0$), `sqrt(4-x^2)` (tập xác định $[-2; 2]$), `ln(x)` (đứng $x=0$, nguyên hàm $x\ln x - x$).
  - **Hội tụ Riemann:** $\sqrt{x}$ trên $[0, 4]$, tích phân chuẩn $16/3 \approx 5.3333$, sai số trung điểm $n=50$ đạt $\le 1\%$.
  - **Thể tích tròn xoay Ox:** $V = \pi \int_0^4 x dx = 8\pi \approx 25.1327 \pm 0.01$.
  - **Không dùng bảng tra:** Quét source code đảm bảo 0 chuỗi regex mapping cố định; 5 đa thức ngẫu nhiên sinh ra khớp đạo hàm số.

### 2. Kiểm thử TDD Dựng Scene Excalidraw (`node --test engine/tests/stage.test.mjs`)
- **Kết quả:** 7/7 tests PASS (142 ms)
- **Minh chứng chức năng:**
  - Trục toạ độ Oxy tránh đè nhãn (collision-free label bounding boxes).
  - Đường cong ngắt đoạn tại tiệm cận (không nhảy qua tiệm cận đứng $x=1$).
  - Đánh dấu cực trị, tiếp tuyến xoay theo độ dốc, $n$ cột hình chữ nhật Riemann.
  - Khối tròn xoay 3D tuân thủ quy tắc nét khuất: cung sau ($z < 0$) là nét đứt (`dashed`), cung trước ($z \ge 0$) là nét liền (`solid`); trần số phần tử $\le 400$ đảm bảo mượt mà.

### 3. Kiểm thử E2E Trình duyệt Headless (`node engine/tests/e2e/e2e_full_verification.mjs`)
- **Kết quả:** ALL PASSED (100%), 0 request mạng ra ngoài, 0 console error.
- **Minh chứng:**
  - Chạy trên Microsoft Edge 120+ qua mock `PluginWebServer` (máy chủ tĩnh cục bộ).
  - Tải toàn bộ font offline: `Assistant` và `Virgil` phục vụ Excalidraw từ local `ui/dist/fonts/`.
  - Nhập lần lượt 8 hàm số: hiển thị chính xác $y'$ và các thông số trong thời gian $< 150$ ms.
  - Chuyển tab 2: Render đầy đủ SVG Bảng Biến Thiên theo chuẩn SGK Việt Nam.
  - Chuyển tab 3: Bật khối tròn xoay 3D, điều khiển góc quay bằng chuột.
  - Bấm "Ghim vào bảng": Sinh ảnh PNG Base64 kích thước 735 KB, gọi đúng `window.HocLuc.board.insertAnnotation(...)`.
  - Bấm "Đóng": Gọi đúng `window.HocLuc.close()`.
- **Ảnh chụp màn hình thực tế lưu tại:**
  - `plans/math-studio-real-engine/evidence/graph-2x2-3x+1.png`
  - `plans/math-studio-real-engine/evidence/graph-x3-3x.png`
  - `plans/math-studio-real-engine/evidence/bbt-x3-3x.png`
  - `plans/math-studio-real-engine/evidence/integral-riemann-sqrt-x.png`
  - `plans/math-studio-real-engine/evidence/solid3d-revolution-sqrt-x.png`

### 4. Kiểm chứng Đóng gói & Ranh giới Kiến trúc
- `node scripts/validate_plugins.mjs`: **0 lỗi** (4 plugins Schema v2.1 đồng bộ 100%).
- `flutter test test/architecture_test.dart`: **12/12 invariants đạt** (100%).
- `flutter analyze --no-fatal-infos`: **0 issues found**.
- `plugins/math_studio.hlep`: Đã đóng gói thành công (23.2 MB uncompressed zip gồm toàn bộ offline fonts và bundle).

---

## II. Checklist người dùng kiểm tra trên ứng dụng Flutter Desktop thật

Vì môi trường agent không có quyền thao tác trực tiếp trên giao diện cửa sổ Native Windows / Flutter GUI của người dùng, xin mời người dùng kiểm tra 6 bước sau khi mở ứng dụng:

- [ ] **Bước 1 — Mở Plugin:** Vào mục Bảng công cụ hoặc Marketplace trên thanh công cụ Bảng đen, chọn **Học Lực Math Studio**. Cửa sổ plugin mở ra mượt mà trong chế độ modal.
- [ ] **Bước 2 — Nhập hàm số:** Gõ `2x^2 - 3x + 1`. Kiểm tra dòng $y'$ bên dưới hiển thị ngay lập tức $4x - 3$ (không còn bị $3x^2 - 3$ như bản cũ).
- [ ] **Bước 3 — Tương tác 2 chiều:** Kéo thanh trượt $x_0$ hoặc kéo trực tiếp điểm $M$ trên đồ thị Excalidraw: điểm $M$ bám chính xác trên đường cong parabol và đường tiếp tuyến đổi hướng theo độ dốc. Kéo thanh trượt $m$ để xem số nghiệm giao điểm đổi theo thời gian thực.
- [ ] **Bước 4 — Tab Bảng biến thiên:** Bấm tab "Bảng biến thiên": bảng biến thiên chuẩn SGK hiện ra sắc nét với các hàng $x$, $y'$, $y$, các dấu $+/-$ và mũi tên tăng giảm.
- [ ] **Bước 5 — Tab Tích phân & Tròn xoay 3D:** Bấm tab "Tích phân & Tròn xoay", gõ $a=0, b=4$. Bật công tắc "Khối tròn xoay 3D": khối tròn xoay xuất hiện với nét liền phía trước và nét đứt phía sau; giữ chuột kéo trên canvas để xoay mô hình theo các góc nhìn.
- [ ] **Bước 6 — Ghim vào bảng đen:** Bấm nút màu xanh **"📌 Ghim vào bảng"**: thẻ đồ thị xuất hiện ngay trên Bảng đen lớp học với 8 điểm neo co giãn và xoay tự do.
- [ ] **Bước 7 — Kiểm tra Offline:** Ngắt kết nối Wi-Fi/Internet và mở lại plugin: toàn bộ font chữ, đồ thị và phép tính toán hoạt động bình thường 100%.

