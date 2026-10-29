# Spec: Tái cấu trúc Toàn diện Math Studio & Áp dụng Công nghệ Excalidraw + Giải tích THPT

**Date:** 2026-10-29
**Status:** Approved

---

## Problem Statement
Mã nguồn Math Studio và Plugin Engine trong Teacher Station hiện đang bị phân mảnh, tích tụ nhiều tàn dư code smell (trùng lặp 2 bộ CAS, regex hardcode, tàn dư QuickJS logic, mã Flutter tự vẽ lấn sân vào core). Cần thực hiện tái cấu trúc toàn diện: loại bỏ 100% mã toán học khỏi Flutter Core để trả về Microkernel Host sạch bóng; thanh lọc toàn bộ code rác trong `plugins/math_studio/`; và xây dựng lại Math Studio thành Plugin Webview độc lập chuẩn Marketplace gồm 3 trang chuyên sâu (Đồ thị & Khảo sát, Bảng biến thiên, Tích phân & Khối tròn xoay Riemann), ứng dụng Canvas Excalidraw nét phấn tự nhiên kết hợp bộ giải tích tương tác 2 chiều.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a kỹ sư hệ thống, I want to dọn sạch toàn bộ mã toán học và runtime QuickJS khỏi `frontend/lib/` so that mã nguồn Flutter trở lại thành một Microkernel Host thuần túy không chứa bất kỳ logic chuyên môn hay tên plugin nào bị hardcode.
  Accepted when: `flutter test test/architecture_test.dart` vượt qua 12/12 invariants, gỡ bỏ `flutter_js` khỏi `pubspec.yaml`, không còn file `native_plugin_*` nào trong `frontend/lib/`.

- **[P1]** As a giáo viên dạy Toán, I want to nhập bất kỳ hàm số nào vào ô nhập liệu gọn gàng và thấy ngay đạo hàm $y'$ bên dưới so that tôi có thể khảo sát hàm số tự do mà không bị giới hạn trong vài loại hàm cố định.
  Accepted when: Ô nhập $f(x)$ và dòng $y'$ thiết kế thanh mảnh, nhận diện mọi hàm đa thức, lượng giác, mũ, logarit, phân thức, căn thức và tính đúng đạo hàm $y'$ tức thì.

- **[P1]** As a giáo viên dạy Toán, I want to tương tác 2 chiều với Tiếp tuyến động $M(x_0)$ và Đường thẳng biện luận $y = m$ so that tôi vừa có thể gõ số ở bảng bên trái vừa có thể dùng chuột kéo trực tiếp trên đồ thị Excalidraw.
  Accepted when: Kéo điểm $M$ trên đường cong thì tiếp tuyến xoay theo độ dốc; kéo đường ngang $y = m$ lên xuống thì số nghiệm giao điểm cập nhật thời gian thực trên cả đồ thị và bảng số liệu.

- **[P1]** As a giáo viên dạy Toán, I want to có một Trang Bảng biến thiên (BBT) chuyên biệt toàn màn hình so that học sinh quan sát rõ ràng các khoảng biến thiên, dấu đạo hàm và chiều mũi tên chuẩn SGK.
  Accepted when: Tab BBT hiển thị đầy đủ các hàng $x, y', y$, dấu $+/-$, hai gạch không xác định $||$ và mũi tên tăng giảm chuẩn SGK THPT Việt Nam.

- **[P1]** As a giáo viên dạy Toán 12, I want to có một Trang Tích phân chuyên sâu với tính năng Tổng Riemann (chia hình chữ nhật) và Khối tròn xoay 3D trực quan so that học sinh hiểu sâu bản chất diện tích tích phân và thể tích tròn xoay.
  Accepted when: Thanh trượt số hình chữ nhật $n \in [4, 50]$ hiển thị các cột Riemann bậc thang khít dần vào đường cong; chế độ Khối tròn xoay 3D render trực tiếp từ đường cong với quy tắc nét liền (thấy) / nét đứt (khuất) và xoay đa góc nhìn tự do.

- **[P1]** As a giáo viên, I want to bấm "Ghim vào bảng" ở bất kỳ trang nào so that thẻ đồ thị xuất hiện trên bảng đen với 8 điểm neo Canva cho phép phóng to, thu nhỏ và xoay $360^\circ$ tự do.
  Accepted when: Thẻ đồ thị trên bảng đen hiển thị sắc nét hình ảnh Excalidraw nét phấn tự nhiên, phản hồi mượt mà với các thao tác kéo dãn kích thước và xoay (rotation) bằng chuột.

---

## Functional Requirements

1. **FR-01 (Purge Flutter Host Bleed)**: Xóa hoàn toàn các file `native_plugin_host.dart`, `native_scene_canvas.dart`, `native_plugin_runtime.dart` trong `frontend/lib/features/plugin_engine/`. Đưa `floating_plugin_window.dart` về sử dụng `FlatHost` (Webview2) duy nhất.
2. **FR-02 (Purge Plugin Code Smells)**: Xóa thư mục `plugins/math_studio/logic/` (`entry.js`, `main.js`), xóa các file CAS trùng lặp (`micro_cas.js`, `export_helper.js`), xóa các chuỗi regex ép kiểu đồ thị trong `ui/`.
3. **FR-03 (Compact Input & Calculus Core)**: Ô nhập hàm số $f(x)$ và kết quả $y'$ thiết kế inline siêu gọn; bộ Math Parser xử lý mọi biểu thức toán học, tự động tính tập xác định, cực trị, tiệm cận (đứng/ngang/xiên) và nguyên hàm.
4. **FR-04 (Bidirectional Interactive Graph on Excalidraw)**:
   - Khung đồ thị hiển thị hệ trục $Oxy$ với tỉ lệ co giãn responsive.
   - Nhãn chữ và tọa độ điểm áp dụng thuật toán chống đè chéo (collision offset).
   - Kéo điểm $M(x_0)$ trên đường cong cập nhật tiếp tuyến; kéo đường ngang $y = m$ cập nhật số nghiệm tức thì.
   - Nét vẽ phấn tự nhiên (hand-drawn roughness) đặc trưng của Excalidraw.
5. **FR-05 (Dedicated BBT Page)**: Trang Bảng biến thiên toàn màn hình với vector SVG sắc nét, đầy đủ cấu trúc 3 hàng $x, y', y$ chuẩn SGK, có nút ghim độc lập lên bảng đen.
6. **FR-06 (Integrals & Riemann Sums)**: Trang Tích phân cho phép nhập cận $[a, b]$, tự động tìm giao điểm, thanh trượt $n \in [4, 50]$ chia các cột hình chữ nhật Riemann khít dần vào diện tích thực tế.
7. **FR-07 (In-situ 3D Solids of Revolution)**: Khối tròn xoay tạo bởi đường cong $y = f(x)$ quay quanh $Ox$, render trực tiếp trên hệ trục với phân tách nét liền (mặt ngoài) và nét đứt (đáy/mặt khuất), hỗ trợ chuột xoay đa chiều góc nhìn.
8. **FR-08 (Canva Transform Stamping Protocol)**: Nút "Ghim vào bảng" xuất ảnh vector/PNG sắc nét từ Excalidraw qua `window.HocLuc.postMessage`, bảng đen bọc 8 điểm neo Canva và cuống xoay $360^\circ$.
9. **FR-09 (Offline Marketplace Packaging)**: Đóng gói plugin thành `plugins/math_studio.hlep`, manifest v2.1 với `"inject_sdk": true`, chạy offline 100% trên máy giáo viên sau khi tải từ Marketplace.

---

## Non-Functional Requirements

- **Performance**:
  - Thời gian phản hồi vẽ đồ thị khi gõ biểu thức $\le 16\text{ ms}$ (60 FPS).
  - Tốc độ tương tác kéo thả điểm $M$ và đường $y = m$ đạt 60-120 FPS không giật lag.
- **Visual Ergonomics**: Màu phấn dạ quang dịu mắt trên nền tối hoặc nền giấy, nhãn số tự động né nhau, không đè lấn làm khó đọc.
- **Zero Host Bleed**: Không có bất kỳ logic toán học hay chuỗi ký tự nào của plugin xuất hiện trong thư mục `frontend/lib/`.

---

## Success Criteria

- [ ] `frontend/lib/` sạch hoàn toàn mã toán học, `pubspec.yaml` gỡ bỏ `flutter_js`.
- [ ] Chạy `flutter test test/architecture_test.dart` vượt qua 12/12 invariants (100%).
- [ ] Chạy `flutter analyze --no-fatal-infos` đạt 0 errors, 0 warnings.
- [ ] Plugin `math_studio` chứa 3 trang rõ ràng: Đồ thị & Khảo sát, Bảng biến thiên, Tích phân & Khối tròn xoay.
- [ ] Kéo thả điểm $M(x_0)$ trên đồ thị làm tiếp tuyến di chuyển mượt mà; kéo đường $y = m$ đếm đúng số nghiệm.
- [ ] Thanh trượt Riemann $n$ tăng giảm số cột hình chữ nhật khít vào đường cong.
- [ ] Khối tròn xoay 3D render trực tiếp với nét liền/nét đứt chuẩn SGK và xoay được đa góc nhìn.
- [ ] Bấm "Ghim vào bảng" sinh ra thẻ sticker trên bảng đen có 8 chấm Canva co giãn và xoay $360^\circ$.
- [ ] `node scripts/validate_plugins.mjs` xác thực thành công.

---

## Out of Scope

- Không nhúng chuyên đề Hình học không gian $Oxyz$ (Mặt phẳng, Mặt cầu) vào plugin này (đã quyết định tách thành plugin riêng trên Marketplace).
- Không yêu cầu kết nối internet khi mở plugin sau khi đã tải về máy.
