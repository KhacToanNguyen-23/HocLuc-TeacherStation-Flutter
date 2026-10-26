# Brainstorm: Tái Thiết Kế Toàn Bộ Giao Diện Extension Theo Phong Cách Liquid Glass (VisionOS)

**Date:** 2026-10-20  
**Slug:** `liquid-glass-extension-ui`  
**User:** Quoc Thai  

---

## 1. Bối Cảnh & Vấn Đề Khởi Điểm

- Giáo viên đang sử dụng Extension **Trợ giảng Tiếng Anh & Phân tích ngữ liệu ĐGNL** trên bảng phấn thông minh (`TeacherStation`).
- Giao diện hiện tại gồm:
  1. Thanh công cụ nổi trên bảng vẽ (`SubjectToolPalette`): Màu xanh đen đục phẳng (`AppColors.overlaySurface`), viền đơn sắc.
  2. Cửa sổ mở rộng kết quả (Webview UI): Nền màu rêu tối đặc (`#111a16`, `#182620`), che khuất hoàn toàn trang slide bài giảng hoặc nét phấn viết tay phía sau.
- Người dùng yêu cầu làm lại toàn bộ giao diện extension dựa trên cảm hứng và các component từ repository [liquidglass](file:///D:/6_OJT/liquidglass) (thư viện WebGL Shader kính khúc xạ thực tế), với thẩm mỹ **Liquid Crystal / iOS VisionOS Glass (kính trong suốt khúc xạ cao, nhìn thấu bài giảng bên dưới)** và **có cơ chế tùy chỉnh độ mờ linh hoạt**.

---

## 2. Các Hướng Giải Pháp Đã Thảo Luận (Ideas Explored)

1. **Hướng A: "True WebGL Liquid Shader"**
   - *Mô tả:* Tích hợp trực tiếp engine `@ybouane/liquidglass` (WebGL shaders, `HtmlCapture`) vào Webview của Extension.
   - *Ưu điểm:* Hiệu ứng tán sắc quang học (chromatic aberration) và khúc xạ ánh sáng chân thực 100% như trang demo của repo.
   - *Nhược điểm:* Quá trình re-rasterize liên tục qua `html-to-image` có thể gây tốn GPU/CPU trên các máy laptop giáo viên cấu hình trung bình, tiềm ẩn giật khung hình khi bảng vẽ đang có nhiều nét viết.

2. **Hướng B: "Hybrid VisionOS Crystal"**
   - *Mô tả:* Dùng Flutter Native `BackdropFilter` cho thanh dock nổi và hệ thống CSS Glassmorphism cao cấp cho Webview.
   - *Ưu điểm:* 60 FPS mượt mà tuyệt đối, phản ứng tức thì với nét vẽ của bảng.
   - *Nhược điểm:* Khó tái sử dụng nhanh cho các plugin khác nếu chỉ viết riêng lẻ trong CSS của extension Tiếng Anh.

3. **Hướng C: "Modular Glass Components" (Được người dùng lựa chọn)**
   - *Mô tả:* Đóng gói hệ thống component và theme Liquid Glass thành bộ kit module hóa chuẩn kiến trúc Microkernel của repo:
     - Phía Flutter Host: Widget `LiquidGlassContainer` và `SubjectToolPalette` kính lỏng.
     - Phía Plugin Webview: Bộ stylesheet `liquid-glass.css` chuẩn VisionOS và cơ chế SDK đồng bộ trạng thái kính.
     - Cơ chế chuyển đổi 3 mức độ kính (`Clear Glass` -> `Frosted Glass` -> `Solid Crystal`) điều khiển qua một nút duy nhất trên thanh dock và áp dụng đồng bộ tức thì cho cả dock lẫn panel drawer.
   - *Ưu điểm:* Thẩm mỹ đỉnh cao, nhẹ và nhanh 60 FPS, dùng chung được cho tất cả các plugin môn học khác sau này (Casio Calculator, Smart Pen,...).

---

## 3. Quyết Định Của Người Dùng (User's Direction)

- **Phạm vi:** Toàn bộ (Cả thanh dock nổi trên bảng vẽ lẫn toàn bộ cửa sổ kết quả Webview của extension).
- **Thẩm mỹ:** Kính trong suốt khúc xạ cao (*Liquid Crystal / iOS VisionOS Glass*), nhìn thấy nội dung bảng vẽ và trang bài giảng bên dưới.
- **Kiến trúc:** Hướng C (Modular Glass Components).
- **Cơ chế điều khiển độ trong suốt:** Phương án 1 (Nút bấm xoay vòng 3 mức preset: *Clear Glass* ~15% đục -> *Frosted Glass* ~50% đục -> *Solid Crystal* ~85% đục), điều khiển một lần là đồng bộ ngay lập tức cho cả thanh dock nổi lẫn cửa sổ drawer bên dưới.

---

## 4. Các Rủi Ro & Biện Pháp Giảm Thiểu (Risks & Mitigations)

1. **Rủi ro tương phản chữ trên nền bài giảng (Legibility on busy backgrounds):**
   - *Hiện tượng:* Nếu slide PDF hoặc bảng phấn có quá nhiều nét vẽ rực rỡ, kính trong suốt 100% có thể làm các phân tích cú pháp S-V-O khó đọc.
   - *Biện pháp:* Mức preset thứ 2 (*Frosted 50%*) và thứ 3 (*Solid 85%*) được tích hợp sẵn để giáo viên đổi trạng thái chỉ bằng 1 cú nhấp chuột.
2. **Tính trong suốt của Microsoft Edge WebView2 trên Windows:**
   - *Hiện tượng:* Mặc định WebView2 trên Windows có thể hiển thị nền trắng (`#FFFFFF`) nếu không kích hoạt thuộc tính background trong suốt.
   - *Biện pháp:* Đảm bảo Controller WebView2 cấu hình màu nền `Color(0x00000000)` và CSS `body { background: transparent; }`.
3. **Bất biến kiến trúc AGENTS.md (Zero Hardcoded Names):**
   - *Hiện tượng:* Cơ chế kính không được phép nhận diện cứng ID plugin `'com.hocluc.plugin.english'`.
   - *Biện pháp:* Trạng thái kính được quản lý chung qua `StudioState` hoặc thuộc tính manifest `"theme": "liquidglass"`, truyền qua `HostBridge` trừu tượng.

---

## 5. Kế Hoạch Tiếp Theo (Next Step)

- Biên soạn tài liệu đặc tả kỹ thuật chi tiết: `plans/liquid-glass-extension-ui/spec.md`.
- Bàn giao sang pipeline `/plan` để phân rã các pha thực thi (`phase-*.md`) và kiểm thử.

