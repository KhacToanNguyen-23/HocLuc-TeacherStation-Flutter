# Phase 03 — Canvas Pan & Zoom with Space Key & Wheel

## Objective
Tích hợp khả năng Thu phóng (Zoom) từ 50% đến 300% và Di chuyển (Pan) bảng đen linh hoạt bằng phím tắt `Space` và con lăn chuột (`Ctrl + Scroll`), đảm bảo hệ quy chiếu tọa độ vẽ chuẩn xác tuyệt đối không bị lệch ngòi bút, kèm thanh công cụ Mini Zoom ở góc bảng.

---

## Scope & Implementation Tasks

1. **Tích hợp Interactive Canvas Container (`main.dart` / `stage_container.dart`):**
   - Sử dụng `TransformationController` quản lý ma trận biến đổi `Matrix4` cho vùng bảng đen.
   - Giới hạn hệ số co giãn (Scale): `minScale = 0.5` (50%), `maxScale = 3.0` (300%).
   - Bắt sự kiện bàn phím qua `KeyboardListener` / `Focus`:
     - Nhận diện khi phím `LogicalKeyboardKey.space` được giữ (hoặc nút phụ trên bút).
     - Khi giữ Space: chuyển chế độ sang `isPanning = true`, đổi con trỏ chuột thành `SystemMouseCursors.grab`. Thao tác kéo chuột sẽ di chuyển (pan) ma trận transform thay vì vẽ nét.
     - Khi thả Space: trở lại con trỏ bút thông thường và tiếp tục vẽ bình thường.
   - Hỗ trợ con lăn chuột: cuộn chuột kèm phím `Ctrl` (hoặc con lăn khi trỏ vào bảng) để Zoom in / Zoom out mượt mà xung quanh tâm con trỏ.

2. **Chuẩn hóa tọa độ nét vẽ trong không gian ma trận (Scene Transformation):**
   - Trong `StrokeCanvas`:
     - Khi người dùng chạm bút vẽ, quy đổi tọa độ viewport về tọa độ scene của bảng:
       ```dart
       final sceneOffset = transformationController.toScene(localOffset);
       ```
     - Điểm `sceneOffset` sau đó mới được đưa vào hệ tọa độ normalized của `BoardStroke`.
     - Đảm bảo ngòi bút đặt vào điểm nào thì nét vẽ xuất hiện chính xác 100% tại điểm đó, không bị lệch hoặc trôi khi bảng đang được phóng to hoặc di chuyển.

3. **Mini Zoom Toolbar ở góc bảng (`main.dart`):**
   - Đặt một thanh điều khiển nổi nhỏ gọn (glassmorphic pill) ở góc dưới bảng đen:
     - Nút `-`: Giảm zoom 10%.
     - Text hiển thị: `% Zoom` hiện tại (ví dụ: `100%`, `150%`). Bấm vào text sẽ reset về `100%` và đưa bảng về tâm.
     - Nút `+`: Tăng zoom 10%.
     - Nút `Hand Tool` (icon bàn tay): Bật/tắt nhanh chế độ Pan bằng nút bấm trên màn hình (dành cho giáo viên chỉ dùng bút không tiện nhấn phím Space).

---

## Files / Modules Affected
- `app/lib/main.dart`
- `app/lib/widgets/stroke_canvas.dart`
- `app/lib/models/studio_state.dart`
- `app/test/stage_switcher_test.dart`

---

## Dependencies
- Phụ thuộc Phase 01 (Dual-layer inking engine) để đảm bảo việc scale canvas không làm giảm tốc độ render.

---

## Tests & Acceptance Criteria
- [x] Giữ phím Space và kéo chuột: bảng di chuyển mượt mà theo tay kéo, không xuất hiện nét vẽ lạ.
- [x] Lăn chuột zoom: bảng phóng to/thu nhỏ chính xác từ 50% đến 300%.
- [x] Vẽ thử khi đang zoom 200%: nét vẽ nằm chính xác ngay dưới đầu con trỏ chuột/ngòi bút.
- [x] Bấm nút Reset 100%: bảng trở về đúng kích thước và vị trí mặc định ban đầu.

---

## Risks & Notes
- Đảm bảo xử lý Focus hợp lý để phím Space không bị chặn bởi các widget TextField hay dialog khác.
