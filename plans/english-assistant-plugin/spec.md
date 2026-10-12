# Spec: Gói Plugin Trợ giảng Tiếng Anh (.hlep) & Hệ thống Microkernel Runtime

**Date:** 2026-10-10  
**Status:** Ready  

---

## Problem Statement
Giáo viên dạy Tiếng Anh cần phân tích cú pháp câu (Chủ ngữ S - Động từ V - Tân ngữ O) và kiểm tra lỗi ngữ pháp/thì một cách trực quan, đồng thời muốn ghim kết quả phân tích trực tiếp lên bảng phấn điện tử để giảng bài mà không phải vẽ hoặc viết lại bằng tay. Giải pháp cần hoạt động mượt mà trên đa nền tảng (Windows Native và Web), hỗ trợ lưu trữ trạng thái vào file bài giảng `.hls` để soạn trước giáo án.

---

## User Stories

- **[P1]** As a giáo viên dạy Tiếng Anh, I want to nhập câu văn và bấm "Phân tích nhanh" so that hệ thống hiển thị màu sắc trực quan bóc tách Chủ ngữ (S), Động từ (V), Tân ngữ (O) và cảnh báo lỗi thì/ngữ pháp.  
  *Accepted when:* Kết quả phân tích trả về trong vòng dưới 800ms đối với câu văn dưới 50 từ, các nhãn màu `[S]`, `[V]`, `[O]` được gắn chuẩn xác vào từng từ.

- **[P1]** As a giáo viên, I want to bấm "📌 Ghim lên bảng" so that kết quả phân tích lập tức xuất hiện trên bảng phấn dưới dạng thẻ ghi chú (BoardSticker).  
  *Accepted when:* Thẻ xuất hiện ngay tại vị trí trung tâm hiển thị của bảng phấn, có thể kéo thả di chuyển vị trí, có nút [x] để xóa thẻ, và zoom/pan đồng bộ theo bảng.

- **[P1]** As a giáo viên soạn bài giảng trước giờ dạy, I want to lưu bài giảng thành file `.hls` so that khi mở lại bài giảng trong tiết học, toàn bộ thẻ S-V-O đã ghim vẫn nằm nguyên vẹn ở đúng vị trí trên từng trang bảng.  
  *Accepted when:* Sau khi lưu và nạp lại file `.hls`, toàn bộ thuộc tính của thẻ (vị trí tọa độ chuẩn hóa, danh sách token, lỗi ngữ pháp) được khôi phục 100%.

- **[P2]** As a giáo viên, I want to linh hoạt chuyển đổi giao diện Plugin giữa Ngăn kéo cố định (Drawer Panel 420px) và Cửa sổ nổi tự do (Floating Window) qua nút [🗗 Tách cửa sổ / Pop-out] so that không gian bảng phấn được tối ưu theo từng giai đoạn của tiết học.  
  *Accepted when:* Bấm nút Pop-out lập tức chuyển plugin thành một cửa sổ nổi có thể di chuyển và thu nhỏ trên bảng phấn mà không làm mất nội dung đang nhập.

- **[P2]** As a giáo viên sử dụng bản Windows Desktop, I want to hệ thống tự động khởi chạy và tắt tiến trình `service.exe` ngầm so that tôi không cần mở dòng lệnh hay cài đặt Python thủ công.  
  *Accepted when:* Khi cài đặt hoặc mở plugin trên Windows, `service.exe` được kích hoạt tự động ở background và tự giải phóng tiến trình khi thoát ứng dụng.

- **[P3]** _(Out of scope cho phase này)_ Hỗ trợ nhận diện chữ viết tay trực tiếp từ bảng phấn để tự động chuyển thành văn bản phân tích ngữ pháp.

---

## Functional Requirements

1. **FR-01: Định dạng gói Plugin (.hlep)**  
   - Gói `.hlep` là file ZIP chuẩn chứa:
     - `manifest.json`: Chứa metadata, id (`com.hocluc.plugin.english`), placement (`drawer_panel`), default_width (`420`), sidecar config (`executable: "engine/service.exe"`, `port: 18888`).
     - `icon.png`: Biểu tượng vuông 64x64.
     - `ui/index.html` & `ui/app.js`: Giao diện web tương tác.
     - `engine/service.exe` & `engine/service.py`: Backend sidecar (spaCy NLP).

2. **FR-02: Quản lý và Nhập gói Plugin trong Studio**  
   - Trong ngăn kéo "Tài liệu giảng dạy", khu vực **TIỆN ÍCH MÔN HỌC (Plugins)** hỗ trợ:
     - Nút "Cài thêm tiện ích môn" cho phép duyệt chọn file `.hlep`.
     - Kéo thả file `.hlep` trực tiếp vào ngăn kéo để cài đặt tự động.
     - Hiển thị danh sách các plugin đã cài đặt kèm icon, tên và nút mở.

3. **FR-03: Khung nhúng Plugin UI Đa Nền Tảng (FlatHost Integration)**  
   - Mở giao diện `ui/index.html` thông qua widget `FlatHost`:
     - Trên **Flutter Web:** Sử dụng IFrame (`HTMLIFrameElement`).
     - Trên **Windows Desktop:** Sử dụng Microsoft Edge WebView2 (`webview_windows`).
   - Mặc định trượt ra ở dạng Panel ngăn kéo kích thước 420px; có nút [🗗 Pop-out] để chuyển đổi mượt mà sang `FloatingPluginWindow`.

4. **FR-04: Cầu nối hai chiều (Bi-directional Bridge Message)**  
   - Giao diện Web gửi thông điệp `postMessage` với hành động:
     ```json
     {
       "action": "INSERT_ANNOTATION",
       "payload": {
         "raw_text": "The diligent student has completed...",
         "tokens": [ { "text": "The", "role": "OTHER" }, { "text": "student", "role": "SUBJECT" }, ... ],
         "issues": [ "⚠️ ..." ]
       }
     }
     ```
   - Flutter Core lắng nghe thông điệp và kích hoạt thêm `BoardSticker` vào trang bảng hiện tại.
   - Hỗ trợ đóng mở tự động ngăn kéo panel khi có yêu cầu từ plugin.

5. **FR-05: Thẻ Ghi Chú Tương Tác trên Bảng Phấn (BoardSticker)**  
   - Hiển thị các khối nhãn màu trực quan:
     - `SUBJECT (S)`: Viền & chữ màu xanh lam (`#89b4fa`).
     - `VERB (V)`: Viền & chữ màu đỏ hồng (`#f38ba8`).
     - `OBJECT (O)`: Viền & chữ màu cam đào (`#fab387`).
     - Khối cảnh báo lỗi ngữ pháp (nếu có): Nền tối viền đỏ cam, gợi ý sửa lỗi từ LanguageTool.
   - Có thanh tiêu đề mini kéo thả (Drag Handle) và nút đóng `[X]`.
   - Vị trí thẻ được tính theo tọa độ chuẩn hóa `0.0..1.0` trên mặt phẳng bảng phấn để co giãn chính xác theo độ phóng to / thu nhỏ của bảng (`InteractiveChalkboard`).

6. **FR-06: Lưu trữ và Khôi phục Giáo án (.hls)**  
   - Mở rộng model `StudioPage`:
     ```dart
     List<BoardSticker> annotations;
     ```
   - Tự động serialize/deserialize trường `annotations` khi lưu/nạp file dự án `.hls` (JSON).

7. **FR-07: Quản lý vòng đời Backend Sidecar (Windows Native)**  
   - Khởi chạy tiến trình `engine/service.exe` qua `dart:io Process.start` khi plugin kích hoạt.
   - Kiểm tra trạng thái sẵn sàng (Health check endpoint `http://127.0.0.1:18888/analyze`) với timeout tối đa 5 giây.
   - Tự động kill process khi ứng dụng thoát hoặc khi đóng plugin.

8. **FR-08: Cơ chế Fallback cho Flutter Web**  
   - Khi chạy trên trình duyệt Web, nếu cổng `18888` chưa phản hồi:
     - Giao diện hiển thị badge trạng thái màu vàng: *"Chế độ Web: Vui lòng khởi chạy service.py cục bộ hoặc kết nối API server"*.
     - Cung cấp dữ liệu phân tích mẫu (Demo Mock Engine) để giáo viên vẫn trải nghiệm được toàn bộ tính năng ghim thẻ S-V-O lên bảng ngay trên Web.

---

## Non-Functional Requirements

- **Hiệu năng (Performance):**
  - Thời gian trượt mở Panel Plugin ≤ 250ms (60 FPS).
  - Tốc độ phản hồi phân tích cú pháp spaCy cục bộ ≤ 500ms đối với câu dưới 100 từ.
  - Tốc độ render thẻ Sticker trên bảng phấn ≤ 16ms (không gây giật khung hình khi vẽ).
- **Tính khả chuyển (Portability):**
  - Tọa độ `BoardSticker` lưu ở dạng chuẩn hóa `Rect (x, y, w, h)` với giá trị tỉ lệ `0.0 .. 1.0`, hiển thị nhất quán trên mọi tỷ lệ màn hình (16:9, 4:3, 16:10).
- **Bảo mật & Ổn định (Reliability & Security):**
  - Tiến trình Python Sidecar chỉ bind cổng cục bộ trên `127.0.0.1`, không mở ra mạng ngoài LAN.
  - Tự động bắt lỗi ngoại lệ nếu file `.hlep` bị lỗi định dạng hoặc không có manifest hợp lệ.

---

## Success Criteria

- [ ] Cài đặt gói `english_assistant.hlep` thành công từ giao diện ngăn kéo tài liệu.
- [ ] Giao diện Plugin mở mượt mà trong Panel 420px và có thể Pop-out thành Floating Window.
- [ ] Bấm "Phân tích nhanh" hiển thị chuẩn xác các token `[S]`, `[V]`, `[O]`.
- [ ] Bấm "📌 Ghim lên bảng" tạo ra thẻ `BoardSticker` trực tiếp trên bảng phấn.
- [ ] Kéo thả thẻ di chuyển vị trí, zoom bảng phấn thẻ zoom đồng bộ.
- [ ] Lưu bài giảng thành file `.hls`, tải lại file: Thẻ phân tích S-V-O vẫn nằm đúng vị trí.
- [ ] Toàn bộ test suite tự động (`flutter test`) và `flutter analyze` đạt 100% xanh (0 lỗi).

---

## Out of Scope

- Tự động nhận diện chữ viết tay nét vẽ (Handwriting OCR) thành văn bản phân tích ngữ pháp.
- Dịch toàn bộ đoạn văn bản dài hàng nghìn từ.
- Huấn luyện lại model spaCy tuỳ biến.

---

## Assumptions

- Môi trường Windows có sẵn Microsoft Edge WebView2 Runtime (đã tích hợp mặc định trên Windows 10/11).
- Môi trường Web có quyền kết nối tới `http://127.0.0.1:18888` (CORS đã được cấu hình cho phép `*` trong FastAPI).

---

## [NEEDS CLARIFICATION]

*(Toàn bộ các câu hỏi đã được làm rõ và thống nhất)*
