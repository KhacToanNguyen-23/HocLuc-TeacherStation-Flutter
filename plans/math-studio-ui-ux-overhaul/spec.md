# Spec: Math Studio Plugin — High-End Visual Design & Clean CAS Architecture Overhaul

**Date:** 2026-10-27
**Status:** Approved & Ready for `/bb-plan`

---

## Problem Statement
`math_studio` currently suffers from slow WebView2 cold starts, coarse/blurred text rendering, overlapping coordinate labels, stiff non-SGK axes/arrows, hardcoded math state (`type: 'cas_function'`, regex asymptotes, `x^3 - 3*x` init side-effects), ~970 lines of dead/orphaned code, broken UI controls (`Giao Ox`, `Giao Oy`, `Cực trị`, `+ Thêm điểm`, `KHUNG NHÌN HỆ TRỤC`), 8 fake buttons on the chalkboard sticker toolbar, and invisible 3D geometry exports.

---

## 1. Hạ tầng Code & Kiến trúc Toán học (Zero Hardcode, AST-Driven Pipeline)

### 1.1. Tại sao Hardcode Toán học hiện tại là Anti-Pattern nghiêm trọng?
- Gán cứng `type: 'cas_function'` và dùng Regex `/\/\s*\(...\)/` khiến hệ thống "mù" cấu trúc đại số: không phân biệt được hàm đa thức bậc 1, 2, 3, 4 hay phân thức hữu tỉ $\frac{P(x)}{Q(x)}$, không rút gọn được đạo hàm phân thức, không tìm được tiệm cận của `1/x` hay hàm có mẫu bất kỳ, và làm chết 250 dòng code nội suy.
- Chạy `store.init()` đồng bộ trên hàm gán cứng `x^3 - 3*x` ngay khi nạp file JS gây lãng phí CPU và ghi đè dữ liệu khi giáo viên bấm "Sửa" một đồ thị có sẵn trên bảng.

### 1.2. Kiến trúc Toán học Chuyên nghiệp (Single AST Pipeline)
```
Chuỗi nhập (Raw Input)
   │
   ▼
[1. Tokenizer & Parser (symbolic_cas.js)] ──► Cây cú pháp AST chuẩn (1 nguồn duy nhất)
   │
   ├──► [2. Algebraic Classifier & Polynomial Extractor]
   │       • Tự động phân tích đa thức P(x) / Q(x) từ AST (không dùng Regex)
   │       • Trả về: family ('linear'|'quadratic'|'cubic'|'quartic'|'rational'|'general'),
   │                 bậc tử/mẫu, hệ số chuẩn {a, b, c, d, e}
   │
   ├──► [3. Symbolic Differentiator & Rational Simplifier]
   │       • Đạo hàm đúng quy tắc + thu gọn đa thức tử số (VD: ((2x+1)/(x-1))' -> -3/(x-1)²)
   │       • Xuất ra HTML Toán học chuẩn (phân số 2 tầng .frac, số mũ <sup>, căn √)
   │
   └──► [4. Numerical Solver (math_cas.js & integral_solver.js)]
           • Tiệm cận đứng: Giải nghiệm mẫu số Q(x) = 0 mà P(x) ≠ 0
           • Tiệm cận ngang / xiên: Tính giới hạn a = lim f(x)/x, b = lim (f(x) - ax)
           • Cực trị & Giao điểm Ox, Oy: Hybrid Bisection + Newton-Raphson
           • Tích phân & Diện tích: Tự động cắt khoảng [a, b] tại mọi nghiệm f(x) = 0
             trước khi chạy Adaptive Simpson + Khôi phục phân số tối giản (15/4, 21/4)
```

### 1.3. Dọn dẹp Hạ tầng File (`Zero Dead Code`)
- **XÓA BỎ 5 file dư thừa/lỗi thời**:
  1. `ui/core/expression_parser.js` (wrapper rỗng không ai gọi)
  2. `ui/core/curve_manipulator.js` (kéo cực trị làm méo hàm và gây giật board)
  3. `ui/render/graph_plotter.js` (bộ vẽ SVG 2D tĩnh cũ đã bị thay bởi `graph_board.js`)
  4. `ui/render/revolution_solid_plotter.js` (module mồ côi)
  5. `ui/sdk.js` (file SDK cũ thiếu `close()` và `onMessage()`; chuyển sang dùng auto-injected `/__hocluc_sdk__/hocluc-plugin-sdk.js` chuẩn của `PluginWebServer`)

---

## 2. Tái cấu trúc UI/UX theo chuẩn `/high-end-visual-design` & Bảng Quyết định Giữ / Bỏ

### 2.1. Ngôn ngữ Thiết kế (`/high-end-visual-design` — Archetype: *Soft Structuralism + Academic Editorial*)
- **Typography (Cấm dùng Arial / Courier / Roboto thô)**:
  - **UI Typography**: `Plus Jakarta Sans`, `Geist`, `Segoe UI Variable Display` (cỡ chữ chẵn `12px`, `13px`, `14px`, `16px`; tuyệt đối bỏ các cỡ chữ lẻ `10px`, `10.5px`, `11.5px` + `bold` gây vỡ hạt).
  - **Math & Coordinate Typography**: `STIX Two Math`, `Cambria Math`, `Times New Roman` (biến số $x, y, O, A, B, C, S$ luôn in nghiêng `italic`; số trục và công thức phân số 2 tầng sắc nét).
  - **ClearType & Pixel-Snapping**: Đặt `background: #F8FAFC` đặc cho `body` để bật lại khử răng cưa ClearType trên Windows; làm tròn tọa độ Modal trong `FloatingPluginWindow` (`roundToDouble()`) để không bao giờ bị nhòe nửa pixel (`0.5px`).
- **Cấu trúc Thẻ "Double-Bezel" (Doppelrand Hardware Tray)**:
  - Cột điều khiển bên trái (`340px` gọn gàng) là một khay nhôm mờ (`background: rgba(15, 23, 42, 0.035)`, `border: 1px solid rgba(15, 23, 42, 0.06)`, `padding: 8px`, `border-radius: 20px`).
  - Các thẻ con bên trong (`Inner Core`) nổi lên với nền trắng tinh (`#FFFFFF`), `border-radius: 14px`, bóng khuếch tán mềm (`0 4px 20px -2px rgba(15, 23, 42, 0.05)`) và viền sáng nội bộ.
- **Chuyển động & Nút bấm ("Fluid Island" & Spring Physics)**:
  - Thanh chuyển chế độ (`Đồ thị` | `Bảng biến thiên` | `Tích phân` | `Hình 3D SGK`) thiết kế dạng **Floating Pill Island** (`border-radius: 999px`).
  - Mọi hiệu ứng chuyển trạng thái dùng đường cong vật lý `cubic-bezier(0.32, 0.72, 0, 1)` (chỉ animate `transform` và `opacity`).
  - Nút chính **`Ghim vào bảng`** thiết kế dạng **Pill Button-in-Button** (`rounded-full`, icon ghim nằm trong vòng tròn riêng bên phải trượt nhẹ khi hover, `active:scale-[0.98]`).
- **Đồ thị Chuẩn LaTeX TikZ / SGK THPT**:
  - **Đầu mũi tên trục $Ox, Oy$**: Dáng cánh én sắc mảnh (Stealth Arrow tỉ lệ $2.2 : 1$, lõm nhẹ ở đuôi), chấm cực trị nhỏ gọn (`3.2px` viền trắng `1.5px`).
  - **Đường gióng & Nhãn tọa độ**: Đường gióng nét đứt mảnh (`stroke-dasharray: 3.5, 3.5`, `1px`). Tự động in giá trị hoành độ $x_0$ và tung độ $y_0$ ngay tại **chân đường gióng trên trục $Ox, Oy$** và tự động ẩn vạch chia thường bị trùng gần đó. Nhãn điểm (`CĐ`, `CT`, giao điểm) có `anchor` + pixel offset thông minh đẩy ra hướng pháp tuyến ngoài đường cong, có lớp đệm nền (`halo` 2.5px) để đường cong đi qua số không bao giờ đè chữ.

### 2.2. Bảng Quyết định Cắt Bỏ / Giữ Lại (Keep vs. Drop Matrix)

| Khu vực | Thành phần UI | Quyết định | Lý do & Thay thế chuyên nghiệp |
| :--- | :--- | :---: | :--- |
| **Modal Đồ thị** | Kéo điểm cực trị để biến dạng hàm số (`curve_manipulator.js`) | ❌ **BỎ HẲN** | Làm giật đồ thị, sinh hàm thập phân rác khi vô tình chạm chuột. Khóa cố định (`fixed: true`) toàn bộ điểm cực trị/giao điểm. |
| **Sidebar Trái** | Thẻ `KHUNG NHÌN HỆ TRỤC` (6 ô nhập `x từ`, `x đến`, `y từ`, `y đến`, `Vạch x`, `Vạch y`) | ❌ **BỎ HẲN** | Không đồng bộ khi Pan/Zoom, không ai nhập tay 6 ô số trên lớp. Thay bằng **Auto-Fit SGK** + cụm 3 nút nổi `[+] [−] [⟲]` ở góc phải dưới đồ thị. |
| **Tab Tích phân** | Nút `Tính toán` + 2 ô kết quả lặp nhau `S ≈ 3.7501` + Nhãn `∫ = -0.7500` trên đồ thị | ❌ **BỎ HẲN** | Gây rối và mâu thuẫn số liệu. Tự động tính ngay khi gõ cận `a, b`; tắt nhãn `∫` thừa trên đồ thị; hiển thị rõ 2 dòng: **Tích phân $I$** và **Diện tích $S$** (kèm phân số $\frac{15}{4}$). |
| **Thanh nổi trên Bảng đen** | 8 nút giả/trùng: `Phát quay`, `Góc nhìn: Sách GK`, `Trước`, `Trên`, `Bên`, `Xoay 3D`, `Sao chép`, `Cắt` | ❌ **BỎ HẲN** | Toàn bộ 6 nút đầu đều chỉ gọi hàm `onEdit` giả tạo; `Sao chép` trùng `Nhân bản`; `Cắt` trùng `Xóa`. |
| **Thanh nổi trên Bảng đen** | 3 nút cốt lõi: **`✎ Sửa`**, **`⧉ Nhân bản`**, **`🗑 Xóa`** | ✅ **GIỮ & TINH GỌN** | Đóng gói trong thanh Pill nhỏ gọn (`~210px`), bấm phát ăn ngay. |
| **Thẻ HÀM SỐ** | Ô nhập + Khung hiển thị Toán học + Dòng Đạo hàm / Nguyên hàm + 4 chấm chọn màu + Chip hàm mẫu SGK | ✅ **NÂNG CẤP** | Hiển thị công thức Toán học chuẩn ($x^3 - 3x$, phân số 2 tầng $\frac{2x+1}{x-1}$), nút gõ nhanh `x²`, `x³`, `a/b`, `√` và đổi màu đường cong thật. |
| **Thẻ ĐIỂM** | Các nút `Cực trị`, `Giao Ox`, `Giao Oy`, `+ Thêm điểm` + Danh sách tọa độ | ✅ **SỬA CHẠY THẬT** | Nối `markedPoints` và `showExtrema` vào `graph_board.js` để bật/tắt tức thì trên cả đồ thị và danh sách. |
| **Tab Hình 3D SGK** | Ô nhập đề bài Hình học tiếng Việt + 6 nút khối mẫu SGK + Khung xoay 3D | ✅ **NÂNG CẤP** | Thêm bộ đọc đề tiếng Việt tự dựng đường cao ($SA \perp \text{đáy}$, $SO \perp \text{đáy}$), trung điểm $M, N$, hình chiếu $H$; bỏ 3 trục $Oxyz$ thừa; xuất ra bảng đen rõ nét 100%. |

---

## 3. Cơ chế Di chuyển & Tương tác Đồ thị (Graph Navigation Mechanics)

1. **Tự động Căn khung Chuẩn SGK (`Auto-Fit SGK Bounding Box`)**:
   - Khi nhập hàm số mới, hệ thống gom tất cả tọa độ quan trọng (cực trị `CĐ/CT`, giao điểm `Ox/Oy`, giao điểm các đường tiệm cận `TCĐ/TCN/TCX`) để tính khung nhìn tối ưu sao cho đồ thị nằm gọn ở trung tâm với khoảng thở 35% xung quanh.
2. **Kéo Dịch chuyển (Pan) & Thu phóng (Zoom) 60fps**:
   - Vì các điểm `CĐ`, `CT`, `Giao Ox`, `Giao Oy` đã được khóa cố định (`fixed: true`), giáo viên kéo chuột ở **bất kỳ đâu trên mặt phẳng đồ thị** đều là thao tác **Pan (dịch chuyển hệ trục)** mượt mà, không bao giờ sợ kéo nhầm làm hỏng hàm số.
   - Khi Zoom bằng con lăn chuột hoặc nút `[+] / [−]` trên góc đồ thị, bước chia vạch (`tickStep`) tự động co giãn thông minh theo cấp số chuẩn (`0.5` $\to$ `1` $\to$ `2` $\to$ `5` $\to$ `10`) để số trên trục không bao giờ quá dày hay quá thưa.
3. **Bảo toàn Khung nhìn (Viewport Preservation)**:
   - Khi giáo viên bật/tắt `Cực trị`, `Giao Ox`, `Giao Oy`, đổi màu đường cong, hoặc thêm điểm mới, hệ thống **chỉ cập nhật lớp điểm trên board hiện tại (hoặc giữ nguyên `board.getBoundingBox()`)**, tuyệt đối không reset mất góc nhìn giáo viên vừa căn chỉnh.
   - Bấm nút **`[⟲]` (Reset View)** ở góc dưới đồ thị sẽ đưa khung nhìn về lại trạng thái chuẩn SGK ban đầu.

---

## 4. Kiến trúc UI & Hiển thị Sau khi Ghim vào Bảng (Post-Pin Chalkboard Experience)

1. **Bộ chuyển đổi Màu sắc Kép Tự động (`Dual-Theme Chalkboard Serializer`)**:
   - Khi bấm **`Ghim vào bảng`**, `board_exporter.js` chuyển toàn bộ SVG sang **Bảng màu Phấn Tương phản cao (High-Luminance Chalk Palette)** trên nền trong suốt:
     - Hệ trục tọa độ, mũi tên, vạch chia, chữ số trục, cạnh nhìn thấy của hình 3D (`#0f172a`, `#0b2348`) $\to$ **Phấn Trắng sắc nét (`#F8FAFC`)**.
     - Đường cong hàm số: Đỏ sẫm/Xanh đậm trên nền trắng được nâng độ sáng lên **Phấn Vàng (`#FACC15`)**, **Xanh Cyan sáng (`#38BDF8`)**, **San hô sáng (`#FB7185`)**, hoặc **Xanh Ngọc (`#34D399`)** — nổi bật tuyệt đối trên nền bảng xanh đen `#0F1E19`.
     - Đường gióng & Cạnh khuất 3D nét đứt $\to$ **Trắng mờ (`rgba(248, 250, 252, 0.65)`)**.
     - Nhúng trực tiếp `font-family`, `font-size`, `font-style="italic"`, `font-weight` vào từng thẻ XML `<text>` (không phụ thuộc file CSS ngoài) để `SvgPicture.string` của Flutter vẽ chuẩn 100%.
2. **Thẻ Sticker & Thanh Công cụ Nổi Tinh gọn (`BoardStickerCard` & `BoardStickerFloatingBar`)**:
   - Khi không chọn: Đồ thị / Hình 3D / Bảng biến thiên nằm tiệp hoàn toàn vào mặt bảng phấn như giáo viên vẽ bằng phấn màu.
   - Khi bấm chọn: Hiện khung nét đứt mảnh kèm nhãn tên tiếng Việt chuẩn (ví dụ: `Đồ thị: y = x³ − 3x`, `Hình chóp S.ABCD (SA ⊥ đáy)`) và thanh công cụ nổi gọn (`width: 220px`) chỉ gồm **3 nút thực chất**: **`✎ Sửa`** | **`⧉ Nhân bản`** | **`🗑 Xóa`**.
   - Xóa bỏ đoạn code hardcode `p.manifest.id.contains('math')` trong `interactive_chalkboard.dart:271` (dùng đúng `sticker.type` để tra cứu plugin trong `PluginManager`).

---

## 5. Ma trận Sự kiện – Hành động (Event-Driven Lifecycle Matrix)

| Sự kiện (User / System Event) | Hành động xử lý chuẩn (Action Pipeline) |
| :--- | :--- |
| **1. Mở mới Plugin từ Thanh công cụ** | • Host kiểm tra URL có кэш `vendor/jsxgraphcore.js` (`max-age=86400`), căn khung Modal tọa độ chẵn (`roundToDouble()`).<br>• `store` đọc `window.location.search`: nếu không có `editId`, khởi tạo hàm mẫu mặc định chuẩn SGK, tự động `autoFitBounds` và vẽ đồ thị 2D. |
| **2. Bấm `✎ Sửa` trên Sticker ở Bảng đen** | • Host truyền `editId`, `formula`, `view`, `a`, `b`, `preset`, `problemText` qua URL & `window.__hocluc_load_edit`.<br>• `store` nạp thẳng trạng thái của sticker đó (không chạy hàm mặc định `x^3 - 3*x`), mở đúng Tab (`graph` / `bbt` / `integral` / `geometry3d`) và khi bấm `Ghim vào bảng` sẽ **cập nhật đè lên đúng `stickerId` đang sửa**. |
| **3. Gõ vào ô Hàm số (`#mathInput`) hoặc bấm nút Ký hiệu / Hàm mẫu** | • Cập nhật ngay lập tức **Khung hiển thị Toán học trực quan** (số mũ $x^3$, phân số 2 tầng $\frac{u}{v}$).<br>• Qua bộ lọc **Debounce `120ms`**: Nếu biểu thức đang gõ dở (ví dụ `x^` hoặc `(2x+1)/`), giữ nguyên đồ thị cũ và chỉ hiện trạng thái nhẹ `"Đang nhập..."` (không xóa trắng đồ thị hay báo lỗi đỏ gắt). Khi biểu thức hợp lệ $\to$ chạy AST Classifier + CAS $\to$ cập nhật đường cong, đạo hàm/nguyên hàm. |
| **4. Bấm các nút `Cực trị`, `Giao Ox`, `Giao Oy`** | • Dispatch `TOGGLE_POINT_MARK` $\to$ Giữ nguyên khung nhìn (`boundingbox`) hiện tại của đồ thị, bật/tắt hiển thị các điểm + đường gióng + số chân đường gióng trên trục $Ox, Oy$ và cập nhật danh sách tọa độ ở cột trái. |
| **5. Bấm `+ Thêm điểm` rồi nhấp lên Đồ thị** | • Chuyển con trỏ đồ thị sang `crosshair`. Khi nhấp chuột tại $(x_c, y_c)$: nếu gần đường cong ($\|y_c - f(x_c)\| < \epsilon$), tự động bắt dính (snap) điểm $(x_c, f(x_c))$ nằm trên đồ thị; ngược lại gắn điểm tại tọa độ nguyên/nửa nguyên gần nhất $\to$ vẽ đường gióng và thêm vào danh sách điểm (có nút `✕` để xóa từng điểm). |
| **6. Chuyển Tab (`Đồ thị` ↔ `Bảng biến thiên` ↔ `Tích phân` ↔ `Hình 3D`)** | • Dùng chung `state.analysis` đã tính sẵn (không tính lại CAS).<br>• Tab **Bảng biến thiên**: Vẽ bảng SGK với mũi tên chiều biến thiên, cực trị và vạch kép `\|\|` cho mọi tiệm cận đứng.<br>• Tab **Tích phân**: Đổi dòng phụ ở thẻ Hàm số thành **Nguyên hàm $F(x)$**, vẽ miền tô màu $[a, b]$ (ẩn cực trị và tắt nhãn `∫` thừa của JSXGraph), hiển thị chính xác cả **Tích phân $I$** và **Diện tích $S$**.<br>• Tab **Hình 3D SGK**: Hiển thị ô đọc đề Hình học tiếng Việt + 6 mẫu khối, vẽ hình 3D không trục $Oxyz$ với đầy đủ nhãn đỉnh SVG. |
| **7. Kéo cận $a, b$ hoặc nhập số cận $a, b$ (Tab Tích phân)** | • Tự động tính lại $I = \int_a^b f(x)\,dx$ và $S = \int_a^b \|f(x)\|\,dx$ (tách khoảng tại nghiệm $f(x)=0$) tức thì mà không cần bấm nút `Tính toán`. Nếu $a \ge b$, tự động hoán đổi hoặc hiện cảnh báo riêng ở thẻ Tích phân, tuyệt đối không làm mất `state.analysis`. |
| **8. Nhập đề Hình học tiếng Việt hoặc chọn Khối mẫu (Tab Hình 3D)** | • `geometry_parser.js` bóc tách khối đáy, đường cao ($SA \perp \text{đáy}$, $SO \perp \text{đáy}$), trung điểm, trọng tâm, hình chiếu $\to$ dựng mô hình 3D với nét đứt/nét liền, ký hiệu góc vuông và nhãn đỉnh SVG có thể xoay 360° bằng chuột. |
| **9. Bấm `📌 Ghim vào bảng` (hoặc `Ctrl + Enter`)** | • `board_exporter.js` serialize SVG của tab đang mở sang **Bảng màu Phấn (Chalk Palette)** kèm `metadata` đầy đủ (`formula`, `view`, `a`, `b`, `preset`, `problemText`, `curveColor`) $\to$ gửi qua `window.HocLuc.board.insertAnnotation` $\to$ đóng hộp thoại. |
| **10. Bấm `✕` hoặc `Hủy`** | • Gọi `window.HocLuc.close()` (được hỗ trợ đầy đủ bởi `hocluc-plugin-sdk.js`) để đóng hộp thoại tức thì. |

---

## Success Criteria
- [ ] Zero hardcoded math types (`type: 'cas_function'` replaced by AST polynomial/rational classifier); 5 dead files deleted.
- [ ] All UI cards, typography, and buttons follow `/high-end-visual-design` (Soft Structuralism + Double-Bezel trays, ClearType opaque body, integer pixel modal alignment, spring transitions).
- [ ] Zero overlapping labels on graphs; projection feet ($x_0, y_0$) labeled on $Ox, Oy$; sleek TikZ stealth arrows; clean non-clipped italic $O$.
- [ ] `Giao Ox`, `Giao Oy`, `Cực trị`, `+ Thêm điểm`, and `#colorSwatch` work 100% on both graph and sidebar while preserving zoom/pan.
- [ ] `KHUNG NHÌN HỆ TRỤC` accordion and extrema-dragging (`curve_manipulator.js`) removed; replaced by Smart Auto-Fit + `[+] [−] [⟲]` canvas controls.
- [ ] Integral tab displays exact $I$ and $S$ (splitting at roots $f(x)=0$, zero `.0001` error, no stray `∫` label on graph).
- [ ] 3D Geometry exports visibly to dark chalkboard with all vertex labels intact and supports Vietnamese problem text parsing.
- [ ] Chalkboard `BoardStickerFloatingBar` trimmed to 3 working actions (`✎ Sửa`, `⧉ Nhân bản`, `🗑 Xóa`).
- [ ] `node scripts/validate_plugins.mjs`, `flutter test test/architecture_test.dart`, and `flutter analyze --no-fatal-infos` pass with 0 errors.
