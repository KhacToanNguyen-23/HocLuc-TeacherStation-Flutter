# Spec: Ghim Đồ thị từ Native Plugin lên Bảng đen (Stamp Graph to Chalkboard)

**Date:** 2026-10-27
**Status:** Ready

---

## Problem Statement
Khi giáo viên sử dụng plugin Toán học Native (QuickJS Engine) và bấm nút "Ghim vào bảng", thẻ sticker sinh ra trên bảng phấn chỉ hiển thị tiêu đề và dòng chữ mô tả hàm số mà không hiển thị đồ thị (vùng nội dung bị đen rỗng). Cần đưa nguyên vẹn nội dung đồ thị đang hiển thị trên canvas vào thẻ sticker của bảng đen một cách sắc nét, tức thì và giữ nguyên các chi tiết giáo viên vừa tinh chỉnh.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a giáo viên dạy Toán, I want to bấm "Ghim vào bảng" ở bất kỳ tab đồ thị nào (Đồ thị 2D, Tích phân, Hình không gian 3D) so that thẻ sticker trên bảng đen hiển thị chính xác hình ảnh đồ thị đang thấy trên màn hình công cụ.
  Accepted when: Thẻ sticker trên bảng đen hiển thị rõ nét đồ thị (hệ trục Oxy, đường cong, miền gạch chéo tích phân hoặc khối 3D) khớp 100% với giao diện trên NativePluginHost.

- **[P1]** As a giáo viên dạy Toán, I want to ghim tab Bảng biến thiên (BBT) so that thẻ sticker trên bảng đen hiển thị bảng biến thiên vector SVG sắc nét không bị vỡ hạt khi phóng to thu nhỏ.
  Accepted when: Thẻ BBT trên bảng phấn chứa đầy đủ các hàng $x$, $y'$, $y$ và các mũi tên biến thiên sắc nét dưới dạng SVG.

- **[P2]** As a giáo viên, I want to dùng 8 điểm neo (Canva handles) kéo dãn hoặc phóng to thu nhỏ thẻ đồ thị trên bảng đen mà không bị méo tỉ lệ khung hình.
  Accepted when: Thẻ đồ thị duy trì tỉ lệ 4:3 (aspect ratio 1.33) hoặc tỉ lệ gốc khi co giãn, không bị méo mó.

- **[P3]** _(out of scope — noted for future)_: Cho phép chỉnh sửa trực tiếp các tham số của đồ thị ngay trên thẻ sticker mà không cần mở lại cửa sổ công cụ.

---

## Functional Requirements

1. **FR-01 (Canvas Boundary Key)**: `NativePluginHost` hoặc `NativeSceneCanvas` cung cấp một `GlobalKey` gắn vào `RepaintBoundary` bọc khung vẽ `CustomPaint`. Khung chụp chỉ lấy phần đồ thị/trục tọa độ toán học, loại trừ các nút bấm điều khiển floating toolbar (zoom in/out, reset).
2. **FR-02 (Snapshot Pipeline)**: Khi người dùng nhấn nút "Ghim vào bảng", phương thức `_stampToBoard()` chụp raster trực tiếp từ `RenderRepaintBoundary` với hệ số tỉ lệ `pixelRatio: 2.0`, chuyển đổi buffer thành chuỗi `data:image/png;base64,...`.
3. **FR-03 (Board Message Payload)**: Đóng gói đầy đủ `imageBase64` (đối với Đồ thị 2D, Tích phân, Hình 3D) hoặc `svgContent` (đối với BBT) vào payload của tin nhắn `board:insert_annotation` gửi qua `HostBridge`.
4. **FR-04 (Architecture Compliance)**: Tuyệt đối không hardcode ID plugin (`math_studio`, `casio_calculator`...) hay chuỗi tên môn học bên trong `frontend/lib/core/` hay `lib/features/studio_board/`. Toàn bộ luồng chụp ảnh và đóng gói được xử lý tổng quát (generic) trong `NativePluginHost`.

---

## Non-Functional Requirements

- **Performance**: Thời gian từ lúc nhấn nút "Ghim vào bảng" đến khi hoàn tất snapshot và tạo sticker trên bảng đen $\le 60\text{ ms}$, không gây giật lag giao diện (zero frame drop trên màn hình 120Hz).
- **Quality / Sharpness**: Ảnh chụp đồ thị có độ phân giải tối thiểu tương đương 2x màn hình chuẩn (Retina/High-DPI), các nét vẽ và chữ số tọa độ hiển thị sắc nét trên nền bảng đen.
- **Payload Size**: Chuỗi `imageBase64` nén PNG có kích thước $\le 200\text{ KB}$ để tránh áp lực bộ nhớ RAM và duy trì tốc độ đồng bộ bảng.

---

## Success Criteria

- [ ] Khi bấm "Ghim vào bảng" ở tab Đồ thị hàm số bậc 3 ($x^3 - 3x$), thẻ sticker trên bảng đen hiển thị rõ ràng đường cong và hệ trục Oxy, không còn vùng đen rỗng.
- [ ] Khi bấm "Ghim vào bảng" ở tab Bảng biến thiên, thẻ sticker hiển thị vector SVG bảng biến thiên.
- [ ] Khi bấm "Ghim vào bảng" ở tab Tích phân và Hình không gian 3D, thẻ sticker hiển thị đúng ảnh chụp miền tích phân / khung dây 3D.
- [ ] Chạy `flutter test test/architecture_test.dart` vượt qua 12/12 invariants (100%).
- [ ] Chạy `flutter analyze --no-fatal-infos` đạt 0 errors, 0 warnings.

---

## Out of Scope

- Không viết lại thuật toán sinh SVG cho đồ thị 2D hay hình 3D (giữ nguyên tắc "render sao lấy vậy").
- Không can thiệp vào cấu trúc lưu trữ cơ sở dữ liệu của bảng đen.

---

## Assumptions

- Khung canvas `NativeSceneCanvas` đã hoàn thành render trước thời điểm giáo viên bấm nút "Ghim vào bảng" trên header thanh công cụ.
- `BoardStickerCard` đã có sẵn logic giải mã và hiển thị `imageBase64` bằng `Image.memory` (đã kiểm chứng qua mã nguồn).

