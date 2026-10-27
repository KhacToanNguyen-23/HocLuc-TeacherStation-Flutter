# Phase 3: Studio Edit Wiring & Plugin 2-Way Sync

## 1. Goal
Kết nối toàn diện thao tác bấm `✏️ Sửa` từ Bảng phấn tới Cửa sổ nổi Math Studio và ngược lại:
1. Khi bấm `✏️ Sửa` trên một sticker:
   - `interactive_chalkboard.dart` gọi `widget.studio.openPlugin(plugin, editingSticker: s)`.
   - `StudioPluginBridgeController` lưu `editingSticker = s`.
   - `FloatingPluginWindow` truyền thông tin qua URL query: `&editId=...&formula=...&view=...&a=...&b=...` và qua RPC `window.__hocluc_load_edit(...)` khi webview sẵn sàng.
2. Math Studio (`plugins/math_studio/ui/app.js`):
   - Đọc URL parameters hoặc xử lý RPC `window.__hocluc_load_edit`:
     - Nếu có `formula`: đặt giá trị vào ô nhập `#mathInput` và chạy `reactiveRender`.
     - Nếu có `a` và `b`: đặt vào ô `#boundA` và `#boundB`.
     - Nếu có `view`: chuyển tab tương ứng.
     - Lưu `editingStickerId = editId`.
3. Khi bấm "Xong" (`#btnDoneDialog` hoặc `#btnQuickPin`):
   - Gửi payload kèm `stickerId: editingStickerId` và `metadata: { formula, bounds, a, b, view }`.
   - HostBridge cập nhật in-place vào sticker cũ trên bảng.
   - Xóa `editingStickerId` và đóng cửa sổ nổi.

## 2. Changes
- `frontend/lib/features/studio_board/services/controllers/studio_plugin_bridge_controller.dart`:
  - Thêm `BoardSticker? editingSticker;`
  - Thêm tham số `BoardSticker? editingSticker` vào `openPlugin`.
- `frontend/lib/features/studio_board/domain/models/studio_state.dart`:
  - Expose `openPlugin(plugin, {bool openModal = false, BoardSticker? editingSticker})`.
  - Expose `BoardSticker? get editingSticker`.
- `frontend/lib/features/studio_board/presentation/interactive_chalkboard.dart`:
  - Truyền `editingSticker: s` khi bấm nút Sửa trên card.
- `frontend/lib/features/plugin_engine/presentation/floating_plugin_window.dart`:
  - Đính kèm các query params `editId`, `formula`, `view`, `a`, `b` vào `targetUrl`.
  - Gọi JS `window.__hocluc_load_edit` trong `onControllerReady`.
- `plugins/math_studio/ui/app.js`:
  - Thêm hàm `loadEditPayload(data)` nạp dữ liệu vào form.
  - Gọi `loadEditPayload` từ URL SearchParams lúc khởi động và gán vào `window.__hocluc_load_edit`.
- `plugins/math_studio/ui/render/export_helper.js`:
  - Chấp nhận `stickerId` và `metadata` trong `insertToBoard`.

