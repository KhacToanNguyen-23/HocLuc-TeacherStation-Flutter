# Spec: Canva-Style Transform Controls & WebView 2-Way Sync

## 1. Problem Statement
Qua kiểm tra thực tế trên Bảng phấn (Studio Board) và plugin Math Studio:
1. **Lỗi Object Manipulation:**
   - Xuất hiện vạch kẻ sọc vàng đen `BOTTOM OVERFLOWED BY 3.0 PIXELS` ở đáy thẻ do cộng dồn viền 3px (`Border.all(width: 1.5)`), làm vỡ layout và tê liệt bộ bắt cử chỉ kéo của Flutter.
   - Các chốt kéo có vùng bấm quá nhỏ (9px) và bị lồng bên trong `GestureDetector` của thân thẻ, khiến thân thẻ cướp cử chỉ kéo.
   - Thiếu `MouseRegion` với con trỏ chuột resize tương ứng.
   - Toạ độ cực trị hiển thị chuỗi phân số dị thường `(100000000000000/49999999999999; -2.70)` do chưa làm tròn số chấm động trước khi tính phân số.
2. **Lỗi đồng bộ khi chỉnh sửa (Edit Desync):**
   - `FlatHost` (`flat_host_native.dart`) thiếu `didUpdateWidget`, khiến WebView không reload URL mới khi bấm `✏️ Sửa` một đồ thị khác trên bảng.
   - Panel Math Studio vẫn giữ thông số cũ thay vì nạp hàm số và cận tích phân của đồ thị đang chọn.

---

## 2. Requirements & User Stories

### P1: Canva-Style Transform Controls (Flutter Native Architecture)
- **US1.1 (Triệt tiêu Overflow):** Loại bỏ gán cứng chiều cao gây lỗi tràn 3px; nội dung vector/ảnh tự co dãn hoàn hảo trong khung bao (`BoxFit.contain`).
- **US1.2 (Tách biệt Layer Cử chỉ):**
  - Thân thẻ dùng `GestureDetector` riêng cho thao tác di chuyển (Move / Drag).
  - 8 chốt kéo và 1 chốt xoay nằm trên lớp `Stack` riêng biệt bên trên cùng.
- **US1.3 (Mở rộng Hit Area & Cursor):**
  - Mỗi chốt có vùng bấm cảm ứng rộng 28px $\times$ 28px (dù hình vẽ chốt chỉ 9px).
  - Tích hợp `MouseRegion`:
    - 4 góc: con trỏ chuột `resizeUpLeftDownRight` và `resizeUpRightDownLeft`.
    - 4 cạnh: con trỏ chuột `resizeUpDown` và `resizeLeftRight`.
    - Chốt xoay đỉnh: con trỏ chuột `grab`.
- **US1.4 (Resize / Scale 4 góc):** Kéo 4 góc phóng to/thu nhỏ đồng dạng giữ nguyên tỷ lệ khung hình (Aspect Ratio Lock).
- **US1.5 (Stretch 4 cạnh):** Kéo 2 cạnh trái/phải dãn `width`, kéo 2 cạnh trên/dưới dãn `height`.
- **US1.6 (Khử lỗi phân số cực trị):** Làm tròn số thực trước khi tính phân số tại `calculus_solver.js`, hiển thị toạ độ cực trị chuẩn SGK (ví dụ: `CT (2; -3)`).

### P1: WebView 2-Way Sync (Đồng Bộ 2 Chiều)
- **US2.1 (WebView Reload on Edit):** Cài đặt `didUpdateWidget` trong `flat_host_native.dart` để gọi `loadUrl(newUrl)` ngay khi URL thay đổi.
- **US2.2 (RPC Data Injection):** Gửi RPC `window.__hocluc_load_edit(payload)` hoặc truyền query params để Math Studio nạp tức thì công thức và cận tích phân của đồ thị được bấm `✏️ Sửa`.
- **US2.3 (In-Place Update):** Bấm "Cập nhật / Xong" trong Math Studio cập nhật đè nội dung lên đúng sticker đó trên bảng phấn, giữ nguyên vị trí, kích thước và góc xoay.

### P1: Bất Biến Kiến Trúc & Kiểm Thử
- **US3.1:** 5/5 test suites logic PASS 100%.
- **US3.2:** 12/12 Invariants PASS 100% (`node scripts/run_architecture_check.mjs`).
- **US3.3:** Đóng gói `plugins/math_studio.hlep` đồng bộ Schema v2.1.

### P1: Live DOM SVG Extraction (Bê Nguyên Hình Ra - Cách A)
- **US4.1 (Direct DOM Clone):** Khi bấm "Xong / Ghim lên bảng" trong Math Studio, trích xuất trực tiếp thẻ `<svg>` đang hiển thị trong container (`#graphContainer`, `#integralGraphContainer`, `#bbtContainer`, `#geometry3dContainer`).
- **US4.2 (Zero Desync):** Thấy thế nào trong panel thì ghim ra bảng y hệt 100%, loại bỏ hàm render SVG thứ hai (`generateGraphSvg`) gây lệch màu hoặc lệch trục.
- **US4.3 (Transparent Canvas Background):** Đảm bảo SVG trích xuất có `background: transparent` khi đặt trên nền bảng đen phấn trắng.

### P1: Canva BoxTransform Engine & Crash Elimination (Cách 1)
- **US5.1 (Khử Triệt Để `shifted_box.dart` Crash):** Tách thanh công cụ nổi (`[Ghim | Sửa | Nhân bản | Xóa]`) ra KHỎI `Transform.rotate`, luôn đặt nằm ngang phía trên đối tượng như chuẩn Canva/Figma. Loại bỏ hoàn toàn `OverflowBox` gây xung đột ma trận hit-test trong `shifted_box.dart`.
- **US5.2 (Local Coordinate Projection):** Khi kéo chốt ở góc hoặc cạnh, tính toán độ dịch chuột $\Delta P_{local} = R(-\theta) \cdot \Delta P_{global}$ để biến đổi kích thước chính xác ở mọi góc xoay $0^\circ \to 360^\circ$.
- **US5.3 (Opposite Anchor Pinning):** Khi kéo 4 góc, giữ cố định chốt đối diện và khóa tỉ lệ (Aspect Ratio Lock); khi kéo 4 cạnh, dãn theo 1 chiều độc lập.
- **US5.4 (Unlimited Re-Selection):** Bấm ra ngoài bảng phấn lập tức ẩn viền cam và 8 chốt; bấm lại vào sticker lập tức hiện lại và tiếp tục kéo xoay không giới hạn số lần, không bị tê liệt.

---

## 3. Success Criteria
- Không còn bất kỳ vạch vàng đen tràn pixel nào (`0.0 pixel overflow`).
- Không còn lỗi assertion `shifted_box.dart: Failed assertion: line 111` trong Flutter console.
- Rê chuột vào 4 góc và 4 cạnh hiện ngay con trỏ chuột kéo 2 chiều; bấm kéo ăn ngay lập tức 100%.
- Thao tác kéo co giãn và xoay hoạt động mượt mà liên tục, bấm ra ngoài deselect sạch sẽ, bấm lại tương tác tiếp không bị đơ.
- Đồ thị ghim lên bảng bê nguyên vẹn DOM SVG đang hiển thị trong panel ra, khớp 100% màu sắc và thông số.
- Bấm `✏️ Sửa` bất kỳ đồ thị nào trên bảng phấn mở ra panel Math Studio hiển thị chính xác đồ thị đó.
- Bấm "Cập nhật" cập nhật đè lên đồ thị cũ, không sinh hình trùng lặp.
- Toạ độ cực trị hiển thị số nguyên/thập phân ngắn gọn, không còn phân số dài dị thường.
