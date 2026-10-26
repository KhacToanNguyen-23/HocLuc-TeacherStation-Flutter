# Brainstorm Report: Tái Cấu Trúc Canva Transform Controls & Đồng Bộ WebView 2 Chiều

**Date:** 2026-10-26  
**Status:** Approved by User (Hướng A)  
**Topic:** Khắc phục triệt để lỗi Object Manipulation trên Bảng phấn và lỗi đồng bộ với Panel Math Studio  

---

## 1. Hiện Trạng & Phân Tích Nguyên Nhân Gốc Rễ

### Vấn đề 1: Lỗi Object Manipulation trên Bảng phấn (Studio Board)
1. **Lỗi tràn khung `BOTTOM OVERFLOWED BY 3.0 PIXELS`:**
   - Khi `Positioned` trên `interactive_chalkboard.dart` truyền chiều cao xuống, thẻ `Container` có `Border.all(width: 1.5)` (viền trên 1.5px + viền dưới 1.5px = 3.0px).
   - Nội dung bên trong `_buildContent` lại được set cứng `height: boxH`, làm tổng chiều cao con = `boxH + 3.0px` $\rightarrow$ Tràn đúng 3.0px và hiện vạch kẻ sọc vàng đen cảnh báo.
   - Khi Flutter bị RenderFlex overflow, bộ phân xử cử chỉ (Gesture Arena) bị vô hiệu hóa hoặc sai lệch toạ độ.
2. **Xung đột cử chỉ (Gesture Conflict) & Vùng chạm quá nhỏ:**
   - Các chốt kéo có kích thước chỉ 9px (khoảng 2mm trên màn hình), rất khó để click trúng bằng chuột máy tính.
   - Các chốt kéo đang bị lồng bên trong `GestureDetector` của thân thẻ (thay vì tách thành layer riêng), khiến thân thẻ cướp mất cử chỉ trước khi chốt kịp nhận lệnh kéo.
   - Chưa có `MouseRegion` với con trỏ chuột tương ứng (`resizeUpDown`, `resizeLeftRight`, `resizeUpLeftDownRight`), khiến người dùng không biết mình đã chạm trúng chốt hay chưa.
3. **Lỗi hiển thị cực trị:**
   - Tại `calculus_solver.js`, phép tính `new Fraction(-b, 2 * a)` khi gặp số chấm động chưa làm tròn đã sinh ra phân số biến dạng `(100000000000000/49999999999999; -2.70)` thay vì số nguyên `2`.

### Vấn đề 2: Lỗi không đồng bộ với Panel Math Studio khi bấm "✏️ Sửa"
1. **WebView không reload khi URL đổi:**
   - `FlatHost` (`flat_host_native.dart`) là một `StatefulWidget` nhưng chưa cài đặt `didUpdateWidget(oldWidget)`.
   - Khi bấm "✏️ Sửa", Flutter cập nhật URL kèm query params (`?editId=...&formula=...`), nhưng WebView2 controller không gọi `loadUrl(newUrl)` mà giữ nguyên trang web cũ.
2. **RPC nạp thông số không được kích hoạt:**
   - Biến `executeJs` trong `FloatingPluginWindow` không được gọi lại khi người dùng bấm Sửa lúc cửa sổ nổi đã mở sẵn.

---

## 2. Giải Pháp Hướng A Được Phê Duyệt

### 2.1. Tối ưu Transform Controls chuẩn Canva (Flutter Native)
1. **Triệt tiêu hoàn toàn Overflow:**
   - Dùng `Expanded` hoặc `FittedBox(fit: BoxFit.contain)` bên trong container có trừ hao độ dày border (`boxH - 3.0`).
2. **Tách riêng Layer Chốt Kéo lên trên cùng:**
   - Lớp dưới: `GestureDetector` thân thẻ chỉ phụ trách di chuyển (Move / Drag).
   - Lớp trên: `Stack` chứa 8 chốt kéo và 1 chốt xoay.
   - **Mở rộng Hit Area:** Kích thước hiển thị là 9px, nhưng kích thước vùng nhận cảm ứng chuột là **28px $\times$ 28px** (với padding trong suốt).
   - **Tích hợp MouseRegion:**
     - 4 góc: `SystemMouseCursors.resizeUpLeftDownRight` và `SystemMouseCursors.resizeUpRightDownLeft`.
     - 4 cạnh: `SystemMouseCursors.resizeUpDown` và `SystemMouseCursors.resizeLeftRight`.
     - Chốt xoay đỉnh: `SystemMouseCursors.grab`.
3. **Khóa tỷ lệ khung hình khi kéo 4 góc:**
   - Kéo 4 góc tự động tính tỷ lệ aspect ratio $\Delta w / \Delta h$ để đồ thị phóng to/thu nhỏ đồng dạng.
   - Kéo 4 cạnh co dãn chiều rộng và chiều cao độc lập.

### 2.2. Khắc phục đồng bộ 2 chiều (WebView & Host Bridge)
1. **Cập nhật `flat_host_native.dart`:**
   - Bổ sung `didUpdateWidget`: Khi `widget.url` thay đổi, gọi ngay `controller.loadUrl(targetUrl)`.
   - Gán `key: ValueKey(targetUrl)` trên `FlatHost` để đảm bảo chuyển đổi trạng thái dứt khoát.
2. **Khử lỗi phân số cực trị:**
   - Trong `calculus_solver.js`, làm tròn toạ độ cực trị $v_x = -b / (2a)$ trước khi chuyển phân số để luôn hiển thị số đẹp (ví dụ: $x = 2$).

---

## 3. Kế Hoạch Tiếp Theo
- Chuyển sang `$bb-plan` để tạo `plan.md` chi tiết và các phase triển khai.
- Chạy `$bb-cook` để hiện thực hóa Hướng A.

